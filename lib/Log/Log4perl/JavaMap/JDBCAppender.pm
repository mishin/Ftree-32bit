#line 1 "Log/Log4perl/JavaMap/JDBCAppender.pm"
package Log::Log4perl::JavaMap::JDBCAppender;

use Carp;
use strict;

sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

    my $pwd =  $data->{password}{value} || 
                die "'password' not supplied for appender '$appender_name', required for a '$data->{value}'\n";

    my $username =  $data->{user}{value} || 
                $data->{username}{value} || 
                die "'user' not supplied for appender '$appender_name', required for a '$data->{value}'\n";


    my $sql =  $data->{sql}{value} || 
                die "'sql' not supplied for appender '$appender_name', required for a '$data->{value}'\n";


    my $dsn;

    my $databaseURL = $data->{URL}{value};
    if ($databaseURL) {
        $databaseURL =~ m|^jdbc:(.+?):(.+?)://(.+?):(.+?);(.+)|;
        my $driverName = $1;
        my $databaseName = $2;
        my $hostname = $3;
        my $port = $4;
        my $params = $5;
        $dsn = "dbi:$driverName:database=$databaseName;host=$hostname;port=$port;$params";
    }elsif ($data->{datasource}{value}){
        $dsn = $data->{datasource}{value};
    }else{
        die "'databaseURL' not supplied for appender '$appender_name', required for a '$data->{value}'\n";
    }


    #this part isn't supported by log4j, it's my Log4perl
    #hack, but I think it's so useful I'm going to implement it
    #anyway
    my %bind_value_params;
    foreach my $p (keys %{$data->{params}}){
        $bind_value_params{$p} =  $data->{params}{$p}{value};
    }

    return Log::Log4perl::Appender->new("Log::Log4perl::Appender::DBI",
        datasource    => $dsn,
        username      => $username,
        password      => $pwd, 
        sql           => $sql,
        params        => \%bind_value_params,
            #warp_message also not a log4j thing, but see above
        warp_message=> $data->{warp_message}{value},  
    );
}

1;



#line 134
