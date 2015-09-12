#!/usr/bin/perl
#line 2 "DBD/CSV.pm"
#
#   DBD::CSV - A DBI driver for CSV and similar structured files
#
#   This module is currently maintained by
#
#	H.Merijn Brand <h.m.brand@xs4all.nl>
#
#   See for full acknowledgements the last two pod sections in this file

use strict;
use warnings;

require DynaLoader;
require DBD::File;
require IO::File;

package DBD::CSV;

use strict;

use vars qw( @ISA $VERSION $ATTRIBUTION $drh $err $errstr $sqlstate );

@ISA =   qw( DBD::File );

$VERSION  = "0.41";
$ATTRIBUTION = "DBD::CSV $DBD::CSV::VERSION by H.Merijn Brand";

$err      = 0;		# holds error code   for DBI::err
$errstr   = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh      = undef;	# holds driver handle once initialized

sub CLONE		# empty method: prevent warnings when threads are cloned
{
    } # CLONE

# --- DRIVER -------------------------------------------------------------------

package DBD::CSV::dr;

use strict;

use Text::CSV_XS ();
use vars qw( @ISA @CSV_TYPES );

@CSV_TYPES = (
    Text::CSV_XS::IV (), # SQL_TINYINT
    Text::CSV_XS::IV (), # SQL_BIGINT
    Text::CSV_XS::PV (), # SQL_LONGVARBINARY
    Text::CSV_XS::PV (), # SQL_VARBINARY
    Text::CSV_XS::PV (), # SQL_BINARY
    Text::CSV_XS::PV (), # SQL_LONGVARCHAR
    Text::CSV_XS::PV (), # SQL_ALL_TYPES
    Text::CSV_XS::PV (), # SQL_CHAR
    Text::CSV_XS::NV (), # SQL_NUMERIC
    Text::CSV_XS::NV (), # SQL_DECIMAL
    Text::CSV_XS::IV (), # SQL_INTEGER
    Text::CSV_XS::IV (), # SQL_SMALLINT
    Text::CSV_XS::NV (), # SQL_FLOAT
    Text::CSV_XS::NV (), # SQL_REAL
    Text::CSV_XS::NV (), # SQL_DOUBLE
    );

our @ISA = qw( DBD::File::dr );

our $imp_data_size     = 0;
our $data_sources_attr = undef;

sub connect
{
    my ($drh, $dbname, $user, $auth, $attr) = @_;
    my $dbh = $drh->DBD::File::dr::connect ($dbname, $user, $auth, $attr);
    $dbh->{Active} = 1;
    $dbh;
    } # connect

# --- DATABASE -----------------------------------------------------------------

package DBD::CSV::db;

use strict;

our $imp_data_size = 0;
our @ISA = qw( DBD::File::db );

sub set_versions
{
    my $this = shift;
    $this->{csv_version} = $DBD::CSV::VERSION;
    return $this->SUPER::set_versions ();
    } # set_versions

my %csv_xs_attr;

sub init_valid_attributes
{
    my $dbh = shift;

    my @xs_attr = qw(
	allow_loose_escapes allow_loose_quotes allow_whitespace
	always_quote auto_diag binary blank_is_undef empty_is_undef
	eol escape_char keep_meta_info quote_char quote_null
	quote_space sep_char types verbatim );
    @csv_xs_attr{@xs_attr} = ();

    $dbh->{csv_xs_valid_attrs} = [ @xs_attr ];

    $dbh->{csv_valid_attrs} = { map {("csv_$_" => 1 )} @xs_attr, qw(

	class tables in csv_in out csv_out skip_first_row

	null sep quote escape
	)};

    $dbh->{csv_readonly_attrs} = { };

    $dbh->{csv_meta} = "csv_tables";

    return $dbh->SUPER::init_valid_attributes ();
    } # init_valid_attributes

