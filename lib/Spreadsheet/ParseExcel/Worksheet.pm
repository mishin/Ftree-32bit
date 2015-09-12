#line 1 "Spreadsheet/ParseExcel/Worksheet.pm"
package Spreadsheet::ParseExcel::Worksheet;

###############################################################################
#
# Spreadsheet::ParseExcel::Worksheet - A class for Worksheets.
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
use Scalar::Util qw(weaken);

our $VERSION = '0.65';

###############################################################################
#
# new()
#
sub new {

    my ( $class, %properties ) = @_;

    my $self = \%properties;

    weaken $self->{_Book};

    $self->{Cells}       = undef;
    $self->{DefColWidth} = 8.43;

    return bless $self, $class;
}

###############################################################################
#
# get_cell( $row, $col )
#
# Returns the Cell object at row $row and column $col, if defined.
#
sub get_cell {

    my ( $self, $row, $col ) = @_;

    if (   !defined $row
        || !defined $col
        || !defined $self->{MaxRow}
        || !defined $self->{MaxCol} )
    {

        # Return undef if no arguments are given or if no cells are defined.
        return undef;
    }
    elsif ($row < $self->{MinRow}
        || $row > $self->{MaxRow}
        || $col < $self->{MinCol}
        || $col > $self->{MaxCol} )
    {

        # Return undef if outside allowable row/col range.
        return undef;
    }
    else {

        # Return the Cell object.
        return $self->{Cells}->[$row]->[$col];
    }
}

###############################################################################
#
# row_range()
#
# Returns a two-element list ($min, $max) containing the minimum and maximum
# defined rows in the worksheet.
#
# If there is no row defined $max is smaller than $min.
#
sub row_range {

    my $self = shift;

    my $min = $self->{MinRow} || 0;
    my $max = defined( $self->{MaxRow} ) ? $self->{MaxRow} : ( $min - 1 );

    return ( $min, $max );
}

###############################################################################
#
# col_range()
#
# Returns a two-element list ($min, $max) containing the minimum and maximum
# defined cols in the worksheet.
#
# If there is no column defined $max is smaller than $min.
#
sub col_range {

    my $self = shift;

    my $min = $self->{MinCol} || 0;
    my $max = defined( $self->{MaxCol} ) ? $self->{MaxCol} : ( $min - 1 );

    return ( $min, $max );
}

###############################################################################
#
# get_name()
#
# Returns the name of the worksheet.
#
sub get_name {

    my $self = shift;

    return $self->{Name};
}

###############################################################################
#
# sheet_num()
#
sub sheet_num {

    my $self = shift;

    return $self->{_SheetNo};
}

###############################################################################
#
# get_h_pagebreaks()
#
# Returns an array ref of row numbers where a horizontal page break occurs.
#
sub get_h_pagebreaks {

    my $self = shift;

    return $self->{HPageBreak};
}

###############################################################################
#
# get_v_pagebreaks()
#
# Returns an array ref of column numbers where a vertical page break occurs.
#
sub get_v_pagebreaks {

    my $self = shift;

    return $self->{VPageBreak};
}

###############################################################################
#
# get_merged_areas()
#
# Returns an array ref of cells that are merged.
#
sub get_merged_areas {

    my $self = shift;

    return $self->{MergedArea};
}

###############################################################################
#
# get_row_heights()
#
# Returns an array of row heights.
#
sub get_row_heights {

    my $self = shift;

    if ( wantarray() ) {
      return unless $self->{RowHeight};
      return @{ $self->{RowHeight} };
    }
    return $self->{RowHeight};
}

###############################################################################
#
# get_col_widths()
#
# Returns an array of column widths.
#
sub get_col_widths {

    my $self = shift;

    if ( wantarray() ) {
      return unless $self->{ColWidth};
      return @{ $self->{ColWidth} };
    }
    return $self->{ColWidth};
}

###############################################################################
#
# get_default_row_height()
#
# Returns the default row height for the worksheet. Generally 12.75.
#
sub get_default_row_height {

    my $self = shift;

    return $self->{DefRowHeight};
}

###############################################################################
#
# get_default_col_width()
#
# Returns the default column width for the worksheet. Generally 8.43.
#
sub get_default_col_width {

    my $self = shift;

    return $self->{DefColWidth};
}

###############################################################################
#
# _get_row_properties()
#
# Returns an array_ref of row properties.
# TODO. This is a placeholder for a future method.
#
sub _get_row_properties {

    my $self = shift;

    return $self->{RowProperties};
}

###############################################################################
#
# _get_col_properties()
#
# Returns an array_ref of column properties.
# TODO. This is a placeholder for a future method.
#
sub _get_col_properties {

    my $self = shift;

    return $self->{ColProperties};
}

###############################################################################
#
# get_header()
#
# Returns the worksheet header string.
#
sub get_header {

    my $self = shift;

    return $self->{Header};
}

###############################################################################
#
# get_footer()
#
# Returns the worksheet footer string.
#
sub get_footer {

    my $self = shift;

    return $self->{Footer};
}

