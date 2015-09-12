#line 1 "Log/Log4perl.pm"
##################################################
package Log::Log4perl;
##################################################

END { local($?); Log::Log4perl::Logger::cleanup(); }

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Util;
use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Log::Log4perl::Appender;

our $VERSION = '1.46';

   # set this to '1' if you're using a wrapper
   # around Log::Log4perl
our $caller_depth = 0;

    #this is a mapping of convenience names to opcode masks used in
    #$ALLOWED_CODE_OPS_IN_CONFIG_FILE below
our %ALLOWED_CODE_OPS = (
    'safe'        => [ ':browse' ],
    'restrictive' => [ ':default' ],
);

our %WRAPPERS_REGISTERED = map { $_ => 1 } qw(Log::Log4perl);

    #set this to the opcodes which are allowed when
    #$ALLOW_CODE_IN_CONFIG_FILE is set to a true value
    #if undefined, there are no restrictions on code that can be
    #excuted
our @ALLOWED_CODE_OPS_IN_CONFIG_FILE;

    #this hash lists things that should be exported into the Safe
    #compartment.  The keys are the package the symbol should be
    #exported from and the values are array references to the names
    #of the symbols (including the leading type specifier)
our %VARS_SHARED_WITH_SAFE_COMPARTMENT = (
    main => [ '%ENV' ],
);

    #setting this to a true value will allow Perl code to be executed
    #within the config file.  It works in conjunction with
    #$ALLOWED_CODE_OPS_IN_CONFIG_FILE, which if defined restricts the
    #opcodes which can be executed using the 'Safe' module.
    #setting this to a false value disables code execution in the
    #config file
our $ALLOW_CODE_IN_CONFIG_FILE = 1;

    #arrays in a log message will be joined using this character,
    #see Log::Log4perl::Appender::DBI
our $JOIN_MSG_ARRAY_CHAR = '';

    #version required for XML::DOM, to enable XML Config parsing
    #and XML Config unit tests
our $DOM_VERSION_REQUIRED = '1.29'; 

our $CHATTY_DESTROY_METHODS = 0;

our $LOGDIE_MESSAGE_ON_STDERR = 1;
our $LOGEXIT_CODE             = 1;
our %IMPORT_CALLED;

our $EASY_CLOSURES = {};

  # to throw refs as exceptions via logcarp/confess, turn this off
our $STRINGIFY_DIE_MESSAGE = 1;

use constant _INTERNAL_DEBUG => 0;

