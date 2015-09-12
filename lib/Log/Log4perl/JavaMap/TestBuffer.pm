#line 1 "Log/Log4perl/JavaMap/TestBuffer.pm"
package Log::Log4perl::JavaMap::TestBuffer;

use Carp;
use strict;
use Log::Log4perl::Appender::TestBuffer;

use constant _INTERNAL_DEBUG => 0;

sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    return Log::Log4perl::Appender->new("Log::Log4perl::Appender::TestBuffer",
                                        name => $appender_name);
}

1;



#line 71
