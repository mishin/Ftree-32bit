#line 1 "Log/Log4perl/Appender/Limit.pm"
######################################################################
# Limit.pm -- 2003, Mike Schilli <m@perlmeister.com>
######################################################################
# Special composite appender limiting the number of messages relayed
# to its appender(s).
######################################################################

###########################################
package Log::Log4perl::Appender::Limit;
###########################################

use strict;
use warnings;
use Storable;

our @ISA = qw(Log::Log4perl::Appender);

our $CVSVERSION   = '$Revision: 1.7 $';
our ($VERSION)    = ($CVSVERSION =~ /(\d+\.\d+)/);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        max_until_flushed   => undef,
        max_until_discarded => undef,
        appender_method_on_flush 
                            => undef,
        appender            => undef,
        accumulate          => 1,
        persistent          => undef,
        block_period        => 3600,
        buffer              => [],
        %options,
    };

        # Pass back the appender to be limited as a dependency
        # to the configuration file parser
    push @{$options{l4p_depends_on}}, $self->{appender};

        # Run our post_init method in the configurator after
        # all appenders have been defined to make sure the
        # appenders we're connecting to really exist.
    push @{$options{l4p_post_config_subs}}, sub { $self->post_init() };

    bless $self, $class;

    if(defined $self->{persistent}) {
        $self->restore();
    }

    return $self;
}

###########################################
sub log {
###########################################
    my($self, %params) = @_;
    
    local $Log::Log4perl::caller_depth =
        $Log::Log4perl::caller_depth + 2;

        # Check if message needs to be discarded
    my $discard = 0;
    if(defined $self->{max_until_discarded} and
       scalar @{$self->{buffer}} >= $self->{max_until_discarded} - 1) {
        $discard = 1;
    }

        # Check if we need to flush
    my $flush = 0;
    if(defined $self->{max_until_flushed} and
       scalar @{$self->{buffer}} >= $self->{max_until_flushed} - 1) {
        $flush = 1;
    }

    if(!$flush and
       (exists $self->{sent_last} and
        $self->{sent_last} + $self->{block_period} > time()
       )
      ) {
            # Message needs to be blocked for now.
        return if $discard;

            # Ask the appender to save a cached message in $cache
        $self->{app}->SUPER::log(\%params,
                             $params{log4p_category},
                             $params{log4p_level}, \my $cache);

            # Save message and other parameters
        push @{$self->{buffer}}, $cache if $self->{accumulate};

        $self->save() if $self->{persistent};

        return;
    }

    # Relay all messages we got to the SUPER class, which needs to render the
    # messages according to the appender's layout, first.

        # Log pending messages if we have any
    $self->flush();

        # Log current message as well
    $self->{app}->SUPER::log(\%params,
                             $params{log4p_category},
                             $params{log4p_level});

    $self->{sent_last} = time();

        # We need to store the timestamp persistently, if requested
    $self->save() if $self->{persistent};
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
sub save {
###########################################
    my($self) = @_;

    my $pdata = [$self->{buffer}, $self->{sent_last}];

        # Save the buffer if we're in persistent mode
    store $pdata, $self->{persistent} or
        die "Cannot save messages in $self->{persistent} ($!)";
}

###########################################
sub restore {
###########################################
    my($self) = @_;

    if(-f $self->{persistent}) {
        my $pdata = retrieve $self->{persistent} or
            die "Cannot retrieve messages from $self->{persistent} ($!)";
        ($self->{buffer}, $self->{sent_last}) = @$pdata;
    }
}

###########################################
sub flush {
###########################################
    my($self) = @_;

        # Log pending messages if we have any
    for(@{$self->{buffer}}) {
        $self->{app}->SUPER::log_cached($_);
    }

      # call flush() on the attached appender if so desired.
    if( $self->{appender_method_on_flush} ) {
        no strict 'refs';
        my $method = $self->{appender_method_on_flush};
        $self->{app}->$method();
    }

        # Empty buffer
    $self->{buffer} = [];
}

###########################################
sub DESTROY {
###########################################
    my($self) = @_;

}

1;

__END__



#line 341
