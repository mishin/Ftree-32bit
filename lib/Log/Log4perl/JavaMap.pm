#line 1 "Log/Log4perl/JavaMap.pm"
package Log::Log4perl::JavaMap;

use Carp;
use strict;

use constant _INTERNAL_DEBUG => 0;

our %translate = (
    'org.apache.log4j.ConsoleAppender' => 
        'Log::Log4perl::JavaMap::ConsoleAppender',
    'org.apache.log4j.FileAppender'    => 
        'Log::Log4perl::JavaMap::FileAppender',
    'org.apache.log4j.RollingFileAppender'    => 
        'Log::Log4perl::JavaMap::RollingFileAppender',
    'org.apache.log4j.TestBuffer'    => 
        'Log::Log4perl::JavaMap::TestBuffer',
     'org.apache.log4j.jdbc.JDBCAppender'    => 
        'Log::Log4perl::JavaMap::JDBCAppender',
     'org.apache.log4j.SyslogAppender'    => 
        'Log::Log4perl::JavaMap::SyslogAppender',
     'org.apache.log4j.NTEventLogAppender'    => 
        'Log::Log4perl::JavaMap::NTEventLogAppender',
);

our %user_defined;

sub get {
    my ($appender_name, $appender_data) = @_;

    print "Trying to map $appender_name\n" if _INTERNAL_DEBUG;

    $appender_data->{value} ||
            die "ERROR: you didn't tell me how to implement your appender " .
                "'$appender_name'";

    my $perl_class = $translate{$appender_data->{value}} || 
                     $user_defined{$appender_data->{value}} ||
            die "ERROR:  I don't know how to make a '$appender_data->{value}' " .
                "to implement your appender '$appender_name', that's not a " .
                "supported class\n";
    eval {
        eval "require $perl_class";  #see 'perldoc -f require' for why two evals
        die $@ if $@;
    };
    $@ and die "ERROR: trying to set appender for $appender_name to " .
               "$appender_data->{value} using $perl_class failed\n$@  \n";

    my $app = $perl_class->new($appender_name, $appender_data);
    return $app;
}

#an external api to the two hashes
sub translate {
    my $java_class = shift;

    return $translate{$java_class} || 
            $user_defined{$java_class};
}

1;




#line 185
