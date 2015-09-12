#line 1 "Digest/MD4.pm"
package Digest::MD4;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);

$VERSION = '1.9';  # ActivePerl version adds hexhash() for compatibility

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(md4 md4_hex md4_base64);

require DynaLoader;
@ISA=qw(DynaLoader);

eval {
    Digest::MD4->bootstrap($VERSION);
};
if ($@) {
    my $olderr = $@;
    eval {
	# Try to load the pure perl version
	require Digest::Perl::MD4;

	Digest::Perl::MD4->import(qw(md4 md4_hex md4_base64));
	push(@ISA, "Digest::Perl::MD4");  # make OO interface work
    };
    if ($@) {
	# restore the original error
	die $olderr;
    }
}
else {
    *reset = \&new;
}
# hash() and hexhash() was in Digest::MD4 1.1. Deprecated
sub hash {
    my ($self, $data) = @_;
    if (ref($self))
    {
	# This is an instance method call so reset the current context
	$self->reset();
    }
    else
    {
	# This is a static method invocation, create a temporary MD4 context
	$self = new Digest::MD4;
    }
    
    # Now do the hash
    $self->add($data);
    $self->digest();
}

sub hexhash
{
    my ($self, $data) = @_;

    unpack("H*", ($self->hash($data)));
}

1;
__END__

#line 373
