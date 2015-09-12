#line 1 "Log/Log4perl/Filter/MDC.pm"
package Log::Log4perl::Filter::MDC;
use strict;
use warnings;

use Log::Log4perl::Util qw( params_check );

use base "Log::Log4perl::Filter";

sub new {
    my ( $class, %options ) = @_;

    my $self = {%options};

    params_check( $self, [qw( KeyToMatch RegexToMatch )] );

    $self->{RegexToMatch} = qr/$self->{RegexToMatch}/;

    bless $self, $class;

    return $self;
}

sub ok {
    my ( $self, %p ) = @_;

    my $context = Log::Log4perl::MDC->get_context;

    my $value = $context->{ $self->{KeyToMatch} };
    return 1
        if defined $value && $value =~ $self->{RegexToMatch};

    return 0;
}

1;

__END__



#line 98
