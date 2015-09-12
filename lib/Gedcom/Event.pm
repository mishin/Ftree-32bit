#line 1 "Gedcom/Event.pm"
# Copyright 1999-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Event;

use Gedcom::Record 1.19;

use vars qw($VERSION @ISA);
$VERSION = "1.19";
@ISA     = qw( Gedcom::Record );

# sub type
# {
#   my $self = shift;
#   $self->tag_value("TYPE")
# }

# sub date
# {
#   my $self = shift;
#   $self->tag_value("DATE")
# }

# sub place
# {
#   my $self = shift;
#   $self->tag_value("PLAC")
# }

1;

__END__

#line 71
