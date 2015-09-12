#line 1 "Spreadsheet/ParseExcel/Workbook.pm"
package Spreadsheet::ParseExcel::Workbook;

###############################################################################
#
# Spreadsheet::ParseExcel::Workbook - A class for Workbooks.
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
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
}

###############################################################################
sub color_idx_to_rgb {
    my( $workbook, $iidx ) = @_;

    my $palette = $workbook->{aColor};
    return ( ( defined $palette->[$iidx] ) ? $palette->[$iidx] : $palette->[0] );
}

###############################################################################
#
# worksheet()
#
# This method returns a single Worksheet object using either its name or index.
#
sub worksheet {
    my ( $oBook, $sName ) = @_;
    my $oWkS;
    foreach $oWkS ( @{ $oBook->{Worksheet} } ) {
        return $oWkS if ( $oWkS->{Name} eq $sName );
    }
    if ( $sName =~ /^\d+$/ ) {
        return $oBook->{Worksheet}->[$sName];
    }
    return undef;
}

###############################################################################
#
# worksheets()
#
# Returns an array of Worksheet objects.
#
sub worksheets {
    my $self = shift;

    return @{ $self->{Worksheet} };
}

###############################################################################
#
# worksheet_count()
#
# Returns the number Woksheet objects in the Workbook.
#
sub worksheet_count {

    my $self = shift;

    return $self->{SheetCount};
}

###############################################################################
#
# get_filename()
#
# Returns the name of the Excel file of C<undef> if the data was read from a filehandle rather than a file.
#
sub get_filename {

    my $self = shift;

    return $self->{File};
}

###############################################################################
#
# get_print_areas()
#
# Returns an array ref of print areas.
#
# TODO. This should really be a Worksheet method.
#
sub get_print_areas {

    my $self = shift;

    return $self->{PrintArea};
}

###############################################################################
#
# get_print_titles()
#
# Returns an array ref of print title hash refs.
#
# TODO. This should really be a Worksheet method.
#
sub get_print_titles {

    my $self = shift;

    return $self->{PrintTitle};
}

###############################################################################
#
# using_1904_date()
#
# Returns true if the Excel file is using the 1904 date epoch.
#
sub using_1904_date {

    my $self = shift;

    return $self->{Flg1904};
}

###############################################################################
#
# ParseAbort()
#
# Todo
#
sub ParseAbort {
    my ( $self, $val ) = @_;
    $self->{_ParseAbort} = $val;
}

#line 160

sub get_active_sheet {
    my $workbook = shift;

    return $workbook->{ActiveSheet};
}

###############################################################################
#
# Parse(). Deprecated.
#
# Syntactic wrapper around Spreadsheet::ParseExcel::Parse().
# This method is *deprecated* since it doesn't conform to the current
# error handling in the S::PE Parse() method.
#
sub Parse {

    my ( $class, $source, $formatter ) = @_;
    my $excel = Spreadsheet::ParseExcel->new();
    my $workbook = $excel->Parse( $source, $formatter );
    $workbook->{_Excel} = $excel;
    return $workbook;
}

###############################################################################
#
# Mapping between legacy method names and new names.
#
{
    no warnings;    # Ignore warnings about variables used only once.
    *Worksheet = *worksheet;
}

1;

__END__

#line 324