sub get_csv_versions
{
    my ($dbh, $table) = @_;
    $table ||= "";
    my $class = $dbh->{ImplementorClass};
    $class =~ s/::db$/::Table/;
    my $meta;
    $table and (undef, $meta) = $class->get_table_meta ($dbh, $table, 1);
    unless ($meta) {
	$meta = {};
	$class->bootstrap_table_meta ($dbh, $meta, $table);
	}
    my $dvsn  = eval { $meta->{csv_class}->VERSION (); };
    my $dtype = $meta->{csv_class};
    $dvsn and $dtype .= " ($dvsn)";
    return sprintf "%s using %s", $dbh->{csv_version}, $dtype;
    } # get_csv_versions 

# --- STATEMENT ----------------------------------------------------------------

package DBD::CSV::st;

use strict;

our $imp_data_size = 0;
our @ISA = qw(DBD::File::st);

package DBD::CSV::Statement;

use strict;
use Carp;

our @ISA = qw(DBD::File::Statement);

package DBD::CSV::Table;

use strict;
use Carp;

our @ISA = qw(DBD::File::Table);

sub bootstrap_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;
    $meta->{csv_class} ||= $dbh->{csv_class} || "Text::CSV_XS";
    $meta->{csv_eol}   ||= $dbh->{csv_eol}   || "\r\n";
    exists $meta->{csv_skip_first_row} or
	$meta->{csv_skip_first_row} = $dbh->{csv_skip_first_row};
    $self->SUPER::bootstrap_table_meta ($dbh, $meta, $table);
    } # bootstrap_table_meta

sub init_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;

    $self->SUPER::init_table_meta ($dbh, $table, $meta);

    my $csv_in = $meta->{csv_in} || $dbh->{csv_csv_in};
    unless ($csv_in) {
	my %opts = ( binary => 1, auto_diag => 1 );

	# Allow specific Text::CSV_XS options
	foreach my $attr (@{$dbh->{csv_xs_valid_attrs}}) {
	    $attr eq "eol" and next; # Handles below
	    exists $dbh->{"csv_$attr"} and $opts{$attr} = $dbh->{"csv_$attr"};
	    }
	$dbh->{csv_null} || $meta->{csv_null} and
	    $opts{blank_is_undef} = $opts{always_quote} = 1;

	my $class = $meta->{csv_class};
	my $eol   = $meta->{csv_eol};
	$eol =~ m/^\A(?:[\r\n]|\r\n)\Z/ or $opts{eol} = $eol;
	for ([ "sep",    ',' ],
	     [ "quote",  '"' ],
	     [ "escape", '"' ],
	     ) {
	    my ($attr, $def) = ($_->[0]."_char", $_->[1]);
	    $opts{$attr} =
		exists $meta->{$attr} ? $meta->{$attr} :
		    exists $dbh->{"csv_$attr"} ? $dbh->{"csv_$attr"} : $def;
	    }
	$meta->{csv_in}  = $class->new (\%opts) or
	    $class->error_diag;
	$opts{eol} = $eol;
	$meta->{csv_out} = $class->new (\%opts) or
	    $class->error_diag;
	}
    } # init_table_meta

my %compat_map = map { $_ => "csv_$_" }
    qw( class eof  eol quote_char sep_char escape_char );

__PACKAGE__->register_compat_map (\%compat_map);

sub table_meta_attr_changed
{
    my ($class, $meta, $attr, $value) = @_;

    (my $csv_attr = $attr) =~ s/^csv_//;
    if (exists $csv_xs_attr{$csv_attr}) {
	for ("csv_in", "csv_out") {
	    exists $meta->{$_} && exists $meta->{$_}{$csv_attr} and
		$meta->{$_}{$csv_attr} = $value;
	    }
	}

    $class->SUPER::table_meta_attr_changed ($meta, $attr, $value);
    } # table_meta_attr_changed

