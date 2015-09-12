#line 1 "Set/Scalar/Universe.pm"
package Set::Scalar::Universe;

use strict;
local $^W = 1;

use vars qw($VERSION @ISA);

$VERSION = '1.29';
@ISA = qw(Set::Scalar::Virtual Set::Scalar::Base);

use Set::Scalar::Base qw(_make_elements);
use Set::Scalar::Virtual;
use Set::Scalar::Null;

use overload
    'neg'	=> \&_complement_overload;

my $UNIVERSE = __PACKAGE__->new;

sub SET_FORMAT        { "[%s]" }

sub universe {
    my $self = shift;

    return $UNIVERSE;
}

sub null {
    my $self = shift;

    return $self->{'null'};
}

sub enter {
    my $self = shift;

    $UNIVERSE = $self;
}

sub _new_hook {
    my $self     = shift;
    my $elements = shift;

    $self->{'universe'} = $UNIVERSE;
    $self->{'null'    } = Set::Scalar::Null->new( $self );

    $self->_extend( { _make_elements( @$elements ) } );
}

sub _complement_overload {
    my $self = shift;

    return Set::Scalar::Null->new( $self );
}

#line 93

1;