##################################################
sub import {
##################################################
    my($class) = shift;

    my $caller_pkg = caller();

    return 1 if $IMPORT_CALLED{$caller_pkg}++;

    my(%tags) = map { $_ => 1 } @_;

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        $tags{':levels'} = 1;
        $tags{':nowarn'} = 1;
        $tags{'get_logger'} = 1;
    }

    if(exists $tags{':no_extra_logdie_message'}) {
        $Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR = 0;
        delete $tags{':no_extra_logdie_message'};
    }

    if(exists $tags{get_logger}) {
        # Export get_logger into the calling module's 
        no strict qw(refs);
        *{"$caller_pkg\::get_logger"} = *get_logger;

        delete $tags{get_logger};
    }

    if(exists $tags{':levels'}) {
        # Export log levels ($DEBUG, $INFO etc.) from Log4perl::Level
        for my $key (keys %Log::Log4perl::Level::PRIORITY) {
            my $name  = "$caller_pkg\::$key";
               # Need to split this up in two lines, or CVS will
               # mess it up.
            my $value = $
                        Log::Log4perl::Level::PRIORITY{$key};
            no strict qw(refs);
            *{"$name"} = \$value;
        }

        delete $tags{':levels'};
    }

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        delete $tags{':easy'};

            # Define default logger object in caller's package
        my $logger = get_logger("$caller_pkg");
        
            # Define DEBUG, INFO, etc. routines in caller's package
        for(qw(TRACE DEBUG INFO WARN ERROR FATAL ALWAYS)) {
            my $level   = $_;
            $level = "OFF" if $level eq "ALWAYS";
            my $lclevel = lc($_);
            easy_closure_create($caller_pkg, $_, sub {
                Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
                $logger->{$level}->($logger, @_, $level);
            }, $logger);
        }

            # Define LOGCROAK, LOGCLUCK, etc. routines in caller's package
        for(qw(LOGCROAK LOGCLUCK LOGCARP LOGCONFESS)) {
            my $method = "Log::Log4perl::Logger::" . lc($_);

            easy_closure_create($caller_pkg, $_, sub {
                unshift @_, $logger;
                goto &$method;
            }, $logger);
        }

            # Define LOGDIE, LOGWARN
         easy_closure_create($caller_pkg, "LOGDIE", sub {
             Log::Log4perl::Logger::init_warn() unless 
                     $Log::Log4perl::Logger::INITIALIZED or
                     $Log::Log4perl::Logger::NON_INIT_WARNED;
             $logger->{FATAL}->($logger, @_, "FATAL");
             $Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR ?
                 CORE::die(Log::Log4perl::Logger::callerline(join '', @_)) :
                 exit $Log::Log4perl::LOGEXIT_CODE;
         }, $logger);

         easy_closure_create($caller_pkg, "LOGEXIT", sub {
            Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
            $logger->{FATAL}->($logger, @_, "FATAL");
            exit $Log::Log4perl::LOGEXIT_CODE;
         }, $logger);

        easy_closure_create($caller_pkg, "LOGWARN", sub {
            Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
            $logger->{WARN}->($logger, @_, "WARN");
            CORE::warn(Log::Log4perl::Logger::callerline(join '', @_))
                if $Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR;
        }, $logger);
    }

    if(exists $tags{':nowarn'}) {
        $Log::Log4perl::Logger::NON_INIT_WARNED = 1;
        delete $tags{':nowarn'};
    }

    if(exists $tags{':nostrict'}) {
        $Log::Log4perl::Logger::NO_STRICT = 1;
        delete $tags{':nostrict'};
    }

    if(exists $tags{':resurrect'}) {
        my $FILTER_MODULE = "Filter::Util::Call";
        if(! Log::Log4perl::Util::module_available($FILTER_MODULE)) {
            die "$FILTER_MODULE required with :resurrect" .
                "(install from CPAN)";
        }
        eval "require $FILTER_MODULE" or die "Cannot pull in $FILTER_MODULE";
        Filter::Util::Call::filter_add(
            sub {
                my($status);
                s/^\s*###l4p// if
                    ($status = Filter::Util::Call::filter_read()) > 0;
                $status;
                });
        delete $tags{':resurrect'};
    }

    if(keys %tags) {
        # We received an Option we couldn't understand.
        die "Unknown Option(s): @{[keys %tags]}";
    }
}

##################################################
sub initialized {
##################################################
    return $Log::Log4perl::Logger::INITIALIZED;
}

##################################################
sub new {
##################################################
    die "THIS CLASS ISN'T FOR DIRECT USE. " .
        "PLEASE CHECK 'perldoc " . __PACKAGE__ . "'.";
}

##################################################
sub reset { # Mainly for debugging/testing
##################################################
    # Delegate this to the logger ...
    return Log::Log4perl::Logger->reset();
}

##################################################
sub init_once { # Call init only if it hasn't been
                # called yet.
##################################################
    init(@_) unless $Log::Log4perl::Logger::INITIALIZED;
}

##################################################
sub init { # Read the config file
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init(@args);
}

##################################################
sub init_and_watch { 
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init_and_watch(@args);
}


##################################################
sub easy_init { # Initialize the root logger with a screen appender
##################################################
    my($class, @args) = @_;

    # Did somebody call us with Log::Log4perl::easy_init()?
    if(ref($class) or $class =~ /^\d+$/) {
        unshift @args, $class;
    }

    # Reset everything first
    Log::Log4perl->reset();

    my @loggers = ();

    my %default = ( level    => $DEBUG,
                    file     => "STDERR",
                    utf8     => undef,
                    category => "",
                    layout   => "%d %m%n",
                  );

    if(!@args) {
        push @loggers, \%default;
    } else {
        for my $arg (@args) {
            if($arg =~ /^\d+$/) {
                my %logger = (%default, level => $arg);
                push @loggers, \%logger;
            } elsif(ref($arg) eq "HASH") {
                my %logger = (%default, %$arg);
                push @loggers, \%logger;
            }
        }
    }

    for my $logger (@loggers) {

        my $app;

        if($logger->{file} =~ /^stderr$/i) {
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::Screen",
                utf8 => $logger->{utf8});
        } elsif($logger->{file} =~ /^stdout$/i) {
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::Screen",
                stderr => 0,
                utf8   => $logger->{utf8});
        } else {
            my $binmode;
            if($logger->{file} =~ s/^(:.*?)>/>/) {
                $binmode = $1;
            }
            $logger->{file} =~ /^(>)?(>)?/;
            my $mode = ($2 ? "append" : "write");
            $logger->{file} =~ s/.*>+\s*//g;
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::File",
                filename => $logger->{file},
                mode     => $mode,
                utf8     => $logger->{utf8},
                binmode  => $binmode,
            );
        }

        my $layout = Log::Log4perl::Layout::PatternLayout->new(
                                                        $logger->{layout});
        $app->layout($layout);

        my $log = Log::Log4perl->get_logger($logger->{category});
        $log->level($logger->{level});
        $log->add_appender($app);
    }

    $Log::Log4perl::Logger::INITIALIZED = 1;
}

