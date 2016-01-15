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

package Reagent::Net::Filter::CryptCBC;

use warnings;
use strict;

require Reagent::Net::Filter;
use base qw(Reagent::Net::Filter);

use Crypt::CBC;

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    #TODO check for validity
    $self->{_key} = $self->{_args}{Key};
    $self->{_cipher_module} = $self->{_args}{Cipher};

    return $self;
}

sub crypto_init {
    my $self = shift;

    my $key = $self->{_key};
    my $cipher_mod = $self->{_cipher_module};

    my $cipher = Crypt::CBC->new(
        -key    => $key,
        -cipher => $cipher_mod,
    );

    $self->{_cipher} = $cipher;

    $self->SUPER::crypto_init;

    return 1;
}

sub encrypt {
    my $self = shift;
    my ($plaintext) = @_;

    return $self->{_cipher}->encrypt($plaintext);
}

sub decrypt {
    my $self = shift;
    my ($ciphertext) = @_;

    return $self->{_cipher}->decrypt($ciphertext);
}

1;

