#line 1 "Crypt/RC4.pm"
#--------------------------------------------------------------------#
# Crypt::RC4
#       Date Written:   07-Jun-2000 04:15:55 PM
#       Last Modified:  13-Dec-2001 03:33:49 PM 
#       Author:         Kurt Kincaid (sifukurt@yahoo.com)
#       Copyright (c) 2001, Kurt Kincaid
#           All Rights Reserved.
#
#       This is free software and may be modified and/or
#       redistributed under the same terms as Perl itself.
#--------------------------------------------------------------------#

package Crypt::RC4;

use strict;
use vars qw( $VERSION @ISA @EXPORT $MAX_CHUNK_SIZE );

$MAX_CHUNK_SIZE = 1024 unless $MAX_CHUNK_SIZE;

require Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw(RC4);
$VERSION = '2.02';

sub new {
    my ( $class, $key )  = @_;
    my $self = bless {}, $class;
    $self->{state} = Setup( $key );
    $self->{x} = 0;
    $self->{y} = 0;
    $self;
}

sub RC4 {
    my $self;
    my( @state, $x, $y );
    if ( ref $_[0] ) {
        $self = shift;
    @state = @{ $self->{state} };
    $x = $self->{x};
    $y = $self->{y};
    } else {
        @state = Setup( shift );
    $x = $y = 0;
    }
    my $message = shift;
    my $num_pieces = do {
    my $num = length($message) / $MAX_CHUNK_SIZE;
    my $int = int $num;
    $int == $num ? $int : $int+1;
    };
    for my $piece ( 0..$num_pieces - 1 ) {
    my @message = unpack "C*", substr($message, $piece * $MAX_CHUNK_SIZE, $MAX_CHUNK_SIZE);
    for ( @message ) {
        $x = 0 if ++$x > 255;
        $y -= 256 if ($y += $state[$x]) > 255;
        @state[$x, $y] = @state[$y, $x];
        $_ ^= $state[( $state[$x] + $state[$y] ) % 256];
    }
    substr($message, $piece * $MAX_CHUNK_SIZE, $MAX_CHUNK_SIZE) = pack "C*", @message;
    }
    if ($self) {
    $self->{state} = \@state;
    $self->{x} = $x;
    $self->{y} = $y;
    }
    $message;
}

sub Setup {
    my @k = unpack( 'C*', shift );
    my @state = 0..255;
    my $y = 0;
    for my $x (0..255) {
    $y = ( $k[$x % @k] + $state[$x] + $y ) % 256;
    @state[$x, $y] = @state[$y, $x];
    }
    wantarray ? @state : \@state;
}


1;
__END__

#line 166
