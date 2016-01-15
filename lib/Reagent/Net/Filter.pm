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

package Reagent::Net::Filter;

use warnings;
use strict;

require Reagent::Base;
use base qw(Reagent::Base);

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            id
            )
    );
}

# Object initialization
#  This is a subclass hook for new()
sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->id( $self->{_args}{Id} );

    return unless ( $self->id );

    $self->{_is_init} = 0;

    return $self;
}

# Encryption / Filter initialization
sub crypto_init {
    my $self = shift;
    
    $self->{_is_init} = 1;

    return $self->{_is_init}; 
}

sub is_initialized {
    my $self = shift;

    return $self->{_is_init};
}

# Takes only plaintext as argument
# Returns ciphertext
sub encrypt { }

# Takes only ciphertext as argument
# Returns plaintext
sub decrypt { }

1;
