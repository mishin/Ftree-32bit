#line 1 "Spreadsheet/ParseExcel/Cell.pm"
package Spreadsheet::ParseExcel::Cell;

###############################################################################
#
# Spreadsheet::ParseExcel::Cell - A class for Cell data and formatting.
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

###############################################################################
#
# new()
#
# Constructor.
#
sub new {
    my ( $package, %properties ) = @_;
    my $self = \%properties;

    bless $self, $package;
}

###############################################################################
#
# value()
#
# Returns the formatted value of the cell.
#
sub value {

    my $self = shift;

    return $self->{_Value};
}

###############################################################################
#
# unformatted()
#
# Returns the unformatted value of the cell.
#
sub unformatted {

    my $self = shift;

    return $self->{Val};
}

###############################################################################
#
# get_format()
#
# Returns the Format object for the cell.
#
sub get_format {

    my $self = shift;

    return $self->{Format};
}

###############################################################################
#
# type()
#
# Returns the type of cell such as Text, Numeric or Date.
#
sub type {

    my $self = shift;

    return $self->{Type};
}

###############################################################################
#
# encoding()
#
# Returns the character encoding of the cell.
#
sub encoding {

    my $self = shift;

    if ( !defined $self->{Code} ) {
        return 1;
    }
    elsif ( $self->{Code} eq 'ucs2' ) {
        return 2;
    }
    elsif ( $self->{Code} eq '_native_' ) {
        return 3;
    }
    else {
        return 0;
    }

    return $self->{Code};
}

###############################################################################
#
# is_merged()
#
# Returns true if the cell is merged.
#
sub is_merged {

    my $self = shift;

    return $self->{Merged};
}

###############################################################################
#
# get_rich_text()
#
# Returns an array ref of font information about each string block in a "rich",
# i.e. multi-format, string.
#
sub get_rich_text {

    my $self = shift;

    return $self->{Rich};
}

###############################################################################
#
# get_hyperlink {
#
# Returns an array ref of hyperlink information if the cell contains a hyperlink.
# Returns undef otherwise
#
# [0] : Description of link (You may want $cell->value, as it will have rich text)
# [1] : URL - the link expressed as a URL. N.B. relative URLs will be defaulted to
#       the directory of the input file, if the input file name is known. Otherwise
#       %REL% will be inserted as a place-holder.  Depending on your application,
#       you should either remove %REL% or replace it with the appropriate path.
# [2] : Target frame (or undef if none)

sub get_hyperlink {
    my $self = shift;

    return $self->{Hyperlink} if exists $self->{Hyperlink};
    return undef;
}

# 
###############################################################################
#
# Mapping between legacy method names and new names.
#
{
    no warnings;    # Ignore warnings about variables used only once.
    *Value = \&value;
}

1;

__END__

#line 362
