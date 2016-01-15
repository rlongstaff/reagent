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

package Reagent::Config::Daemon;

use warnings;
use strict;

use Readonly;
use File::Spec;
use IO::Socket::INET;    # INADR_ANY
use Object::Trampoline;

use Reagent::Config;
use base qw(Reagent::Config);

Readonly my $DEFAULT_LOG_CFG =>
    File::Spec->catfile( 'etc', 'reagentd_log.cfg' );
Readonly my $DEFAULT_PID_FILE => File::Spec->catfile( 'var', 'reagentd.pid' );

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            log_config
            interface
            port
            pid_file
            user
            )
    );
}

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    my $log = Log::Log4perl->get_logger(ref $self);

    $self->log_config( $self->{_config}{LogConfig} || $DEFAULT_LOG_CFG );
    $self->interface( $self->{_config}{Interface}  || inet_ntoa(INADDR_ANY) );
    $self->pid_file( $self->{_config}{PidFile}     || $DEFAULT_PID_FILE );
    $self->user( $self->{_config}{User} );

    if ( $self->{_config}{Server} ) {
        foreach my $id ( keys %{ $self->{_config}{Server} } ) {
            my $server_class = $self->{_config}{Server}{$id}{Class};
            my %args;
            foreach my $arg ( keys %{ $self->{_config}{Server}{$id} } ) {
                next if ( $arg eq 'Class' );
                $args{$arg} = $self->{_config}{Server}{$id}{$arg};
            }
            my $s_obj = Object::Trampoline::Use->new($server_class, Id => $id, %args);
            
            $self->server($id, $s_obj);
        }
    }

    return $self;
}

sub servers {
    my $self = shift;
    return keys %{ $self->{_server} };
}

sub server {
    my $self = shift;
    my ( $id, $cfg_ref ) = @_;

    if ( defined $cfg_ref ) {
        $self->{_server}{$id} = $cfg_ref;
    }

    return $self->{_server}{$id};
}

1;
