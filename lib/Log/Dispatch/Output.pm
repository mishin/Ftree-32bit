#line 1 "Log/Dispatch/Output.pm"
package Log::Dispatch::Output;

use strict;
use warnings;

our $VERSION = '2.45';

use Log::Dispatch;

use base qw( Log::Dispatch::Base );

use Params::Validate qw(validate SCALAR ARRAYREF CODEREF BOOLEAN);
Params::Validate::validation_options( allow_extra => 1 );

use Carp ();

my $level_names
    = [qw( debug info notice warning error critical alert emergency )];
my $ln            = 0;
my $level_numbers = {
    ( map { $_ => $ln++ } @{$level_names} ),
    warn  => 3,
    err   => 4,
    crit  => 5,
    emerg => 7
};

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    die "The new method must be overridden in the $class subclass";
}

sub log {
    my $self = shift;

    my %p = validate(
        @_, {
            level   => { type => SCALAR },
            message => { type => SCALAR },
        }
    );

    return unless $self->_should_log( $p{level} );

    $p{message} = $self->_apply_callbacks(%p)
        if $self->{callbacks};

    $self->log_message(%p);
}

sub _basic_init {
    my $self = shift;

    my %p = validate(
        @_, {
            name      => { type => SCALAR, optional => 1 },
            min_level => { type => SCALAR, required => 1 },
            max_level => {
                type     => SCALAR,
                optional => 1
            },
            callbacks => {
                type     => ARRAYREF | CODEREF,
                optional => 1
            },
            newline => { type => BOOLEAN, optional => 1 },
        }
    );

    $self->{level_names}   = $level_names;
    $self->{level_numbers} = $level_numbers;

    $self->{name} = $p{name} || $self->_unique_name();

    $self->{min_level} = $self->_level_as_number( $p{min_level} );
    die "Invalid level specified for min_level"
        unless defined $self->{min_level};

    # Either use the parameter supplied or just the highest possible level.
    $self->{max_level} = (
        exists $p{max_level}
        ? $self->_level_as_number( $p{max_level} )
        : $#{ $self->{level_names} }
    );

    die "Invalid level specified for max_level"
        unless defined $self->{max_level};

    my @cb = $self->_get_callbacks(%p);
    $self->{callbacks} = \@cb if @cb;

    if ( $p{newline} ) {
        push @{ $self->{callbacks} }, \&_add_newline_callback;
    }
}

sub name {
    my $self = shift;

    return $self->{name};
}

sub min_level {
    my $self = shift;

    return $self->{level_names}[ $self->{min_level} ];
}

sub max_level {
    my $self = shift;

    return $self->{level_names}[ $self->{max_level} ];
}

sub accepted_levels {
    my $self = shift;

    return @{ $self->{level_names} }
        [ $self->{min_level} .. $self->{max_level} ];
}

sub _should_log {
    my $self = shift;

    my $msg_level = $self->_level_as_number(shift);
    return (   ( $msg_level >= $self->{min_level} )
            && ( $msg_level <= $self->{max_level} ) );
}

sub _level_as_number {
    my $self  = shift;
    my $level = shift;

    unless ( defined $level ) {
        Carp::croak "undefined value provided for log level";
    }

    return $level if $level =~ /^\d$/;

    unless ( Log::Dispatch->level_is_valid($level) ) {
        Carp::croak "$level is not a valid Log::Dispatch log level";
    }

    return $self->{level_numbers}{$level};
}

sub _level_as_name {
    my $self  = shift;
    my $level = shift;

    unless ( defined $level ) {
        Carp::croak "undefined value provided for log level";
    }

    return $level unless $level =~ /^\d$/;

    return $self->{level_names}[$level];
}

my $_unique_name_counter = 0;

sub _unique_name {
    my $self = shift;

    return '_anon_' . $_unique_name_counter++;
}

sub _add_newline_callback {

    # This weird construct is an optimization since this might be called a lot
    # - see https://github.com/autarch/Log-Dispatch/pull/7
    +{@_}->{message} . "\n";
}

1;

# ABSTRACT: Base class for all Log::Dispatch::* objects

__END__

#line 316
