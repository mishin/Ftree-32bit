#line 1 "DBI/Gofer/Serializer/Base.pm"
package DBI::Gofer::Serializer::Base;

#   $Id: Base.pm 9949 2007-09-18 09:38:15Z Tim $
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

#line 31


use strict;
use warnings;

use Carp qw(croak);

our $VERSION = "0.009950";


sub new {
    my $class = shift;
    my $deserializer_class = $class->deserializer_class;
    return bless { deserializer_class => $deserializer_class } => $class;
}

sub deserializer_class {
    my $self = shift;
    my $class = ref($self) || $self;
    $class =~ s/^DBI::Gofer::Serializer:://;
    return $class;
}

sub serialize {
    my $self = shift;
    croak ref($self)." has not implemented the serialize method";
}

sub deserialize {
    my $self = shift;
    croak ref($self)." has not implemented the deserialize method";
}

1;
