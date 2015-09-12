#line 1 "Log/Log4perl/Appender/Buffer.pm"
######################################################################
# Buffer.pm -- 2004, Mike Schilli <m@perlmeister.com>
######################################################################
# Composite appender buffering messages until a trigger condition is met.
######################################################################

###########################################
package Log::Log4perl::Appender::Buffer;
###########################################

use strict;
use warnings;

our @ISA = qw(Log::Log4perl::Appender);

our $CVSVERSION   = '$Revision: 1.2 $';
our ($VERSION)    = ($CVSVERSION =~ /(\d+\.\d+)/);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        appender=> undef,
        buffer  => [],
        options => { 
            max_messages  => undef, 
            trigger       => undef,
            trigger_level => undef,
        },
        level   => 0,
        %options,
    };

    if($self->{trigger_level}) {
        $self->{trigger} = level_trigger($self->{trigger_level});
    }

        # Pass back the appender to be synchronized as a dependency
        # to the configuration file parser
    push @{$options{l4p_depends_on}}, $self->{appender};

        # Run our post_init method in the configurator after
        # all appenders have been defined to make sure the
        # appender we're playing 'dam' for really exists
    push @{$options{l4p_post_config_subs}}, sub { $self->post_init() };

    bless $self, $class;
}

###########################################
sub log {
###########################################
    my($self, %params) = @_;

    local $Log::Log4perl::caller_depth =
        $Log::Log4perl::caller_depth + 2;

        # Do we need to discard a message because there's already
        # max_size messages in the buffer?
    if(defined $self->{max_messages} and
       @{$self->{buffer}} == $self->{max_messages}) {
        shift @{$self->{buffer}};
    }
        # Ask the appender to save a cached message in $cache
    $self->{app}->SUPER::log(\%params,
                         $params{log4p_category},
                         $params{log4p_level}, \my $cache);

        # Save it in the appender's message buffer, but only if
        # it hasn't been suppressed by an appender threshold
    if( defined $cache ) {
        push @{ $self->{buffer} }, $cache;
    }

    $self->flush() if $self->{trigger}->($self, \%params);
}

###########################################
sub flush {
###########################################
    my($self) = @_;

        # Flush pending messages if we have any
    for my $cache (@{$self->{buffer}}) {
        $self->{app}->SUPER::log_cached($cache);
    }

        # Empty buffer
    $self->{buffer} = [];
}

###########################################
sub post_init {
###########################################
    my($self) = @_;

    if(! exists $self->{appender}) {
       die "No appender defined for " . __PACKAGE__;
    }

    my $appenders = Log::Log4perl->appenders();
    my $appender = Log::Log4perl->appenders()->{$self->{appender}};

    if(! defined $appender) {
       die "Appender $self->{appender} not defined (yet) when " .
           __PACKAGE__ . " needed it";
    }

    $self->{app} = $appender;
}

###########################################
sub level_trigger {
###########################################
    my($level) = @_;

        # closure holding $level
    return sub {
        my($self, $params) = @_;

        return Log::Log4perl::Level::to_priority(
                 $params->{log4p_level}) >= 
               Log::Log4perl::Level::to_priority($level);
    };
}
    
###########################################
sub DESTROY {
###########################################
    my($self) = @_;
}

1;

__END__



#line 280
