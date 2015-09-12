#line 1 "Set/Scalar.pm"
package Set::Scalar;

use strict;
# local $^W = 1;

use vars qw($VERSION @ISA);

$VERSION = '1.29';
@ISA = qw(Set::Scalar::Real Set::Scalar::Null Set::Scalar::Base);

use Set::Scalar::Base qw(_make_elements is_equal as_string_callback);
use Set::Scalar::Real;
use Set::Scalar::Null;
use Set::Scalar::Universe;

sub ELEMENT_SEPARATOR { " "    }
sub SET_FORMAT        { "(%s)" }

sub _insert_hook {
    my $self     = shift;

    if (@_) {
	my $elements = shift;

	$self->universe->_extend( $elements );

	$self->_insert_elements( $elements );
    }
}

sub _new_hook {
    my $self     = shift;
    my $elements = shift;

    $self->{ universe } = Set::Scalar::Universe->universe;

    $self->_insert( { _make_elements( @$elements ) } );
}

#line 409

1;
