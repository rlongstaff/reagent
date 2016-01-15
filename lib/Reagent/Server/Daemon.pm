##############################################################################
#
#  Copyright (C) 2010 Robert Longstaff (rob@longstaff.us)
#  
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; either version 2 of the License, or
#      (at your option) any later version.
#  
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#  
#      You should have received a copy of the GNU General Public License along
#      with this program; if not, write to the Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
##############################################################################

package Reagent::Server::Daemon;

require 5.6.0;

use warnings;
use strict;

use POSIX qw{ :sys_wait_h setuid };
use Readonly;
use Cwd;
use File::Spec;
use IO::Select;
use Log::Log4perl;

require Reagent::Base;
use base qw( Reagent::Base );

use Reagent::Net::Socket;
require Reagent::Config::Daemon;
require Reagent::Server::Daemon::Connection;
require Reagent::Net::Message;

use Data::Dumper;

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            debug
            base_path
            config_file
            config
            filterset
            server_socket
            server_list
            )
    );
}

Readonly my $DEFAULT_CFG => File::Spec->catfile( 'etc', 'reagentd.cfg' );
Readonly my $LOG_CFG_READ_INTERVAL => 10;

Readonly our $RUN_STATUS_RUN     => 3;
Readonly our $RUN_STATUS_RELOAD  => 2;
Readonly our $RUN_STATUS_RESTART => 1;
Readonly our $RUN_STATUS_QUIT    => 0;

Readonly our $VER_MAJOR => 0;
Readonly our $VER_MINOR => 1;
Readonly our $VER_PATCH => 0;
Readonly our $VERSION   => "$VER_MAJOR.$VER_MINOR.$VER_PATCH";

Readonly our $PROTOCOL_VER_MAJOR => 1;
Readonly our $PROTOCOL_VER_MINOR => 0;
Readonly our $PROTOCOL_VERSION   => "$PROTOCOL_VER_MAJOR.$PROTOCOL_VER_MINOR";

# Global needed for signal handlers that won't have access to the instance
my $gbl_run_status = $RUN_STATUS_RUN;

sub sigchld {

    my $log = Log::Log4perl->get_logger('Reagent::Server::Daemon');
    $log->debug("Reaping a child!");
    local $?;
    while ( waitpid( -1, WNOHANG ) > 0 ) { }
    $SIG{CHLD} = \&sigchld;
}

sub sighup {

    my $log = Log::Log4perl->get_logger('Reagent::Server::Daemon');
    $log->info("Received SIGHUP");
    $gbl_run_status = $RUN_STATUS_RELOAD;
}

sub sigquit {
    my $name = shift;

    my $log = Log::Log4perl->get_logger('Reagent::Server::Daemon');
    $log->info("Received SIG$name");
    $gbl_run_status = $RUN_STATUS_QUIT;
}

sub sigwarn {
    my @d   = @_;
    my $log = Log::Log4perl->get_logger('Reagent::Server::Daemon');
    foreach (@d) {
        chomp;
        $log->debug($_);
    }
}

sub run_status {
    my $self;
    if ( ref $_[0] ) {
        $self = shift;
    }
    my ($new_state) = @_;

    if ( defined $new_state ) {
        $gbl_run_status = $new_state;
    }

    return $gbl_run_status;
}

sub protocol_version {
    return $PROTOCOL_VERSION;
}

sub daemonize {
    my $self = shift;

    unless ( $self->{_daemon} ) {
        $self->{_log}->debug("daemonizing");
        fork && exit;
        chdir('/');
        open( STDIN,  '</dev/null' );
        open( STDOUT, '>/dev/null' );
        open( STDERR, '>/dev/null' );

        $self->{_daemon} = 1;
        $self->{_log}->info("Process backgrounded. New pid: $$");
    }

    return $self->{_daemon};
}

# Object initialization
#  parse options from constructor to prep for actual configuration
sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->debug( $self->{_arg}{Debug} || 0 );

    my $base = $self->{_arg}{BasePath} || getcwd();
    my $cfg = $self->{_arg}{ConfigFile}
        || File::Spec->catfile( $base, 'etc', 'reagentd.cfg' );

    $self->base_path($base);
    $self->config_file($cfg);

    return $self;
}

sub configure {
    my $self = shift;

    $self->config(
           Reagent::Config::Daemon->new( ConfigFile => $self->config_file ) );

 # Localize the pid_file directory. We'll be in / after we daemonize, but want
 # to keep the reletive directory reference in the Config::Daemon module
    $self->config->pid_file( File::Spec->catfile( 
        $self->base_path, 
        $self->config->pid_file,
    ));

    unless ( Log::Log4perl->initialized() ) {
        Log::Log4perl->init_and_watch( $self->config->log_config,
                                       $LOG_CFG_READ_INTERVAL );
        $self->{_log} = Log::Log4perl->get_logger( ref $self );

        if ( $self->debug ) {
            my $layout = Log::Log4perl::Layout::PatternLayout->new(
                                                     '[%d] (%P) %p %c: %m%n');
            my $appender =
                Log::Log4perl::Appender->new(
                                            "Log::Log4perl::Appender::Screen",
                                            name => "screenlog", );
            $appender->layout($layout);
            my $root = Log::Log4perl::Logger->get_root_logger;
            $root->add_appender($appender);
            $root->level($Log::Log4perl::DEBUG);
        }

        $self->{_log}->debug("Log initialized");
    }

    $self->filterset( $self->config->filterset );

    # TODO crypto_init needs to be pushed back to socket creation to
    #   allow for public key in phase 1...
    $self->filterset->crypto_init;

    if ( $self->config->servers ) {
        foreach my $id ( $self->config->servers ) {
            my $s_obj = $self->config->server($id);
            $self->server( $id, $s_obj );
        }
    }

    return 1;
}

