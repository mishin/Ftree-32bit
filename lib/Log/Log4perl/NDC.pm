#line 1 "Log/Log4perl/NDC.pm"
##################################################
package Log::Log4perl::NDC;
##################################################

use 5.006;
use strict;
use warnings;

our @NDC_STACK = ();
our $MAX_SIZE  = 5;

###########################################
sub get {
###########################################
    if(@NDC_STACK) {
        # Return elements blank separated
        return join " ", @NDC_STACK;
    } else {
        return "[undef]";
    }
}

###########################################
sub pop {
###########################################
    if(@NDC_STACK) {
        return pop @NDC_STACK;
    } else {
        return undef;
    }
}

###########################################
sub push {
###########################################
    my($self, $text) = @_;

    unless(defined $text) {
        # Somebody called us via Log::Log4perl::NDC::push("blah") ?
        $text = $self;
    }

    if(@NDC_STACK >= $MAX_SIZE) {
        CORE::pop(@NDC_STACK);
    }

    return push @NDC_STACK, $text;
}

###########################################
sub remove {
###########################################
    @NDC_STACK = ();
}

__END__



#line 152
