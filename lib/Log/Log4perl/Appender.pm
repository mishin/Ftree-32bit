#line 1 "Log/Log4perl/Appender.pm"
##################################################
package Log::Log4perl::Appender;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Config;
use Log::Log4perl::Level;
use Carp;

use constant _INTERNAL_DEBUG => 0;

our $unique_counter = 0;

##################################################
sub reset {
##################################################
    $unique_counter = 0;
}

##################################################
sub unique_name {
##################################################
        # THREADS: Need to lock here to make it thread safe
    $unique_counter++;
    my $unique_name = sprintf("app%03d", $unique_counter);
        # THREADS: Need to unlock here to make it thread safe
    return $unique_name;
}

##################################################
sub new {
##################################################
    my($class, $appenderclass, %params) = @_;

        # Pull in the specified Log::Log4perl::Appender object
    eval {

           # Eval erroneously succeeds on unknown appender classes if
           # the eval string just consists of valid perl code (e.g. an
           # appended ';' in $appenderclass variable). Fail if we see
           # anything in there that can't be class name.
        die "'$appenderclass' not a valid class name " if 
            $appenderclass =~ /[^:\w]/;

        # Check if the class/package is already available because
        # something like Class::Prototyped injected it previously.

        # Use UNIVERSAL::can to check the appender's new() method
        # [RT 28987]
        if( ! $appenderclass->can('new') ) {
            # Not available yet, try to pull it in.
            # see 'perldoc -f require' for why two evals
            eval "require $appenderclass";
                 #unless ${$appenderclass.'::IS_LOADED'};  #for unit tests, 
                                                          #see 004Config
            die $@ if $@;
        }
    };

    $@ and die "ERROR: can't load appenderclass '$appenderclass'\n$@";

    $params{name} = unique_name() unless exists $params{name};

    # If it's a Log::Dispatch::File appender, default to append 
    # mode (Log::Dispatch::File defaults to 'clobber') -- consensus 9/2002
    # (Log::Log4perl::Appender::File already defaults to 'append')
    if ($appenderclass eq 'Log::Dispatch::File' &&
        ! exists $params{mode}) {
        $params{mode} = 'append';
    }

    my $appender = $appenderclass->new(
            # Set min_level to the lowest setting. *we* are 
            # controlling this now, the appender should just
            # log it with no questions asked.
        min_level => 'debug',
            # Set 'name' and other parameters
        map { $_ => $params{$_} } keys %params,
    );

    my $self = {
                 appender  => $appender,
                 name      => $params{name},
                 layout    => undef,
                 level     => $ALL,
                 composite => 0,
               };

        #whether to collapse arrays, etc.
    $self->{warp_message} = $params{warp_message};
    if($self->{warp_message} and
       my $cref = 
       Log::Log4perl::Config::compile_if_perl($self->{warp_message})) {
        $self->{warp_message} = $cref;
    }
    
    bless $self, $class;

    return $self;
}

##################################################
sub composite { # Set/Get the composite flag
##################################################
    my ($self, $flag) = @_;

    $self->{composite} = $flag if defined $flag;
    return $self->{composite};
}

##################################################
sub threshold { # Set/Get the appender threshold
##################################################
    my ($self, $level) = @_;

    print "Setting threshold to $level\n" if _INTERNAL_DEBUG;

    if(defined $level) {
        # Checking for \d makes for a faster regex(p)
        $self->{level} = ($level =~ /^(\d+)$/) ? $level :
            # Take advantage of &to_priority's error reporting
            Log::Log4perl::Level::to_priority($level);
    }

    return $self->{level};
}

