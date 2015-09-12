#line 1 "Log/Log4perl/Filter.pm"
##################################################
package Log::Log4perl::Filter;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;

use constant _INTERNAL_DEBUG => 0;

our %FILTERS_DEFINED = ();

##################################################
sub new {
##################################################
    my($class, $name, $action) = @_;
  
    print "Creating filter $name\n" if _INTERNAL_DEBUG;

    my $self = { name => $name };
    bless $self, $class;

    if(ref($action) eq "CODE") {
        # it's a code ref
        $self->{ok} = $action;
    } else {
        # it's something else
        die "Code for ($name/$action) not properly defined";
    }

    return $self;
}

##################################################
sub register {         # Register a filter by name
                       # (Passed on to subclasses)
##################################################
    my($self) = @_;

    by_name($self->{name}, $self);
}

##################################################
sub by_name {        # Get/Set a filter object by name
##################################################
    my($name, $value) = @_;

    if(defined $value) {
        $FILTERS_DEFINED{$name} = $value;
    }

    if(exists $FILTERS_DEFINED{$name}) {
        return $FILTERS_DEFINED{$name};
    } else {
        return undef;
    }
}

##################################################
sub reset {
##################################################
    %FILTERS_DEFINED = ();
}

##################################################
sub ok {
##################################################
    my($self, %p) = @_;

    print "Calling $self->{name}'s ok method\n" if _INTERNAL_DEBUG;

        # Force filter classes to define their own
        # ok(). Exempt are only sub {..} ok functions,
        # defined in the conf file.
    die "This is to be overridden by the filter" unless
         defined $self->{ok};

    # What should we set the message in $_ to? The most logical
    # approach seems to be to concat all parts together. If some
    # filter wants to dissect the parts, it still can examine %p,
    # which gets passed to the subroutine and contains the chunks
    # in $p{message}.
        # Split because of CVS
    local($_) = join $
                     Log::Log4perl::JOIN_MSG_ARRAY_CHAR, @{$p{message}};
    print "\$_ is '$_'\n" if _INTERNAL_DEBUG;

    my $decision = $self->{ok}->(%p);

    print "$self->{name}'s ok'ed: ", 
          ($decision ? "yes" : "no"), "\n" if _INTERNAL_DEBUG;

    return $decision;
}

1;

__END__



#line 369
