#line 1 "Log/Log4perl/Appender/Screen.pm"
##################################################
package Log::Log4perl::Appender::Screen;
##################################################

our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name   => "unknown name",
        stderr => 1,
        utf8   => undef,
        @options,
    };

    if( $self->{utf8} ) {
        if( $self->{stderr} ) {
            binmode STDERR, ":utf8";
        } else {
            binmode STDOUT, ":utf8";
        }
    }

    bless $self, $class;
}
    
##################################################
sub log {
##################################################
    my($self, %params) = @_;

    if($self->{stderr}) {
        print STDERR $params{message};
    } else {
        print $params{message};
    }
}

1;

__END__



#line 125
