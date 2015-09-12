#line 1 "Log/Log4perl/Util/TimeTracker.pm"
##################################################
package Log::Log4perl::Util::TimeTracker;
##################################################

use 5.006;
use strict;
use warnings;
use Log::Log4perl::Util;
use Carp;

our $TIME_HIRES_AVAILABLE;

BEGIN {
    # Check if we've got Time::HiRes. If not, don't make a big fuss,
    # just set a flag so we know later on that we can't have fine-grained
    # time stamps
    $TIME_HIRES_AVAILABLE = 0;
    if(Log::Log4perl::Util::module_available("Time::HiRes")) {
        require Time::HiRes;
        $TIME_HIRES_AVAILABLE = 1;
    }
}

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        reset_time            => undef,
        @_,
    };

    $self->{time_function} = \&_gettimeofday unless 
        defined $self->{time_function};

    bless $self, $class;

    $self->reset();

    return $self;
}

##################################################
sub hires_available {
##################################################
    return $TIME_HIRES_AVAILABLE;
}

##################################################
sub _gettimeofday {
##################################################
    # Return secs and optionally msecs if we have Time::HiRes
    if($TIME_HIRES_AVAILABLE) {
        return (Time::HiRes::gettimeofday());
    } else {
        return (time(), 0);
    }
}

##################################################
sub gettimeofday {
##################################################
    my($self) = @_;

    my($seconds, $microseconds) = $self->{time_function}->();

    $microseconds = 0 if ! defined $microseconds;
    return($seconds, $microseconds);
}

##################################################
sub reset {
##################################################
    my($self) = @_;

    my $current_time = [$self->gettimeofday()];
    $self->{reset_time} = $current_time;
    $self->{last_call_time} = $current_time;

    return $current_time;
}

##################################################
sub time_diff {
##################################################
    my($time_from, $time_to) = @_;

    my $seconds = $time_to->[0] -
                  $time_from->[0];

    my $milliseconds = int(( $time_to->[1] -
                             $time_from->[1] ) / 1000);

    if($milliseconds < 0) {
        $milliseconds = 1000 + $milliseconds;
        $seconds--;
    }

    return($seconds, $milliseconds);
}

##################################################
sub milliseconds {
##################################################
    my($self, $current_time) = @_;

    $current_time = [ $self->gettimeofday() ] unless
        defined $current_time;

    my($seconds, $milliseconds) = time_diff(
            $self->{reset_time}, 
            $current_time);

    return $seconds*1000 + $milliseconds;
}

##################################################
sub delta_milliseconds {
##################################################
    my($self, $current_time) = @_;

    $current_time = [ $self->gettimeofday() ] unless
        defined $current_time;

    my($seconds, $milliseconds) = time_diff(
            $self->{last_call_time}, 
            $current_time);

    $self->{last_call_time} = $current_time;

    return $seconds*1000 + $milliseconds;
}

1;

__END__



#line 260
