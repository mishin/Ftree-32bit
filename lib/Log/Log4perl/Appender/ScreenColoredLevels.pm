#line 1 "Log/Log4perl/Appender/ScreenColoredLevels.pm"
##################################################
package Log::Log4perl::Appender::ScreenColoredLevels;
##################################################
use Log::Log4perl::Appender::Screen;
our @ISA = qw(Log::Log4perl::Appender::Screen);

use warnings;
use strict;

use Term::ANSIColor qw();
use Log::Log4perl::Level;

BEGIN {
    $Term::ANSIColor::EACHLINE="\n";
}

##################################################
sub new {
##################################################
    my($class, %options) = @_;

    my %specific_options = ( color => {} );

    for my $option ( keys %specific_options ) {
        $specific_options{ $option } = delete $options{ $option } if
            exists $options{ $option };
    }

    my $self = $class->SUPER::new( %options );
    @$self{ keys %specific_options } = values %specific_options;
    bless $self, __PACKAGE__; # rebless

      # also accept lower/mixed case levels in config
    for my $level ( keys %{ $self->{color} } ) {
        my $uclevel = uc($level);
        $self->{color}->{$uclevel} = $self->{color}->{$level};
    }

    my %default_colors = (
        TRACE   => 'yellow',
        DEBUG   => '',
        INFO    => 'green',
        WARN    => 'blue',
        ERROR   => 'magenta',
        FATAL   => 'red',
    );
    for my $level ( keys %default_colors ) {
        if ( ! exists $self->{ 'color' }->{ $level } ) {
            $self->{ 'color' }->{ $level } = $default_colors{ $level };
        }
    }

    bless $self, $class;
}
    
##################################################
sub log {
##################################################
    my($self, %params) = @_;

    my $msg = $params{ 'message' };

    if ( my $color = $self->{ 'color' }->{ $params{ 'log4p_level' } } ) {
        $msg = Term::ANSIColor::colored( $msg, $color );
    }
    
    if($self->{stderr}) {
        print STDERR $msg;
    } else {
        print $msg;
    }
}

1;

__END__



#line 236
