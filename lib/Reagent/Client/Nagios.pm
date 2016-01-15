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

package Reagent::Client::Nagios;

use warnings;
use strict;

require Reagent::Client;
use base qw(Reagent::Client);

use Storable qw(nfreeze);

sub check {
    my $self = shift;
    my ($check_name, @args) = @_;

    my $msg = Reagent::Net::Message->new;
    
    # TODO escapes and such
    $msg->content(nfreeze([$check_name, @args]));
    
    $self->_socket->send_msg($msg);
    
    $msg = $self->_socket->recv_msg;

    my ($result, $output);

    if (defined $msg) {
        $result = $msg->header('ReturnCode');
        $output = $msg->content;
    } else {
        #TODO replace with central return code labels per rack:21
        $result = -1;
        $output = "Error receiving message from remote agent.";
    }

    # TODO text / return code
    return wantarray?($result,$output):$result;
}

1;

