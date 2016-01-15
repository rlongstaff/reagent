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

package Reagent::Config;

use warnings;
use strict;

use Readonly;
use Config::General;
use Log::Log4perl;
use Object::Trampoline;

require Reagent::Base;
use base qw(Reagent::Base);

require Reagent::Net::Filter;
require Reagent::Net::FilterSet;

Readonly my $DEFAULT_PORT => 3141;

BEGIN {
    __PACKAGE__->__install_methods(
        qw(
            config_file
            debug
            port
            )
    );
}

sub _init {
    my $self = shift;

    my $log = Log::Log4perl->get_logger( ref $self );

    $self->SUPER::_init(@_);

    $self->config_file( $self->{_args}{ConfigFile} );
#    return unless $self->config_file;

    my ( $conf_obj, %config );
    eval {
        $conf_obj = Config::General->new(
            -ConfigFile         => $self->config_file,
            -UseApacheInclude   => 1,
            -IncludeRelative    => 1,
            -IncludeDirectories => 1,
            -IncludeGlob        => 1,
            -SlashIsDirectory   => 1,
            -SplitPolicy        => 'whitespace',
            -CComments          => 0,
            -BackslashEscape    => 1,
        );
        if ( defined $conf_obj ) {
            %config = $conf_obj->getall;
        }
    };
    if ($@) { }    # Config::General dies if it can't find the config
                   # We can sneak by on defaults, so no need to die

    # TODO standarized format? no reason to expose internal
    #         Config::General structures...
    $self->{_config} = \%config;

    # common options to server and client
    $self->debug( $self->{_config}{Debug} ? 1 : 0 );
    $self->port( $self->{_config}{Port} || $DEFAULT_PORT );

    if ( exists $config{Filter} ) {
        foreach my $f_id ( keys %{ $config{Filter} } ) {
            my $class_name = $config{Filter}{$f_id}{Class};
            my %args;
            foreach my $arg ( keys %{ $config{Filter}{$f_id} } ) {
                next if ( $arg eq 'Class' );
                $args{$arg} = $config{Filter}{$f_id}{$arg};
            }
            
            my $filter = Object::Trampoline::Use->new( $class_name, Id => $f_id, %args );

            unless ($filter) {
                $log->warn("Unable to build Filter: $f_id");
                next;
            }
            $self->{_filters}{$f_id} = $filter;
        }
    }

    return $self;
}

sub filters {
    my $self = shift;

    unless (defined $self->{_filters} && ref $self->{_filters} eq 'HASH') {
        return;
    }
    
    return %{ $self->{_filters} };
}

sub filterset {
    my $self = shift;

    my $log = Log::Log4perl->get_logger( ref $self );

    my %config = %{ $self->{_config} };

    my $filterset = Reagent::Net::FilterSet->new;

    my @filter_ids;

    unless ( scalar keys %{ $self->{_filters} } != 1
        || ( exists $config{FilterOrder} && defined $config{FilterOrder} ) )
    {
        $log->warn("No FilterOrder specified");
        return;
    }

    @filter_ids = split( /\s*,\s*/, $config{FilterOrder} );

    foreach my $f_id (@filter_ids) {
        my $filter = $self->{_filters}{$f_id};
        if ( defined $filter ) {
            $filterset->add_filter($filter);
        } else {
            $log->warn("Invalid Filter identifier in FilterOrder");
            return;
        }
    }

    return $filterset;
}

1;
