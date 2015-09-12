#line 1 "Log/Log4perl/Filter/LevelMatch.pm"
##################################################
package Log::Log4perl::Filter::LevelMatch;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Log::Log4perl::Util qw( params_check );

use constant _INTERNAL_DEBUG => 0;

use base qw(Log::Log4perl::Filter);

##################################################
sub new {
##################################################
    my ($class, %options) = @_;

    my $self = { LevelToMatch  => '',
                 AcceptOnMatch => 1,
                 %options,
               };
     
    params_check( $self,
                  [ qw( LevelToMatch ) ], 
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

     if($self->{LevelToMatch} eq $p{log4p_level}) {
         print "Levels match\n" if _INTERNAL_DEBUG;
         return $self->{AcceptOnMatch};
     } else {
         print "Levels don't match\n" if _INTERNAL_DEBUG;
         return !$self->{AcceptOnMatch};
     }
}

1;

__END__



#line 119
