#line 1 "Log/Log4perl/MDC.pm"
##################################################
package Log::Log4perl::MDC;
##################################################

use 5.006;
use strict;
use warnings;

our %MDC_HASH = ();

###########################################
sub get {
###########################################
    my($class, $key) = @_;

    if($class ne __PACKAGE__) {
        # Somebody called us with Log::Log4perl::MDC::get($key)
        $key = $class;
    }

    if(exists $MDC_HASH{$key}) {
        return $MDC_HASH{$key};
    } else {
        return undef;
    }
}

###########################################
sub put {
###########################################
    my($class, $key, $value) = @_;

    if($class ne __PACKAGE__) {
        # Somebody called us with Log::Log4perl::MDC::put($key, $value)
        $value = $key;
        $key   = $class;
    }

    $MDC_HASH{$key} = $value;
}

###########################################
sub remove {
###########################################
    %MDC_HASH = ();

    1;
}

###########################################
sub get_context {
###########################################
    return \%MDC_HASH;
}

1;

__END__



#line 137
