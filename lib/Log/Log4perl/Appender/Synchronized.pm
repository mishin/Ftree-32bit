#line 1 "Log/Log4perl/Appender/Synchronized.pm"
######################################################################
# Synchronized.pm -- 2003, 2007 Mike Schilli <m@perlmeister.com>
######################################################################
# Special appender employing a locking strategy to synchronize
# access.
######################################################################

###########################################
package Log::Log4perl::Appender::Synchronized;
###########################################

use strict;
use warnings;
use Log::Log4perl::Util::Semaphore;

our @ISA = qw(Log::Log4perl::Appender);

our $CVSVERSION   = '$Revision: 1.12 $';
our ($VERSION)    = ($CVSVERSION =~ /(\d+\.\d+)/);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        appender=> undef,
        key     => '_l4p',
        level   => 0,
        %options,
    };

    my @values = ();
    for my $param (qw(uid gid mode destroy key)) {
        push @values, $param, $self->{$param} if defined $self->{$param};
    }

    $self->{sem} = Log::Log4perl::Util::Semaphore->new(
        @values
    );

        # Pass back the appender to be synchronized as a dependency
        # to the configuration file parser
    push @{$options{l4p_depends_on}}, $self->{appender};

        # Run our post_init method in the configurator after
        # all appenders have been defined to make sure the
        # appender we're synchronizing really exists
    push @{$options{l4p_post_config_subs}}, sub { $self->post_init() };

    bless $self, $class;
}

###########################################
sub log {
###########################################
    my($self, %params) = @_;
    
    $self->{sem}->semlock();

    # Relay that to the SUPER class which needs to render the
    # message according to the appender's layout, first.
    $Log::Log4perl::caller_depth +=2;
    $self->{app}->SUPER::log(\%params, 
                             $params{log4p_category},
                             $params{log4p_level});
    $Log::Log4perl::caller_depth -=2;

    $self->{sem}->semunlock();
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

1;

__END__



#line 293
