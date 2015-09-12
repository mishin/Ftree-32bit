#line 1 "Log/Log4perl/JavaMap/SyslogAppender.pm"
package Log::Log4perl::JavaMap::SyslogAppender;

use Carp;
use strict;
use Log::Dispatch::Syslog;


sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    my ($ident,    #defaults to $0
        $logopt,   #Valid options are 'cons', 'pid', 'ndelay', and 'nowait'.
        $facility, #Valid options are 'auth', 'authpriv',
                   #  'cron', 'daemon', 'kern', 'local0' through 'local7',
                   #   'mail, 'news', 'syslog', 'user', 'uucp'.  Defaults to
                   #   'user'
        $socket,   #Valid options are 'unix' or 'inet'. Defaults to 'inet'
        );

    if (defined $data->{Facility}{value}) {
        $facility = $data->{Facility}{value}
    }elsif (defined $data->{facility}{value}){
        $facility = $data->{facility}{value};
    }else{
        $facility = 'user';
    }

    if (defined $data->{Ident}{value}) {
        $ident = $data->{Ident}{value}
    }elsif (defined $data->{ident}{value}){
        $ident = $data->{ident}{value};
    }else{
        $ident = $0;
    }
    
    return Log::Log4perl::Appender->new("Log::Dispatch::Syslog",
        name      => $appender_name,
        facility  => $facility,
        ident     => $ident,
        min_level => 'debug',
    );
}

1;



#line 110