sub create_socket {
    my $self = shift;

    $self->{_log}->debug(   "Binding socket to "
                          . $self->config->interface . ":"
                          . $self->config->port );
    my $sock =
        Reagent::Net::Socket->new( Proto     => 'tcp',
                                   Listen    => SOMAXCONN,
                                   LocalAddr => $self->config->interface,
                                   LocalPort => $self->config->port,
                                   ReuseAddr => 1,
        );

    unless ($sock) {
        $self->{_log}->logdie("Could not create socket: $!\n");
    }

    $self->{_log}->info(   "Listening on "
                         . $self->config->interface . ":"
                         . $self->config->port );
    $self->server_socket($sock);

    return $sock;
}

sub destroy_socket {
    my $self = shift;

    $self->{_log}->debug("destroying server socket");
    my $sock = $self->server_socket;
    $sock->shutdown(2);
    $sock->close;
    $self->server_socket(undef);
}

sub create_pid_file {
    my $self = shift;

    my $pid_file = $self->config->pid_file;
    unless ( defined $pid_file ) {
        $self->{_log}->error("No pid_file configured");
        return;
    }

    my $pid = $$;

    if ( -f $pid_file ) {
        $self->{_log}->error("Cannot create $pid_file. File exists");
        return;
    }

    my $fh;
    unless ( open( $fh, '>', $pid_file ) ) {
        $self->{_log}->error("Could not create $pid_file: $!");
        return;
    }
    print $fh $pid;
    unless ( close($fh) ) {
        $self->{_log}->error("Could not close $pid_file: $!");
        return;
    }

    $self->{_log}->debug("pid_file created");

    return $pid;
}

sub destroy_pid_file {
    my $self = shift;

    my $pid_file = $self->config->pid_file;
    unless ( defined $pid_file ) {
        $self->{_log}->error("No pid_file configured");
        return;
    }

    unlink $pid_file;

    $self->{_log}->debug("pid_file destroyed");

    return 1;
}

sub servers {
    my $self = shift;
    return keys %{ $self->{_server} };
}

sub server {
    my $self = shift;
    my ( $id, $obj ) = @_;

    if ( defined $obj ) {
        $self->{_server}{$id} = $obj;
    }

    return $self->{_server}{$id};
}

sub run {
    my $self = shift;

    my $log = $self->{_log};

    $log->info("Reagentd $VERSION starting up...");

    $self->daemonize
        unless $self->debug;

    unless ( $self->create_pid_file ) {
        $self->run_status($RUN_STATUS_QUIT);
        return;
    }

    # create socket
    unless ( $self->create_socket ) {
        $self->run_status($RUN_STATUS_QUIT);
        return;
    }

    # TODO useing to separate ways to stop the process after failure
    #      pick one and stick with it

    # drop privs
    if ( defined $self->config->user ) {
        my $uid = getpwnam( $self->config->user );

        unless ( defined $uid ) {
            $log->logdie(
                    "Could not get uid for '" . $self->config->user . "'\n" );
        }

        unless ( setuid($uid) ) {
            $log->logdie("Could not setuid($uid): $!\n");
        }
        $log->debug( "switched to user: " . $self->config->user . " ($uid)" );
    }

    # set signal handlers
    $SIG{HUP}      = \&sighup;
    $SIG{INT}      = \&sigquit;
    $SIG{QUIT}     = \&sigquit;
    $SIG{TERM}     = \&sigquit;
    $SIG{CHLD}     = \&sigchld;
    $SIG{__WARN__} = \&sigwarn;

    # connection loop
    $self->listen_for_clients;

    $log->info("Shutting down...");
    
    $self->destroy_socket;

    $self->destroy_pid_file;

    return $self->run_status;
}

sub listen_for_clients {
    my $self = shift;

    my $select = IO::Select->new;
    $select->add( $self->server_socket );

    while ( $self->run_status == $RUN_STATUS_RUN ) {
        my @ready = $select->can_read(5);    # 5 second wait

        foreach my $fh (@ready) {
            next unless ( $fh == $self->server_socket );
            next unless my $client_socket = $self->server_socket->accept();

            $self->{_log}->debug(   "Accepted connection from "
                                  . $client_socket->peerhost . ":"
                                  . $client_socket->peerport );
            if ( !defined( my $pid = fork ) ) {
                $self->{_log}->error("Could not fork!");
            } elsif ( $pid == 0 ) {
                my $client =
                    Reagent::Server::Daemon::Connection->new(
                                                     Socket => $client_socket,
                                                     Daemon => $self, );
                unless ( $client->run() ) {
                    $self->{_log}
                        ->error("Client processed exited abnormally");
                    exit 1;
                }
                exit 0;
            }
        }
    }

    return 1;
}

1;

