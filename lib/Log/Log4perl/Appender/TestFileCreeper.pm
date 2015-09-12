#line 1 "Log/Log4perl/Appender/TestFileCreeper.pm"
##################################################
package Log::Log4perl::Appender::TestFileCreeper;
##################################################
# Test appender, intentionally slow. It writes 
# out one byte at a time to provoke sync errors.
# Don't use it, unless for testing.
##################################################

use warnings;
use strict;

use Log::Log4perl::Appender::File;

our @ISA = qw(Log::Log4perl::Appender::File);

##################################################
sub log {
##################################################
    my($self, %params) = @_;

    my $fh = $self->{fh};

    for (split //, $params{message}) {
        print $fh $_;
        my $oldfh = select $self->{fh}; 
        $| = 1; 
        select $oldfh;
    }
}

1;

__END__



#line 90
