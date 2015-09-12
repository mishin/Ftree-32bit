#line 1 "Log/Log4perl/Layout/SimpleLayout.pm"
##################################################
package Log::Log4perl::Layout::SimpleLayout;
##################################################
# as documented in
# http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/SimpleLayout.html
##################################################

use 5.006;
use strict;
use warnings;
use Log::Log4perl::Level;

no strict qw(refs);
use base qw(Log::Log4perl::Layout);

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;

    return $self;
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    return "$priority - $message\n";
}

1;

__END__



#line 98
