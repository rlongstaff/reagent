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

package Reagent::Net::Socket;

use warnings;
use strict;

use IO::Socket::INET;
use base qw(IO::Socket::INET);

use Data::Dumper;
use Log::Log4perl;
use Readonly;
require Reagent::Net::Message;
require Reagent::Net::FilterSet;

Readonly my $HEADER_LEN => 8;             # two 32 bit unsigned int
                                          #   (MAGIC, length)
Readonly my $MAGIC      => 0x52474e54;    # hex of RGNT

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = $class->SUPER::new(@_);

    return unless defined $self;

    my $fs = Reagent::Net::FilterSet->new;

    $self->filterset($fs);

    return $self;
}

sub filterset {
    my $self = shift;
    my ($fs) = @_;

    if ( defined $fs ) {
        ${*$self}->{_filterset} = $fs;
    }

    return ${*$self}->{_filterset};
}

sub accept {
    my $self = shift;

    my ( $new_socket, $peer_addr ) = $self->SUPER::accept()
        or return;

    # Apply current filters to new socket
    my @filters = $self->filterset->filters;
    $new_socket->filterset->filters( \@filters );

    return wantarray ? ( $new_socket, $peer_addr ) : $new_socket;
}

sub send_msg {
    my $self = shift;
    my ($msg) = @_;

    my $log = Log::Log4perl->get_logger(ref $self);

    unless ( defined $msg && $msg->isa('Reagent::Net::Message') ) {
        $log->error("Invalid message");
        return;
    }

    my $buf;
    $buf = $msg->serialize();
    
    $log->debug("Sending: " . Dumper($buf));

    # loop outbound layers
    foreach my $f ( $self->filterset->filters ) {
        $buf = $f->encrypt($buf);
    }

    my $header = pack( 'NN', $MAGIC, length $buf );

    my $bytes = syswrite( $self, $header . $buf );

    # TODO validate num bytes sent?

    return $bytes;
}

#TODO add timeouts to sysreads
sub recv_msg {
    my $self = shift;

    my $log = Log::Log4perl->get_logger(ref $self);

    my ( $buf, $bytes_read );

    # read header
    $bytes_read = sysread( $self, $buf, $HEADER_LEN );
    if ( !defined $bytes_read ) {
        $log->warn("recv_msg: Error during header sysread: $!");
        return;
    } elsif ( 0 == $bytes_read ) {
        $log->warn("recv_msg: 0 byte header sysread during...");
        return;
    } elsif ( $bytes_read < $HEADER_LEN ) {
        $log->warn(
            "recv_msg: Failed to read complete header. Received $bytes_read bytes"
        );
        return;
    }

    my ( $magic, $payload_len ) = unpack( 'NN', $buf );

    # validate magic
    unless ( $MAGIC == $magic ) {
        $log->warn("recv_msg: Magic mismatch! Expecting: $MAGIC. Received: $magic");
    }

    undef $buf;

    # read payload
    my $total_bytes_read = 0;
    while ( $total_bytes_read < $payload_len ) {
        my $partial_buf;
        $bytes_read = sysread( $self, $partial_buf,
            $payload_len - $total_bytes_read );
        if ( !defined $bytes_read ) {
            $log->warn("recv_msg: Error during payload sysread: $!");
            return;
        } elsif ( 0 == $bytes_read ) {
            $log->warn("recv_msg: 0 byte payload sysread during...");
            last;    # TODO ...? Not sure of correct course here...
        }
        $buf .= $partial_buf;
        $total_bytes_read += $bytes_read;
    }

    # loop payload through inbound filters
    #  we're reversing due to FILO on the send side
    foreach my $f ( reverse $self->filterset->filters ) {
        $buf = $f->decrypt($buf);
    }

    $log->debug("receiving: " . Dumper($buf));

    # create Reagent::Net::Message object from plaintext payload
    my $msg = Reagent::Net::Message->new();

    unless ($msg) {
        $log->warn("recv_msg: Failed to create Reagent::Net::Message");
        return;
    }

    unless ( $msg->from_string($buf) ) {
        $log->warn("recv_msg: Failed to construct Message from string");
        return;
    }

    return $msg;
}

1;