###############################################################################
#
# get_margin_left()
#
# Returns the left margin of the worksheet in inches.
#
sub get_margin_left {

    my $self = shift;

    return $self->{LeftMargin};
}

###############################################################################
#
# get_margin_right()
#
# Returns the right margin of the worksheet in inches.
#
sub get_margin_right {

    my $self = shift;

    return $self->{RightMargin};
}

###############################################################################
#
# get_margin_top()
#
# Returns the top margin of the worksheet in inches.
#
sub get_margin_top {

    my $self = shift;

    return $self->{TopMargin};
}

###############################################################################
#
# get_margin_bottom()
#
# Returns the bottom margin of the worksheet in inches.
#
sub get_margin_bottom {

    my $self = shift;

    return $self->{BottomMargin};
}

###############################################################################
#
# get_margin_header()
#
# Returns the header margin of the worksheet in inches.
#
sub get_margin_header {

    my $self = shift;

    return $self->{HeaderMargin};
}

###############################################################################
#
# get_margin_footer()
#
# Returns the footer margin of the worksheet in inches.
#
sub get_margin_footer {

    my $self = shift;

    return $self->{FooterMargin};
}

###############################################################################
#
# get_paper()
#
# Returns the printer paper size.
#
sub get_paper {

    my $self = shift;

    return $self->{PaperSize};
}

###############################################################################
#
# get_start_page()
#
# Returns the page number that printing will start from.
#
sub get_start_page {

    my $self = shift;

    # Only return the page number if the "First page number" option is set.
    if ( $self->{UsePage} ) {
        return $self->{PageStart};
    }
    else {
        return 0;
    }
}

###############################################################################
#
# get_print_order()
#
# Returns the Worksheet page printing order.
#
sub get_print_order {

    my $self = shift;

    return $self->{LeftToRight};
}

###############################################################################
#
# get_print_scale()
#
# Returns the workbook scale for printing.
#
sub get_print_scale {

    my $self = shift;

    return $self->{Scale};
}

###############################################################################
#
# get_fit_to_pages()
#
# Returns the number of pages wide and high that the printed worksheet page
# will fit to.
#
sub get_fit_to_pages {

    my $self = shift;

    if ( !$self->{PageFit} ) {
        return ( 0, 0 );
    }
    else {
        return ( $self->{FitWidth}, $self->{FitHeight} );
    }
}

###############################################################################
#
# is_portrait()
#
# Returns true if the worksheet has been set for printing in portrait mode.
#
sub is_portrait {

    my $self = shift;

    return $self->{Landscape};
}

###############################################################################
#
# is_centered_horizontally()
#
# Returns true if the worksheet has been centered horizontally for printing.
#
sub is_centered_horizontally {

    my $self = shift;

    return $self->{HCenter};
}

###############################################################################
#
# is_centered_vertically()
#
# Returns true if the worksheet has been centered vertically for printing.
#
sub is_centered_vertically {

    my $self = shift;

    return $self->{HCenter};
}

###############################################################################
#
# is_print_gridlines()
#
# Returns true if the worksheet print "gridlines" option is turned on.
#
sub is_print_gridlines {

    my $self = shift;

    return $self->{PrintGrid};
}

###############################################################################
#
# is_print_row_col_headers()
#
# Returns true if the worksheet print "row and column headings" option is on.
#
sub is_print_row_col_headers {

    my $self = shift;

    return $self->{PrintHeaders};
}

###############################################################################
#
# is_print_black_and_white()
#
# Returns true if the worksheet print "black and white" option is turned on.
#
sub is_print_black_and_white {

    my $self = shift;

    return $self->{NoColor};
}

###############################################################################
#
# is_print_draft()
#
# Returns true if the worksheet print "draft" option is turned on.
#
sub is_print_draft {

    my $self = shift;

    return $self->{Draft};
}

###############################################################################
#
# is_print_comments()
#
# Returns true if the worksheet print "comments" option is turned on.
#
sub is_print_comments {

    my $self = shift;

    return $self->{Notes};
}

#line 557

sub get_tab_color {
    my $worksheet = shift;

    return $worksheet->{TabColor};
}

#line 569

sub is_sheet_hidden {
    my $worksheet = shift;

    return $worksheet->{SheetHidden};
}

#line 583

sub is_row_hidden {
    my $worksheet = shift;

    my ($row) = @_;

    unless ( $worksheet->{RowHidden} ) {
        return () if (wantarray);
        return 0;
    }

    return @{ $worksheet->{RowHidden} } if (wantarray);
    return $worksheet->{RowHidden}[$row];
}

#line 605

sub is_col_hidden {
    my $worksheet = shift;

    my ($col) = @_;

    unless ( $worksheet->{ColHidden} ) {
        return () if (wantarray);
        return 0;
    }

    return @{ $worksheet->{ColHidden} } if (wantarray);
    return $worksheet->{ColHidden}[$col];
}

###############################################################################
#
# Mapping between legacy method names and new names.
#
{
    no warnings;    # Ignore warnings about variables used only once.
    *sheetNo  = *sheet_num;
    *Cell     = *get_cell;
    *RowRange = *row_range;
    *ColRange = *col_range;
}

1;

__END__

#line 1039