sub open_data {
    my ($self, $meta, $attrs, $flags) = @_;
    $self->SUPER::open_file ($meta, $attrs, $flags);

    if ($meta && $meta->{fh}) {
	$attrs->{csv_csv_in}  = $meta->{csv_in};
	$attrs->{csv_csv_out} = $meta->{csv_out};
	if (my $types = $meta->{types}) {
	    # XXX $meta->{types} is nowhere assigned and should better $meta->{csv_types}
	    # The 'types' array contains DBI types, but we need types
	    # suitable for Text::CSV_XS.
	    my $t = [];
	    for (@{$types}) {
		$_ = $_
		    ? $DBD::CSV::dr::CSV_TYPES[$_ + 6] || Text::CSV_XS::PV ()
		    : Text::CSV_XS::PV ();
		push @$t, $_;
		}
	    $meta->{types} = $t;
	    }
	if (!$flags->{createMode}) {
	    my $array;
	    my $skipRows = defined $meta->{skip_rows}
		? $meta->{skip_rows}
		: defined $meta->{csv_skip_first_row}
		    ? 1
		    : exists $meta->{col_names} ? 0 : 1;
	    defined $meta->{skip_rows} or
		$meta->{skip_rows} = $skipRows;
	    if ($skipRows--) {
		$array = $attrs->{csv_csv_in}->getline ($meta->{fh}) or
		    croak "Missing first row due to ".$attrs->{csv_csv_in}->error_diag;
		unless ($meta->{raw_header}) {
		    s/\W/_/g for @$array;
		    }
		defined $meta->{col_names} or
		    $meta->{col_names} = $array;
		while ($skipRows--) {
		    $attrs->{csv_csv_in}->getline ($meta->{fh});
		    }
		}
	    # lockMode is set 1 for DELETE, INSERT or UPDATE
	    # no other case need seeking
	    $flags->{lockMode} and # $meta->{fh}->can ("tell") and
		$meta->{first_row_pos} = $meta->{fh}->tell ();
	    exists $meta->{col_names} and
		$array = $meta->{col_names};
	    if (!$meta->{col_names} || !@{$meta->{col_names}}) {
		# No column names given; fetch first row and create default
		# names.
		my $ar = $meta->{cached_row} =
		    $attrs->{csv_csv_in}->getline ($meta->{fh});
		$array = $meta->{col_names};
		push @$array, map { "col$_" } 0 .. $#$ar;
		}
	    }
	}
    } # open_file

no warnings 'once';
$DBI::VERSION < 1.623 and
    *open_file = \&open_data;
use warnings;

sub _csv_diag
{
    my @diag = $_[0]->error_diag;
    for (2, 3) {
	defined $diag[$_] or $diag[$_] = "?";
	}
    return @diag;
    } # _csv_diag

sub fetch_row
{
    my ($self, $data) = @_;

    exists $self->{cached_row} and
	return $self->{row} = delete $self->{cached_row};

    my $tbl = $self->{meta};

    my $csv = $self->{csv_csv_in} or
	return do { $data->set_err ($DBI::stderr, "Fetch from undefined handle"); undef };

    my $fields;
    eval { $fields = $csv->getline ($tbl->{fh}) };
    unless ($fields) {
	$csv->eof and return;

	my @diag = _csv_diag ($csv);
	my $file = $tbl->{f_fqfn};
	croak "Error $diag[0] while reading file $file: $diag[1] \@ line $diag[3] pos $diag[2]";
	}
    @$fields < @{$tbl->{col_names}} and
	push @$fields, (undef) x (@{$tbl->{col_names}} - @$fields);
    $self->{row} = (@$fields ? $fields : undef);
    } # fetch_row

sub push_row
{
    my ($self, $data, $fields) = @_;
    my $tbl = $self->{meta};
    my $csv = $self->{csv_csv_out};
    my $fh  = $tbl->{fh};

    unless ($csv->print ($fh, $fields)) {
	my @diag = _csv_diag ($csv);
	my $file = $tbl->{f_fqfn};
	return do { $data->set_err ($DBI::stderr, "Error $diag[0] while writing file $file: $diag[1] \@ line $diag[3] pos $diag[2]"); undef };
	}
    1;
    } # push_row

no warnings 'once';
*push_names = \&push_row;
use warnings;

1;

__END__

#line 1191
