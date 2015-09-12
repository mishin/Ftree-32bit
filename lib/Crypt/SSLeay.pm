#line 1 "Crypt/SSLeay.pm"
package Crypt::SSLeay;

use strict;
use vars '$VERSION';
$VERSION = '0.72';
$VERSION = eval $VERSION;

eval {
    require XSLoader;
    XSLoader::load('Crypt::SSLeay', $VERSION);
    1;
}
or do {
    require DynaLoader;
    use vars '@ISA'; # not really locally scoped, it just looks that way
    @ISA = qw(DynaLoader);
    bootstrap Crypt::SSLeay $VERSION;
};

use vars qw(%CIPHERS);
%CIPHERS = (
   'NULL-MD5'     => "No encryption with a MD5 MAC",
   'RC4-MD5'      => "128 bit RC4 encryption with a MD5 MAC",
   'EXP-RC4-MD5'  => "40 bit RC4 encryption with a MD5 MAC",
   'RC2-CBC-MD5'  => "128 bit RC2 encryption with a MD5 MAC",
   'EXP-RC2-CBC-MD5' => "40 bit RC2 encryption with a MD5 MAC",
   'IDEA-CBC-MD5' => "128 bit IDEA encryption with a MD5 MAC",
   'DES-CBC-MD5'  => "56 bit DES encryption with a MD5 MAC",
   'DES-CBC-SHA'  => "56 bit DES encryption with a SHA MAC",
   'DES-CBC3-MD5' => "192 bit EDE3 DES encryption with a MD5 MAC",
   'DES-CBC3-SHA' => "192 bit EDE3 DES encryption with a SHA MAC",
   'DES-CFB-M1'   => "56 bit CFB64 DES encryption with a one byte MD5 MAC",
);

use Crypt::SSLeay::X509;

# A xsupp bug made this necessary
sub Crypt::SSLeay::CTX::DESTROY  { shift->free; }
sub Crypt::SSLeay::Conn::DESTROY { shift->free; }
sub Crypt::SSLeay::X509::DESTROY { shift->free; }

1;

__END__

#line 539