##################################################
sub wrapper_register {  
##################################################
    my $wrapper = $_[-1];

    $WRAPPERS_REGISTERED{ $wrapper } = 1;
}

##################################################
sub get_logger {  # Get an instance (shortcut)
##################################################
    # get_logger() can be called in the following ways:
    #
    #   (1) Log::Log4perl::get_logger()     => ()
    #   (2) Log::Log4perl->get_logger()     => ("Log::Log4perl")
    #   (3) Log::Log4perl::get_logger($cat) => ($cat)
    #   
    #   (5) Log::Log4perl->get_logger($cat) => ("Log::Log4perl", $cat)
    #   (6)   L4pSubclass->get_logger($cat) => ("L4pSubclass", $cat)

    # Note that (4) L4pSubclass->get_logger() => ("L4pSubclass")
    # is indistinguishable from (3) and therefore can't be allowed.
    # Wrapper classes always have to specify the category explicitly.

    my $category;

    if(@_ == 0) {
          # 1
        my $level = 0;
        do { $category = scalar caller($level++);
        } while exists $WRAPPERS_REGISTERED{ $category };

    } elsif(@_ == 1) {
          # 2, 3
        $category = $_[0];

        my $level = 0;
        while(exists $WRAPPERS_REGISTERED{ $category }) { 
            $category = scalar caller($level++);
        }

    } else {
          # 5, 6
        $category = $_[1];
    }

    # Delegate this to the logger module
    return Log::Log4perl::Logger->get_logger($category);
}

###########################################
sub caller_depth_offset {
###########################################
    my( $level ) = @_;

    my $category;

    { 
        my $category = scalar caller($level + 1);

        if(defined $category and
           exists $WRAPPERS_REGISTERED{ $category }) {
            $level++;
            redo;
        }
    }

    return $level;
}

##################################################
sub appenders {  # Get a hashref of all defined appender wrappers
##################################################
    return \%Log::Log4perl::Logger::APPENDER_BY_NAME;
}

##################################################
sub add_appender { # Add an appender to the system, but don't assign
	           # it to a logger yet
##################################################
    my($class, $appender) = @_;

    my $name = $appender->name();
    die "Mandatory parameter 'name' missing in appender" unless defined $name;

      # Make it known by name in the Log4perl universe
      # (so that composite appenders can find it)
    Log::Log4perl->appenders()->{ $name } = $appender;
}

##################################################
# Return number of appenders changed
sub appender_thresholds_adjust {  # Readjust appender thresholds
##################################################
        # If someone calls L4p-> and not L4p::
    shift if $_[0] eq __PACKAGE__;
    my($delta, $appenders) = @_;
	my $retval = 0;

    if($delta == 0) {
          # Nothing to do, no delta given.
        return;
    }

    if(defined $appenders) {
            # Map names to objects
        $appenders = [map { 
                       die "Unkown appender: '$_'" unless exists
                          $Log::Log4perl::Logger::APPENDER_BY_NAME{
                            $_};
                       $Log::Log4perl::Logger::APPENDER_BY_NAME{
                         $_} 
                      } @$appenders];
    } else {
            # Just hand over all known appenders
        $appenders = [values %{Log::Log4perl::appenders()}] unless 
            defined $appenders;
    }

        # Change all appender thresholds;
    foreach my $app (@$appenders) {
        my $old_thres = $app->threshold();
        my $new_thres;
        if($delta > 0) {
            $new_thres = Log::Log4perl::Level::get_higher_level(
                             $old_thres, $delta);
        } else {
            $new_thres = Log::Log4perl::Level::get_lower_level(
                             $old_thres, -$delta);
        }

        ++$retval if ($app->threshold($new_thres) == $new_thres);
    }
	return $retval;
}

