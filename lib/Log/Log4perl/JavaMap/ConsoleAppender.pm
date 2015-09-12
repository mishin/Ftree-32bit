#line 1 "Log/Log4perl/JavaMap/ConsoleAppender.pm"
package Log::Log4perl::JavaMap::ConsoleAppender;

use Carp;
use strict;
use Log::Dispatch::Screen;


sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    if (my $t = $data->{Target}{value}) {
        if ($t eq 'System.out') {
            $stderr = 0;
        }elsif ($t eq 'System.err') {
            $stderr = 1;
        }else{
            die "ERROR: illegal value '$t' for $data->{value}.Target' in appender $appender_name\n";
        }
    }elsif (defined $data->{stderr}{value}){
        $stderr = $data->{stderr}{value};
    }else{
        $stderr = 0;
    }

    return Log::Log4perl::Appender->new("Log::Dispatch::Screen",
        name   => $appender_name,
        stderr => $stderr );
}


1;




#line 63

#line 96
