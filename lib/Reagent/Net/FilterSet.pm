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

package Reagent::Net::FilterSet;

use warnings;
use strict;

use Log::Log4perl;

require Reagent::Base;
use base qw(Reagent::Base);

sub _init {
    my $self = shift;

    $self->SUPER::_init(@_);

    $self->clear_filters;

    return $self;
}

sub clear_filters {
    my $self = shift;

    $self->{_filters}      = {};
    $self->{_filter_order} = [];

    return 1;
}

sub add_filter {
    my $self = shift;
    my ($filter) = @_;

    my $log = Log::Log4perl->get_logger(ref $self);
    unless ( defined $filter
        && ($filter->isa('Reagent::Net::Filter') || $filter->isa('Object::Trampoline::Bounce')))
    {
        $log->error("Failed to add Filter: Not a Filter");
        return;
    }
    
    $log->debug("Added Filter: " . $filter->id);

    push @{ $self->{_filter_order} }, $filter->id;
    $self->{_filters}{ $filter->id } = $filter;

    return 1;
}

sub filter {
    my $self = shift;
    my ($id) = @_;

    return $self->{_filters}{$id};
}

sub filters {
    my $self = shift;

    return ( map { $self->{_filters}{$_} } @{ $self->{_filter_order} } );
}

sub filter_list {
    my $self = shift;

    return @{ $self->{_filter_order} };
}

sub crypto_init {
    my $self = shift;

    foreach my $f_id ( @{ $self->{_filter_order} } ) {
        $self->{_filters}{$f_id}->crypto_init;
    }
}

1;