##################################################
sub appender_by_name {  # Get a (real) appender by name
##################################################
        # If someone calls L4p->appender_by_name and not L4p::appender_by_name
    shift if $_[0] eq __PACKAGE__;

    my($name) = @_;

    if(defined $name and
       exists $Log::Log4perl::Logger::APPENDER_BY_NAME{
                 $name}) {
        return $Log::Log4perl::Logger::APPENDER_BY_NAME{
                 $name}->{appender};
    } else {
        return undef;
    }
}

##################################################
sub eradicate_appender {  # Remove an appender from the system
##################################################
        # If someone calls L4p->... and not L4p::...
    shift if $_[0] eq __PACKAGE__;
    Log::Log4perl::Logger->eradicate_appender(@_);
}

##################################################
sub infiltrate_lwp {  # 
##################################################
    no warnings qw(redefine);

    my $l4p_wrapper = sub {
        my($prio, @message) = @_;
        local $Log::Log4perl::caller_depth =
              $Log::Log4perl::caller_depth + 2;
        get_logger(scalar caller(1))->log($prio, @message);
    };

    *LWP::Debug::trace = sub { 
        $l4p_wrapper->($INFO, @_); 
    };
    *LWP::Debug::conns =
    *LWP::Debug::debug = sub { 
        $l4p_wrapper->($DEBUG, @_); 
    };
}

##################################################
sub easy_closure_create {
##################################################
    my($caller_pkg, $entry, $code, $logger) = @_;

    no strict 'refs';

    print("easy_closure: Setting shortcut $caller_pkg\::$entry ", 
         "(logger=$logger\n") if _INTERNAL_DEBUG;

    $EASY_CLOSURES->{ $caller_pkg }->{ $entry } = $logger;
    *{"$caller_pkg\::$entry"} = $code;
}

###########################################
sub easy_closure_cleanup {
###########################################
    my($caller_pkg, $entry) = @_;

    no warnings 'redefine';
    no strict 'refs';

    my $logger = $EASY_CLOSURES->{ $caller_pkg }->{ $entry };

    print("easy_closure: Nuking easy shortcut $caller_pkg\::$entry ", 
         "(logger=$logger\n") if _INTERNAL_DEBUG;

    *{"$caller_pkg\::$entry"} = sub { };
    delete $EASY_CLOSURES->{ $caller_pkg }->{ $entry };
}

##################################################
sub easy_closure_category_cleanup {
##################################################
    my($caller_pkg) = @_;

    if(! exists $EASY_CLOSURES->{ $caller_pkg } ) {
        return 1;
    }

    for my $entry ( keys %{ $EASY_CLOSURES->{ $caller_pkg } } ) {
        easy_closure_cleanup( $caller_pkg, $entry );
    }

    delete $EASY_CLOSURES->{ $caller_pkg };
}

###########################################
sub easy_closure_global_cleanup {
###########################################

    for my $caller_pkg ( keys %$EASY_CLOSURES ) {
        easy_closure_category_cleanup( $caller_pkg );
    }
}

###########################################
sub easy_closure_logger_remove {
###########################################
    my($class, $logger) = @_;

    PKG: for my $caller_pkg ( keys %$EASY_CLOSURES ) {
        for my $entry ( keys %{ $EASY_CLOSURES->{ $caller_pkg } } ) {
            if( $logger == $EASY_CLOSURES->{ $caller_pkg }->{ $entry } ) {
                easy_closure_category_cleanup( $caller_pkg );
                next PKG;
            }
        }
    }
}

##################################################
sub remove_logger {
##################################################
    my ($class, $logger) = @_;

    # Any stealth logger convenience function still using it will
    # now become a no-op.
    Log::Log4perl->easy_closure_logger_remove( $logger );

    # Remove the logger from the system
    delete $Log::Log4perl::Logger::LOGGERS_BY_NAME->{ $logger->{category} };
}

1;

__END__



#line 2957
