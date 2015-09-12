#line 1 "DBI/Gofer/Serializer/Storable.pm"
package DBI::Gofer::Serializer::Storable;

use strict;
use warnings;

use base qw(DBI::Gofer::Serializer::Base);

#   $Id: Storable.pm 15585 2013-03-22 20:31:22Z Tim $
#
#   Copyright (c) 2007, Tim Bunce, Ireland
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

#line 38

use Storable qw(nfreeze thaw);

our $VERSION = "0.015586";

use base qw(DBI::Gofer::Serializer::Base);


sub serialize {
    my $self = shift;
    local $Storable::forgive_me = 1; # for CODE refs etc
    local $Storable::canonical = 1; # for go_cache
    my $frozen = nfreeze(shift);
    return $frozen unless wantarray;
    return ($frozen, $self->{deserializer_class});
}

sub deserialize {
    my $self = shift;
    return thaw(shift);
}

1;
