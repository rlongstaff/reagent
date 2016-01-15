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

package Reagent::Server::Nagios;

use warnings;
use strict;

require Reagent::Server;
use base qw(Reagent::Server);

use Proc::Reliable;
use Storable qw(thaw);

BEGIN {
    __PACKAGE__->__install_methods(qw(
        plugin_dir
        ));
}

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    my $log = Log::Log4perl->get_logger(ref $self);

    $log->debug("Initializing...");
    
    unless (defined $self->{_args}{PluginDir} ) {
        $log->error("No PluginDir specified!");
        return;
    }

    unless ( -d $self->{_args}{PluginDir} ) {
        $log->error("Not a directory: " . $self->{_args}{PluginDir});
        return;
    }

    $self->plugin_dir($self->{_args}{PluginDir});

    $log->debug("Initialization complete.");

    return $self;
}

sub handler {
    my $self = shift;

    my $log = Log::Log4perl->get_logger(ref $self);

    # Let the client know we're ready to proceed.
    my $msg = Reagent::Net::Message->new();
    $msg->header( 'Status', 'OK' );
    $self->_socket->send_msg($msg);
    
    $msg = $self->_socket->recv_msg;

    my $buf = thaw($msg->content);
    my ($cmd, @args) = @$buf;
    
    # Reject anything with a parent directory marker in it
    #  That can only be used for breaking out of the plugin jail 
    if ($cmd =~ /\.\.\//) {
        $log->warn("Rejecting command: '$cmd'");
        $msg->clear;
        $msg->header('ReturnCode', 127);
        $msg->content("$cmd: command not found");
        $self->_socket->send_msg($msg);
        return;
    }
    
    my $bin = File::Spec->catfile($self->plugin_dir, $cmd);
    my ( $rc, $output );

    # verify command exists and is executable before attempting to run it
    if ( -e $bin && -x $bin ) {
        my $proc = Proc::Reliable->new;
        
        $log->debug("Executing: '$bin " . join(' ', @args) . "'");
        $output = $proc->run([$bin, @args]);
        $rc = $proc->status >> 8; # exit codes are the most significant 8 bits

        chomp $output;

    } else {

        # cannot execute command 
        $log->debug("Cannot execute: '$bin " . join(' ', @args) . "'");
        
        # default to UNKNOWN state return code
        #TODO no magic numbers
        $rc = 3;

        # and set sensible output msg
        $output = "$cmd: command not executable"
            unless -x $bin;
        $output = "$cmd: command not found"
            unless -e $bin;
    }

    $log->debug("ReturnCode: $rc");
    $log->debug("Output: $output");

    $msg->clear;
    $msg->header('ReturnCode', $rc);
    $msg->content($output);

    $self->_socket->send_msg($msg);

    return 1;
}

1;

