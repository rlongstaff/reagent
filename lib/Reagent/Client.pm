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

package Reagent::Client;

use warnings;
use strict;

use Data::Dumper;
use Readonly;
use Config::General;
use Log::Log4perl;

require Reagent::Base;
use base qw(Reagent::Base);

require Reagent::Config::Client;
require Reagent::Net::Message;
require Reagent::Net::Socket;

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            config_file
            config
            debug
            host
            _socket
            )
    );
}

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->config_file( $self->{_args}{ConfigFile} );

    my $cfg;
    
    $cfg = Reagent::Config::Client->new( ConfigFile => $self->config_file );
    return unless ($cfg);
    $self->config($cfg);

    $self->debug( $self->{_args}{Debug} );

    my $log_level = ( $self->debug ) ? 'DEBUG' : 'WARN';
    my $conf = "
        log4perl.rootLogger                = $log_level, Screen
        log4perl.appender.Screen           = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout    = Log::Log4perl::Layout::SimpleLayout
    ";

    #log4perl.appender.Screen.stderr = 0

    Log::Log4perl::init( \$conf );
    
    my $log = Log::Log4perl->get_logger(ref $self);
    
    $self->host( $self->{_args}{Host} );
    unless ( defined $self->host ) {
        $log->error("No host specified");
        return;
    }

    return $self;
}

sub connect {
    my $self = shift;

    my $log = Log::Log4perl->get_logger($self);

    my $sock = Reagent::Net::Socket->new(
        PeerAddr => $self->host,
        PeerPort => $self->config->port,    #TODO ugly
    );

    my $host_str = $self->host . ":" . $self->config->port;
    unless ($sock) {
        $log->error("Failed to connect to $host_str: $!");
        return;
    }
    $log->debug("Connected to $host_str");

    $self->_socket($sock);

    $log->debug("Beginning filter negotiation");
    unless ( $self->negotiate_filters ) {
        $log->error("Filter negotiation failed");
        return;
    }
    $log->debug("Filter negotiation complete");

    $log->debug("Beginning user authentication");
    unless ( $self->negotiate_authentication ) {
        $log->error("User authentication failed");
        return;
    }
    $log->debug("User authentication complete");

    my @s = $self->fetch_available_servers;

    return @s;
}

sub negotiate_filters {
    my $self = shift;

    my $log = Log::Log4perl->get_logger($self);

    my $msg = $self->_socket->recv_msg;
    unless ( defined $msg ) {
        $log->error("Did not receive banner!`");
        return;
    }

    my $buf = $msg->header('Filters');
    unless ( defined $buf ) {
        $log->error("Initial message missing Filter header");
        return;
    }

    my $fs = Reagent::Net::FilterSet->new;

    my %filters = $self->config->filters;

    my @filter_ids = split( /,/, $buf );
    foreach my $f_id (@filter_ids) {
        unless ( exists $filters{$f_id} ) {
            $log->error("Requested filter definition not found: $f_id");
            return;
        }
        my $f = $filters{$f_id};

        #TODO validation
        unless ( $f->is_initialized ) {
            $f->crypto_init;
        }
        $fs->add_filter($f);
    }

    $self->_socket->filterset($fs);

    $msg->clear;
    $msg->header( 'Status' => 'OK' );

    $self->_socket->send_msg($msg);

    return 1;
}

sub negotiate_authentication {
    my $self = shift;

    # TODO :)
    return 1;
}

sub fetch_available_servers {
    my $self = shift;

    my $log = Log::Log4perl->get_logger($self);

    my $resp = $self->_socket->recv_msg;

    unless ( defined $resp ) {
        $log->error("Failed to get server list");
        return;
    }

    unless ( $resp->header('Content') eq 'ServerList' ) {
        $log->error( "Expected ServerList packet; received: "
                . $resp->header('Content') );
        return;
    }

    my @servers = split( /,/, $resp->content );

    if ( $self->debug ) {
        foreach my $s (@servers) {
            $log->debug("Received server $s");
        }
    }

    return @servers;
}

sub request_server {
    my $self = shift;
    my ($server) = @_;

    my $msg = Reagent::Net::Message->new;

    $msg->header( 'Content', 'ServerRequest' );
    $msg->content($server);

    $self->_socket->send_msg($msg);

    $msg->clear;
    $msg = $self->_socket->recv_msg;

    return ( ( $msg->header('Status') eq 'OK' ) ? 1 : 0 );
}

1;

