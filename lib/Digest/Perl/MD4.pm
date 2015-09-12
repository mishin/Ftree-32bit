#line 1 "Digest/Perl/MD4.pm"
package Digest::Perl::MD4;

use strict;
use Exporter;
use warnings;
use vars qw($VERSION @ISA @EXPORTER @EXPORT_OK);

use integer;

@EXPORT_OK = qw(md4 md4_hex md4_base64);

@ISA = 'Exporter';
$VERSION = '1.4';

# Module logic and interface adapted from Digest::Perl::MD5 v1.5 from CPAN.
# See author information below.

# The MD4 logic Perl code has these origins:
#     MD5[0] in 8 lines of perl5
#
#     The MD5 algorithm (Message Digest 5) is a cryptographic message digest
#     algorithm.  It is the message digest algorithm used by PGP 2.x.
#
#     MD5 was designed by Ron Rivest[1], who is also the `R' in `RSA'.  MD5 is
#     described in rfc1321[2].  C source code is included with the RFC.
#
#     John Allen[3] wrote this implementation of MD5 optimised for size, in 8
#     lines of perl5:
{
    no warnings;
<<'EOF';				# quote this stuff
#!/bin/perl -iH9T4C`>_-JXF8NMS^$#)4=@<,$18%"0X4!`L0%P8*#Q4``04``04#!P`` ~JLA
@A=unpack N4C24,unpack u,$^I;@K=map{int abs 2**32*sin$_}1..64;sub L{($x=pop)
<<($n=pop)|2**$n-1&$x>>32-$n}sub M{($x=pop)-($m=1+~0)*int$x/$m}do{$l+=$r=read
STDIN,$_,64;$r++,$_.="\x80"if$r<64&&!$p++;@W=unpack V16,$_."\0"x7;$W[14]=$l*8
if$r<57;($a,$b,$c,$d)=@A;for(0..63){$a=M$b+L$A[4+4*($_>>4)+$_%4],M&{(sub{$b&$c
|$d&~$b},sub{$b&$d|$c&~$d},sub{$b^$c^$d},sub{$c^($b|~$d)})[$z=$_/16]}+$W[($A[
20+$z]+$A[24+$z]*($_%16))%16]+$K[$_]+$a;($a,$b,$c,$d)=($d,$a,$b,$c)}$v=a;for(
@A[0..3]){$_=M$_+${$v++}}}while$r>56;print unpack H32,pack V4,@A # RSA's MD5
EOF
}

#     Comments, html bugs to Adam Back[5] at adam@cypherspace.org.

# My MD4 modifications are based on reading rfc1320.txt[6].  While some
# remnants of the the highly concise nature of the orginal remain, I've made
# numerous typographical adjustments. -ota

# [0] http://www.cypherspace.org/~adam/rsa/md5.html
# [1] http://theory.lcs.mit.edu/~rivest/homepage.html
# [2] http://www.ietf.org/rfc/rfc1321.txt
# [3] mailto:allen@grumman.com
# [4] http://www.cypherspace.org/~adam/rsa/sha.html
# [5] http://www.cypherspace.org/~adam/
# [6] http://www.ietf.org/rfc/rfc1320.txt

# object part of this module
sub new {
	my $class = shift;
	bless {}, ref($class) || $class;
}

sub reset {
	my $self = shift;
	delete $self->{data};
	$self
}

sub add(@) {
	my $self = shift;
	$self->{data} .= join'', @_;
	$self
}

sub addfile {
  	my ($self,$fh) = @_;
	if (!ref($fh) && ref(\$fh) ne "GLOB") {
	    require Symbol;
	    $fh = Symbol::qualify($fh, scalar caller);
	}
	$self->{data} .= do{local$/;<$fh>};
	$self
}

sub digest {
	md4(shift->{data})
}

sub hexdigest {
	md4_hex(shift->{data})
}

sub b64digest {
	md4_base64(shift->{data})
}

# This is the actual MD4 algorithm

sub L # left-rotate
{
    my ($n, $x) = @_;
    $x<<$n|2**$n-1&$x>>32-$n;
}

sub M # mod 2**32
{
    no integer;
    my ($x) = @_;
    my $m = 1+0xffffffff;
    $x-$m*int$x/$m;
}

sub R # reverse two bit number
{
    my $n = pop;
    ($n&1)*2 + ($n&2)/2;
}

sub md4(@)
{
    my @input = grep defined && length>0, split /(.{64})/s, join '', @_;
    push @input, '' if !@input || length($input[$#input]) >= 56;
    my @A = (0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476); # initial regs
    my @L = qw(3 7 11 19 3 5 9 13 3 9 11 15); # left rotate counts
    my @O = (1, 4, 4,			# x stride for input index
	     4, 1, 1,			# y stride for input index
	     0, 0, 1);			# bitwise reverse both indexes
    my @I = map {my $z=int $_/16;my $x=$_%4; my $y=int $_%16/4;
		 $O[6+$z]&&(($x,$y)=(R($x),R($y)));
		 $O[$z]*$x+$O[3+$z]*$y} 0..47;
    my @T = (0, 0x5A827999, 0x6ED9EBA1);

    my $l = 0;
    my $p = 0;
    my ($a,$b,$c,$d);
    foreach (@input) {
	my $r=length($_);
	$l+=$r;
	$r++,$_.="\x80" if $r<64&&!$p++;
	my @W=unpack 'V16',$_."\0"x7;
	push @W, (0)x16 if @W<16;
	$W[14]=$l*8 if $r<57;		# add bit-length in low 32-bits
	($a,$b,$c,$d) = @A;
	for (0..47) {
	    my $z = int $_/16;
	    $a=L($L[4*($_>>4)+$_%4],
		 M(&{(sub{$b&$c|~$b&$d}, 	# F
		      sub{$b&$c|$b&$d|$c&$d},	# G
		      sub{$b^$c^$d}		# H
		     )[$z]}
		   +$a+$W[$I[$_]]+$T[$z]));
	    ($a,$b,$c,$d)=($d,$a,$b,$c);
	}
	my @v=($a, $b, $c, $d);
	for (0..3) {
	    $A[$_] = M($A[$_]+$v[$_]);
	}
    }
    pack 'V4', @A;
}

sub md4_hex(@) {
  unpack 'H*', &md4;
}

sub md4_base64(@) {
  encode_base64(&md4);
}


sub encode_base64 ($) {
    my $res;
    while ($_[0] =~ /(.{1,45})/gs) {
	$res .= substr pack('u', $1), 1;
	chop $res;
    }
    $res =~ tr|` -_|AA-Za-z0-9+/|;#`
    chop $res;chop $res;
    $res;
}

1;

#line 347
