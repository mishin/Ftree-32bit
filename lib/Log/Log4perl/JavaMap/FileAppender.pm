#line 1 "Log/Log4perl/JavaMap/FileAppender.pm"
package Log::Log4perl::JavaMap::FileAppender;

use Carp;
use strict;
use Log::Dispatch::File;


sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    my $filename =  $data->{File}{value} || 
                $data->{filename}{value} || 
                die "'File' not supplied for appender '$appender_name', required for a '$data->{value}'\n";

    my $mode;
    if (defined($data->{Append}{value})){
        if (lc $data->{Append}{value} eq 'true' || $data->{Append}{value} == 1){
            $mode = 'append';
        }elsif (lc $data->{Append}{value} eq 'false' || $data->{Append}{value} == 0) {
            $mode = 'write';
        }elsif($data->{Append} =~ /^(write|append)$/){
            $mode = $data->{Append}
        }else{
            die "'$data->{Append}' is not a legal value for Append for appender '$appender_name', '$data->{value}'\n";
        }
    }else{
        $mode = 'append';
    }

    my $autoflush;
    if (defined($data->{BufferedIO}{value})){
        if (lc $data->{BufferedIO}{value} eq 'true' || $data->{BufferedIO}{value}){
            $autoflush = 1;
        }elsif (lc $data->{BufferedIO}{value} eq 'true' || ! $data->{BufferedIO}{value}) {
            $autoflush = 0;
        }else{
            die "'$data->{BufferedIO}' is not a legal value for BufferedIO for appender '$appender_name', '$data->{value}'\n";
        }
    }else{
        $autoflush = 1;
    }


    return Log::Log4perl::Appender->new("Log::Dispatch::File",
        name      => $appender_name,
        filename  => $filename,
        mode      => $mode,
        autoflush => $autoflush,
    );
}

1;



#line 118
