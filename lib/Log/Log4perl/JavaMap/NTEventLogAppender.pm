#line 1 "Log/Log4perl/JavaMap/NTEventLogAppender.pm"
package Log::Log4perl::JavaMap::NTEventLogAppender;

use Carp;
use strict;



sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    my ($source,   #        
        );

    if (defined $data->{Source}{value}) {
        $source = $data->{Source}{value}
    }elsif (defined $data->{source}{value}){
        $source = $data->{source}{value};
    }else{
        $source = 'user';
    }

    
    return Log::Log4perl::Appender->new("Log::Dispatch::Win32EventLog",
        name      => $appender_name,
        source    => $source,
        min_level => 'debug',
    );
}

1;



#line 92
