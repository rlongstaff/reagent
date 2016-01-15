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

package Reagent::Server::Daemon::Connection;

use warnings;
use strict;

use Log::Log4perl;

require Reagent::Base;
use base qw(Reagent::Base);

require Reagent::Server::Daemon;
require Reagent::Net::Message;
require Reagent::Net::Filter;
require Reagent::Net::FilterSet;

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            _daemon
            _socket
            user
            )
    );
}

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->_socket( $self->{_args}{Socket} );
    $self->_daemon( $self->{_args}{Daemon} );

    # TODO verbose errors
    return unless ( defined $self->_socket );
    return unless ( defined $self->_daemon );

    return $self;
}

sub run {
    my $self = shift;

    my $log = Log::Log4perl->get_logger(ref $self);

    # Phase 1: filter / encryption negotiation
    $log->debug("Beginning filter negotiation");
    unless ( $self->negotiate_filters ) {
        $log->error("Filter negotiation failed");
        return;
    }
    $log->debug("Filter negotiation complete");

    # Phase 2: User authentication
    $log->debug("Beginning user authentication");
    unless ( $self->negotiate_authentication ) {
        $log->error("User authentication failed");
        return;
    }
    $log->debug("User authentication complete");

    # Phase 3: Server selection
    my $server_id = $self->negotiate_server_handler;

    # plugin handoff
    my $server = $self->_daemon->server($server_id);
    
    # Separate the _socket call into its own eval{}.
    #  Object::Trampoline delays instantiation until the first use of the
    #  object, which is here.
    eval {
        $server->_socket($self->_socket);
    };
    if ($@) {
        $log->error("Failed to load Server $server_id: $@");
        my $msg = Reagent::Net::Message->new;
        $msg->header('Status', 'Error');
        $msg->content("Failed to load Server $server_id");
        $self->_socket->send_msg($msg);
        return;
    }
    eval{
        $server->handler;
    };
    if ($@) {
        $log->error("Failed Server handoff: $@");
        return;
    }

    return 1;
}

sub negotiate_filters {
    my $self = shift;
    my $log = Log::Log4perl->get_logger(ref $self);
    my $msg = Reagent::Net::Message->new;

    $msg->header( Protocol => $self->_daemon->protocol_version );
    $msg->header(
        Filters => join( ',', $self->_daemon->filterset->filter_list ) );

    $self->_socket->send_msg($msg);

    $self->_socket->filterset( $self->_daemon->filterset );

    my $resp = $self->_socket->recv_msg;

    unless ( defined $resp ) {
        $log->error("Failed to construct message from filter negotiation");
        return;
    }

    unless ( $resp->header('Status') eq 'OK' ) {
        $log->error( 'Filter negotiation respond understood, but not valid: '
                . $resp->header('Status') );
        return;
    }

    return 1;
}

sub negotiate_authentication {
    my $self = shift;

    #TODO :)

    return 1;
}

sub negotiate_server_handler {
    my $self = shift;

    my $log = Log::Log4perl->get_logger(ref $self);

    my $msg = Reagent::Net::Message->new;

    $msg->header( 'Content', 'ServerList' );
    $msg->content( join( ',', $self->_daemon->servers ) );

    $self->_socket->send_msg($msg);

    $msg->clear;

    $msg = $self->_socket->recv_msg;
    unless ( $msg->header('Content') eq 'ServerRequest') {
        $log->error("Expect ServerRequest: " . $msg->serialize);
        return;
    }

    my $server = $msg->content;
    
    $log->debug("Received request for Server: $server");
    unless ($self->_daemon->server($server)) {
        my $msg_buf = "Invalid Server request: No such Server";
        $log->error($msg_buf);
        $msg->clear;
        $msg->header('Status', 'Error');
        $msg->content($msg_buf);
        $self->_socket->send_msg($msg);
        
        return;
    }

    return $server;
}

1;

