#line 1 "Log/Log4perl/Filter/LevelRange.pm"
##################################################
package Log::Log4perl::Filter::LevelRange;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Log::Log4perl::Util qw( params_check );

use constant _INTERNAL_DEBUG => 0;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
    my ($class, %options) = @_;

    my $self = { LevelMin      => 'DEBUG',
                 LevelMax      => 'FATAL',
                 AcceptOnMatch => 1,
                 %options,
               };
     
    params_check( $self,
                  [ qw( LevelMin LevelMax ) ], 
                  [ qw( name AcceptOnMatch ) ] 
                );

    $self->{AcceptOnMatch} = Log::Log4perl::Config::boolean_to_perlish(
                                                $self->{AcceptOnMatch});

    bless $self, $class;

    return $self;
}

##################################################
sub ok {
##################################################
     my ($self, %p) = @_;

     if(Log::Log4perl::Level::to_priority($self->{LevelMin}) <= 
        Log::Log4perl::Level::to_priority($p{log4p_level}) and
        Log::Log4perl::Level::to_priority($self->{LevelMax}) >= 
        Log::Log4perl::Level::to_priority($p{log4p_level})) {
         return $self->{AcceptOnMatch};
     } else {
         return ! $self->{AcceptOnMatch};
     }
}

1;

__END__



#line 127
