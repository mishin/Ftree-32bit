#line 1 "Set/Scalar/Null.pm"
package Set::Scalar::Null;

use strict;
local $^W = 1;

use vars qw($VERSION @ISA);

$VERSION = '1.29';
@ISA = qw(Set::Scalar::Base Set::Scalar::Virtual);
use Set::Scalar::Virtual;
use Set::Scalar::Base;

use overload
    'neg'	=> \&_complement_overload;

sub SET_FORMAT        { "(%s)" }

sub _new_hook {
    my $self     = shift;
    my $universe = $_[0]->[0];
    
    $self->universe( $universe );
}

sub universe {
    my $self = shift;

    $self->{'universe'} = shift if @_;

    return $self->{'universe'};
}

sub elements {
    return ();
}

sub size {
    return 0;
}

sub _complement_overload {
    my $self = shift;

    return Set::Scalar->new( $self->universe->elements );
}

#line 67

1;
