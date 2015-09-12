#line 1 "Log/Log4perl/Catalyst.pm"
package Log::Log4perl::Catalyst;

use strict;
use Log::Log4perl qw(:levels);
use Log::Log4perl::Logger;

our $VERSION                  = $Log::Log4perl::VERSION;
our $CATALYST_APPENDER_SUFFIX = "catalyst_buffer";
our $LOG_LEVEL_ADJUSTMENT     = 1;

init();

##################################################
sub init {
##################################################

    my @levels = qw[ trace debug info warn error fatal ];

    Log::Log4perl->wrapper_register(__PACKAGE__);

    for my $level (@levels) {
        no strict 'refs';

        *{$level} = sub {
            my ( $self, @message ) = @_;

            local $Log::Log4perl::caller_depth =
                  $Log::Log4perl::caller_depth +
                     $LOG_LEVEL_ADJUSTMENT;

            my $logger = Log::Log4perl->get_logger();
            $logger->$level(@message);
            return 1;
        };

        *{"is_$level"} = sub {
            my ( $self, @message ) = @_;

            local $Log::Log4perl::caller_depth =
                  $Log::Log4perl::caller_depth +
                     $LOG_LEVEL_ADJUSTMENT;

            my $logger = Log::Log4perl->get_logger();
            my $func   = "is_" . $level;
            return $logger->$func;
        };
    }
}

##################################################
sub new {
##################################################
    my($class, $config, %options) = @_;

    my $self = {
        autoflush   => 0,
        abort       => 0,
        watch_delay => 0,
        %options,
    };

    if( !Log::Log4perl->initialized() ) {
        if( defined $config ) {
            if( $self->{watch_delay} ) {
                Log::Log4perl::init_and_watch( $config, $self->{watch_delay} );
            } else {
                Log::Log4perl::init( $config );
            }
        } else {
             Log::Log4perl->easy_init({
                 level  => $DEBUG,
                 layout => "[%d] [catalyst] [%p] %m%n",
             });
        }
    }

      # Unless we have autoflush, Catalyst likes to buffer all messages
      # until it calls flush(). This is somewhat unusual for Log4perl,
      # but we just put an army of buffer appenders in front of all 
      # appenders defined in the system.

    if(! $options{autoflush} ) {
        for my $appender (values %Log::Log4perl::Logger::APPENDER_BY_NAME) {
            next if $appender->{name} =~ /_$CATALYST_APPENDER_SUFFIX$/;

            # put a buffering appender in front of every appender
            # defined so far

            my $buf_app_name = "$appender->{name}_$CATALYST_APPENDER_SUFFIX";

            my $buf_app = Log::Log4perl::Appender->new(
                'Log::Log4perl::Appender::Buffer',
                name       => $buf_app_name,
                appender   => $appender->{name},
                trigger    => sub { 0 },    # only trigger on explicit flush()
            );

            Log::Log4perl->add_appender($buf_app);
            $buf_app->post_init();
            $buf_app->composite(1);

            # Point all loggers currently connected to the previously defined
            # appenders to the chained buffer appenders instead.

            foreach my $logger (
                           values %$Log::Log4perl::Logger::LOGGERS_BY_NAME){
                if(defined $logger->remove_appender( $appender->{name}, 0, 1)) {
                    $logger->add_appender( $buf_app );
                }
            }
        }
    }

    bless $self, $class;

    return $self;
}

##################################################
sub _flush {
##################################################
    my ($self) = @_;

    for my $appender (values %Log::Log4perl::Logger::APPENDER_BY_NAME) {
        next if $appender->{name} !~ /_$CATALYST_APPENDER_SUFFIX$/;

        if ($self->abort) {
            $appender->{appender}{buffer} = [];
        }
        else {
            $appender->flush();
        }
    }

    $self->abort(undef);
}

##################################################
sub abort {
##################################################
    my $self = shift;

    $self->{abort} = $_[0] if @_;

    return $self->{abort};
}

##################################################
sub levels {
##################################################
      # stub function, until we have something meaningful
    return 0;
}

##################################################
sub enable {
##################################################
      # stub function, until we have something meaningful
    return 0;
}

##################################################
sub disable {
##################################################
      # stub function, until we have something meaningful
    return 0;
}

1;

__END__



#line 369
