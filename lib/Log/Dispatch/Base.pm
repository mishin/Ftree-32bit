#line 1 "Log/Dispatch/Base.pm"
package Log::Dispatch::Base;

use strict;
use warnings;

our $VERSION = '2.45';

sub _get_callbacks {
    shift;
    my %p = @_;

    return unless exists $p{callbacks};

    return @{ $p{callbacks} }
        if ref $p{callbacks} eq 'ARRAY';

    return $p{callbacks}
        if ref $p{callbacks} eq 'CODE';

    return;
}

sub _apply_callbacks {
    my $self = shift;
    my %p    = @_;

    my $msg = delete $p{message};
    foreach my $cb ( @{ $self->{callbacks} } ) {
        $msg = $cb->( message => $msg, %p );
    }

    return $msg;
}

sub add_callback {
    my $self  = shift;
    my $value = shift;

    Carp::carp("given value $value is not a valid callback")
        unless ref $value eq 'CODE';

    $self->{callbacks} ||= [];
    push @{ $self->{callbacks} }, $value;

    return;
}

1;

# ABSTRACT: Code shared by dispatch and output objects.

__END__

#line 92
