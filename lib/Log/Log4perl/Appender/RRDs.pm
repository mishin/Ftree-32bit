#line 1 "Log/Log4perl/Appender/RRDs.pm"
##################################################
package Log::Log4perl::Appender::RRDs;
##################################################
our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;
use RRDs;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name             => "unknown name",
        dbname           => undef,
        rrdupd_params => [],
        @options,
    };

    die "Mandatory parameter 'dbname' missing" unless
        defined $self->{dbname};

    bless $self, $class;

    return $self;
}

##################################################
sub log {
##################################################
    my($self, %params) = @_;

    #print "UPDATE: '$self->{dbname}' - '$params{message}'\n";

    RRDs::update($self->{dbname}, 
                 @{$params{rrdupd_params}},
                 $params{message}) or
        die "Cannot update rrd $self->{dbname} ",
            "with $params{message} ($!)";
}

1;

__END__



#line 135