##################################################
sub log { 
##################################################
# Relay this call to Log::Log4perl::Appender:* or
# Log::Dispatch::*
##################################################
    my ($self, $p, $category, $level, $cache) = @_;

    # Check if the appender has a last-minute veto in form
    # of an "appender threshold"
    if($self->{level} > $
                        Log::Log4perl::Level::PRIORITY{$level}) {
        print "$self->{level} > $level, aborting\n" if _INTERNAL_DEBUG;
        return undef;
    }

    # Run against the (yes only one) customized filter (which in turn
    # might call other filters via the Boolean filter) and check if its
    # ok() method approves the message or blocks it.
    if($self->{filter}) {
        if($self->{filter}->ok(%$p,
                               log4p_category => $category,
                               log4p_level    => $level )) {
            print "Filter $self->{filter}->{name} passes\n" if _INTERNAL_DEBUG;
        } else {
            print "Filter $self->{filter}->{name} blocks\n" if _INTERNAL_DEBUG;
            return undef;
        }
    }

    unless($self->composite()) {

            #not defined, the normal case
        if (! defined $self->{warp_message} ){
                #join any message elements
            if (ref $p->{message} eq "ARRAY") {
                for my $i (0..$#{$p->{message}}) {
                    if( !defined $p->{message}->[ $i ] ) {
                        local $Carp::CarpLevel =
                        $Carp::CarpLevel + $Log::Log4perl::caller_depth + 1;
                        carp "Warning: Log message argument #" . 
                             ($i+1) . " undefined";
                    }
                }
                $p->{message} = 
                    join($Log::Log4perl::JOIN_MSG_ARRAY_CHAR, 
                         @{$p->{message}} 
                         );
            }
            
            #defined but false, e.g. Appender::DBI
        } elsif (! $self->{warp_message}) {
            ;  #leave the message alone
    
        } elsif (ref($self->{warp_message}) eq "CODE") {
            #defined and a subref
            $p->{message} = 
                [$self->{warp_message}->(@{$p->{message}})];
        } else {
            #defined and a function name?
            no strict qw(refs);
            $p->{message} = 
                [$self->{warp_message}->(@{$p->{message}})];
        }

        $p->{message} = $self->{layout}->render($p->{message}, 
            $category,
            $level,
            3 + $Log::Log4perl::caller_depth,
        ) if $self->layout();
    }

    my $args = [%$p, log4p_category => $category, log4p_level => $level];

    if(defined $cache) {
        $$cache = $args;
    } else {
        $self->{appender}->log(@$args);
    }

    return 1;
}

###########################################
sub log_cached {
###########################################
    my ($self, $cache) = @_;

    $self->{appender}->log(@$cache);
}

##################################################
sub name { # Set/Get the name
##################################################
    my($self, $name) = @_;

        # Somebody wants to *set* the name?
    if($name) {
        $self->{name} = $name;
    }

    return $self->{name};
}

###########################################
sub layout { # Set/Get the layout object
             # associated with this appender
###########################################
    my($self, $layout) = @_;

        # Somebody wants to *set* the layout?
    if($layout) {
        $self->{layout} = $layout;

        # somebody wants a layout, but not set yet, so give 'em default
    }elsif (! $self->{layout}) {
        $self->{layout} = Log::Log4perl::Layout::SimpleLayout
                                                ->new($self->{name});

    }

    return $self->{layout};
}

##################################################
sub filter { # Set filter
##################################################
    my ($self, $filter) = @_;

    if($filter) {
        print "Setting filter to $filter->{name}\n" if _INTERNAL_DEBUG;
        $self->{filter} = $filter;
    }

    return $self->{filter};
}

##################################################
sub AUTOLOAD { 
##################################################
# Relay everything else to the underlying 
# Log::Log4perl::Appender::* or Log::Dispatch::*
#  object
##################################################
    my $self = shift;

    no strict qw(vars);

    $AUTOLOAD =~ s/.*:://;

    if(! defined $self->{appender}) {
        die "Can't locate object method $AUTOLOAD() in ", __PACKAGE__;
    }

    return $self->{appender}->$AUTOLOAD(@_);
}

##################################################
sub DESTROY {
##################################################
    foreach my $key (keys %{$_[0]}) {
        # print "deleting $key\n";
        delete $_[0]->{$key};
    }
}

1;

__END__



#line 734
