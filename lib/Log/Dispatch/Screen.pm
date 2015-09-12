#line 1 "Log/Dispatch/Screen.pm"
package Log::Dispatch::Screen;

use strict;
use warnings;

our $VERSION = '2.45';

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate BOOLEAN);
Params::Validate::validation_options( allow_extra => 1 );

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = validate(
        @_, {
            stderr => {
                type    => BOOLEAN,
                default => 1
            },
        }
    );

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->{stderr} = exists $p{stderr} ? $p{stderr} : 1;

    return $self;
}

sub log_message {
    my $self = shift;
    my %p    = @_;

    if ( $self->{stderr} ) {
        print STDERR $p{message};
    }
    else {
        print STDOUT $p{message};
    }
}

1;

# ABSTRACT: Object for logging to the screen

__END__

#line 119
