#line 1 "Spreadsheet/ParseExcel/Format.pm"
package Spreadsheet::ParseExcel::Format;

###############################################################################
#
# Spreadsheet::ParseExcel::Format - A class for Cell formats.
#
# Used in conjunction with Spreadsheet::ParseExcel.
#
# Copyright (c) 2014      Douglas Wilson
# Copyright (c) 2009-2013 John McNamara
# Copyright (c) 2006-2008 Gabor Szabo
# Copyright (c) 2000-2006 Kawai Takanori
#
# perltidy with standard settings.
#
# Documentation after __END__
#

use strict;
use warnings;

our $VERSION = '0.65';

sub new {
    my ( $class, %rhIni ) = @_;
    my $self = \%rhIni;

    bless $self, $class;
}

1;

__END__

#line 74
