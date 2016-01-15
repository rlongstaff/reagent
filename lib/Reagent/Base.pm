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

package Reagent::Base;

use warnings;
use strict;

use Symbol;

our $VERSION = 0.1;

# TODO either submit Object::Base to CPAN or modify this to use
#      Class::Accessor

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = {};

    $self = bless( $self, $class );

    return $self->_init(@_);
}

sub __install_methods {
    my $proto = shift;
    my $class = ref $proto || $proto;

    foreach my $s (@_) {
        *{ qualify_to_ref($class . "::$s") } = sub {
            my $self = shift;
            no warnings 'redefine';
            $self->{"_$s"} = $_[0]
                if (scalar @_);
            return $self->{"_$s"};
        };
    }
}

sub _init {
    my $self = shift;

    # NOTE: The following is a shallow copy. References will be copied as
    # references. If you modify the values within that referenced structure
    # the structure referred to in the argument list will be modified.
    #
    # You have been warned.
    $self->{_args} = {};
    %{ $self->{_args} } = @_; # perl's warnings will notify user of uneven hash

    return $self;
}

sub _arg {
    my $self = shift;
    my ($key, $val) = @_;

    return unless (defined $key);

    return unless (exists $self->{_args}{$key});

    my $old_val = $self->{_args}{$key};

    $self->{_args}{$key} = $val
        if (@_ == 2);

    return $old_val;
}

1;

