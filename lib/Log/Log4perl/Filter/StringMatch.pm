#line 1 "Log/Log4perl/Filter/StringMatch.pm"
##################################################
package Log::Log4perl::Filter::StringMatch;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Config;
use Log::Log4perl::Util qw( params_check );

use constant _INTERNAL_DEBUG => 0;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
     my ($class, %options) = @_;

     print join('-', %options) if _INTERNAL_DEBUG;

     my $self = { StringToMatch => undef,
                  AcceptOnMatch => 1,
                  %options,
                };
     
     params_check( $self,
                  [ qw( StringToMatch ) ], 
                  [ qw( name AcceptOnMatch ) ] 
                );

     $self->{AcceptOnMatch} = Log::Log4perl::Config::boolean_to_perlish(
                                                 $self->{AcceptOnMatch});

     $self->{StringToMatch} = qr($self->{StringToMatch});

     bless $self, $class;

     return $self;
}

##################################################
sub ok {
##################################################
     my ($self, %p) = @_;

     local($_) = join $
                     Log::Log4perl::JOIN_MSG_ARRAY_CHAR, @{$p{message}};

     if($_ =~ $self->{StringToMatch}) {
         print "Strings match\n" if _INTERNAL_DEBUG;
         return $self->{AcceptOnMatch};
     } else {
         print "Strings don't match ($_/$self->{StringToMatch})\n" 
             if _INTERNAL_DEBUG;
         return !$self->{AcceptOnMatch};
     }
}

1;

__END__



#line 127
