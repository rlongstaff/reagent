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

package Reagent::Net::Message;

use warnings;
use strict;

require Reagent::Base;
use base qw( Reagent::Base );

use Log::Log4perl;

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->clear;

    return $self;
}

sub clear {
    my $self = shift;

    $self->{_headers} = {};
    $self->{_content} = '';
}

sub header {
    my $self = shift;

    my ( $key, $val ) = @_;

    return unless ( defined $key );

    $key = ucfirst $key;

    # test for only a single argument
    #  use @_ for an existence test o $set_val, rather than defined test,
    #  allowing  undef as a valid value
    if ( scalar @_ > 1 ) {
        return if ( $key eq 'Length' );
        $self->{_headers}{$key} = $val;
    }

    if ( $key eq 'Length' ) {
        return scalar length $self->content;
    }

    return $self->{_headers}{$key};
}

sub headers {
    my $self = shift;

    my %h = %{ $self->{_headers} };

    $h{Length} = length( $self->content );

    return %h;
}

sub content {
    my $self = shift;

    my ($val) = @_;

    if ( defined $val ) {
        $self->{_content} = $val;
    }

    return $self->{_content};
}

sub serialize {
    my $self = shift;

    my %headers = $self->headers();
    my $header_buf;

    while ( my ( $h, $v ) = each %headers ) {
        $header_buf .= "$h: $v\r\n";
    }

    return $header_buf . "\r\n" . $self->content;
}

# TODO There is a good deal of memory optimization to be done here as we are
# copying the content buffer several times. Very large messages could cause
# problems
sub from_string {
    my $self = shift;
    my ($buf) = @_;

    return unless ( defined $buf );

    my $log = Log::Log4perl->get_logger(ref $self);

    my ( $header_buf, $content_buf ) = split( /\r\n\r\n/, $buf, 2 );

    undef $buf;

    return unless ( defined $header_buf );

    my %headers;
    foreach my $line ( split( /\r\n/, $header_buf ) ) {
        next unless defined $line;
        my ($key, $val) = split( /: /, $line );

        unless (defined $key && defined $val) {
            $log->error("Malformed message header: '$line'");
            return;
        }

        $headers{$key} = $val;
    }


    $self->content( substr( $content_buf, 0, $headers{Length} ) );

    delete $headers{Length};
    foreach my $k ( keys %headers ) {
        $self->header( $k, $headers{$k} );
    }

    return $self;
}

1;

