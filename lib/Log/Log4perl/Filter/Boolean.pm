#line 1 "Log/Log4perl/Filter/Boolean.pm"
##################################################
package Log::Log4perl::Filter::Boolean;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;

use constant _INTERNAL_DEBUG => 0;

use base qw(Log::Log4perl::Filter);

##################################################
sub new {
##################################################
    my ($class, %options) = @_;

    my $self = { params => {},
                 %options,
               };
     
    bless $self, $class;
     
    print "Compiling '$options{logic}'\n" if _INTERNAL_DEBUG;

        # Set up meta-decider for later
    $self->compile_logic($options{logic});

    return $self;
}

##################################################
sub ok {
##################################################
     my ($self, %p) = @_;

     return $self->eval_logic(\%p);
}

##################################################
sub compile_logic {
##################################################
    my ($self, $logic) = @_;

       # Extract Filter placeholders in logic as defined
       # in configuration file.
    while($logic =~ /([\w_-]+)/g) {
            # Get the corresponding filter object
        my $filter = Log::Log4perl::Filter::by_name($1);
        die "Filter $filter required by Boolean filter, but not defined" 
            unless $filter;

        $self->{params}->{$1} = $filter;
    }

        # Fabricate a parameter list: A1/A2/A3 => $A1, $A2, $A3
    my $plist = join ', ', map { '$' . $_ } keys %{$self->{params}};

        # Replace all the (dollar-less) placeholders in the code with
        # calls to their respective coderefs.  
        $logic =~ s/([\w_-]+)/\&\$$1/g;

        # Set up the meta decider, which transforms the config file
        # logic into compiled perl code
    my $func = <<EOT;
        sub { 
            my($plist) = \@_;
            $logic;
        }
EOT

    print "func=$func\n" if _INTERNAL_DEBUG;

    my $eval_func = eval $func;

    if(! $eval_func) {
        die "Syntax error in Boolean filter logic: $eval_func";
    }

    $self->{eval_func} = $eval_func;
}

##################################################
sub eval_logic {
##################################################
    my($self, $p) = @_;

    my @plist = ();

        # Eval the results of all filters referenced
        # in the code (although the order of keys is
        # not predictable, it is consistent :)
    for my $param (keys %{$self->{params}}) {
        # Pass a coderef as a param that will run the filter's ok method and
        # return a 1 or 0.  
        print "Passing filter $param\n" if _INTERNAL_DEBUG;
        push(@plist, sub {
            return $self->{params}->{$param}->ok(%$p) ? 1 : 0
        });
    }

        # Now pipe the parameters into the canned function,
        # have it evaluate the logic and return the final
        # decision
    print "Passing in (", join(', ', @plist), ")\n" if _INTERNAL_DEBUG;
    return $self->{eval_func}->(@plist);
}

1;

__END__



#line 212
