#line 1 "Text/CSV_XS.pm"
package Text::CSV_XS;

# Copyright (c) 2007-2014 H.Merijn Brand.  All rights reserved.
# Copyright (c) 1998-2001 Jochen Wiedmann. All rights reserved.
# Copyright (c) 1997 Alan Citterman.       All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# HISTORY
#
# Written by:
#    Jochen Wiedmann <joe@ispsoft.de>
#
# Based on Text::CSV by:
#    Alan Citterman <alan@mfgrtl.com>
#
# Extended and Remodelled by:
#    H.Merijn Brand (h.m.brand@xs4all.nl)

require 5.006001;

use strict;
use warnings;

require Exporter;
use DynaLoader ();
use Carp;

use vars   qw( $VERSION @ISA @EXPORT_OK );
$VERSION   = "1.08";
@ISA       = qw( DynaLoader Exporter );
@EXPORT_OK = qw( csv );
bootstrap Text::CSV_XS $VERSION;

sub PV { 0 }
sub IV { 1 }
sub NV { 2 }

# version
#
#   class/object method expecting no arguments and returning the version
#   number of Text::CSV.  there are no side-effects.

sub version
{
    return $VERSION;
    } # version

# new
#
#   class/object method expecting no arguments and returning a reference to
#   a newly created Text::CSV object.

my %def_attr = (
    quote_char			=> '"',
    escape_char			=> '"',
    sep_char			=> ',',
    eol				=> '',
    always_quote		=> 0,
    quote_space			=> 1,
    quote_null			=> 1,
    quote_binary		=> 1,
    binary			=> 0,
    decode_utf8			=> 1,
    keep_meta_info		=> 0,
    allow_loose_quotes		=> 0,
    allow_loose_escapes		=> 0,
    allow_unquoted_escape	=> 0,
    allow_whitespace		=> 0,
    blank_is_undef		=> 0,
    empty_is_undef		=> 0,
    verbatim			=> 0,
    auto_diag			=> 0,
    diag_verbose		=> 0,
    types			=> undef,
    callbacks			=> undef,

    _EOF			=> 0,
    _RECNO			=> 0,
    _STATUS			=> undef,
    _FIELDS			=> undef,
    _FFLAGS			=> undef,
    _STRING			=> undef,
    _ERROR_INPUT		=> undef,
    _COLUMN_NAMES		=> undef,
    _BOUND_COLUMNS		=> undef,
    _AHEAD			=> undef,
    );
my %attr_alias = (
    quote_always		=> "always_quote",
    verbose_diag		=> "diag_verbose",
    );
my $last_new_err = Text::CSV_XS->SetDiag (0);

# NOT a method: is also used before bless
sub _unhealthy_whitespace
{
    my $self = shift;
    $_[0] and
      (defined $self->{quote_char}  && $self->{quote_char}  =~ m/^[ \t]$/) ||
      (defined $self->{escape_char} && $self->{escape_char} =~ m/^[ \t]$/) and
	return 1002;
    return 0;
    } # _sane_whitespace

sub _check_sanity
{
    my $self = shift;
    for (qw( sep_char quote_char escape_char )) {
	defined $self->{$_} && $self->{$_} =~ m/[\r\n]/ and
	    return 1003;
	}
    return _unhealthy_whitespace ($self, $self->{allow_whitespace});
    } # _check_sanity

sub new
{
    $last_new_err = Text::CSV_XS->SetDiag (1000,
	"usage: my \$csv = Text::CSV_XS->new ([{ option => value, ... }]);");

    my $proto = shift;
    my $class = ref ($proto) || $proto	or  return;
    @_ > 0 &&   ref $_[0] ne "HASH"	and return;
    my $attr  = shift || {};
    my %attr  = map {
	my $k = m/^[a-zA-Z]\w+$/ ? lc $_ : $_;
	exists $attr_alias{$k} and $k = $attr_alias{$k};
	$k => $attr->{$_};
	} keys %$attr;

    for (keys %attr) {
	if (m/^[a-z]/ && exists $def_attr{$_}) {
	    # uncoverable condition false
	    defined $attr{$_} && $] >= 5.008002 && m/_char$/ and
		utf8::decode ($attr{$_});
	    next;
	    }
#	croak?
	$last_new_err = Text::CSV_XS->SetDiag (1000, "INI - Unknown attribute '$_'");
	$attr{auto_diag} and error_diag ();
	return;
	}

    my $self = { %def_attr, %attr };
    if (my $ec = _check_sanity ($self)) {
	$last_new_err = Text::CSV_XS->SetDiag ($ec);
	$attr{auto_diag} and error_diag ();
	return;
	}
    if (defined $self->{callbacks} && ref $self->{callbacks} ne "HASH") {
	warn "The 'callbacks' attribute is set but is not a hash: ignored\n";
	$self->{callbacks} = undef;
	}

    $last_new_err = Text::CSV_XS->SetDiag (0);
    defined $\ && !exists $attr{eol} and $self->{eol} = $\;
    bless $self, $class;
    defined $self->{types} and $self->types ($self->{types});
    $self;
    } # new

# Keep in sync with XS!
my %_cache_id = ( # Only expose what is accessed from within PM
    quote_char			=>  0,
    escape_char			=>  1,
    sep_char			=>  2,
    binary			=>  3,
    keep_meta_info		=>  4,
    always_quote		=>  5,
    allow_loose_quotes		=>  6,
    allow_loose_escapes		=>  7,
    allow_unquoted_escape	=>  8,
    allow_whitespace		=>  9,
    blank_is_undef		=> 10,
    eol				=> 11,	# 11 .. 18
    verbatim			=> 22,
    empty_is_undef		=> 23,
    auto_diag			=> 24,
    diag_verbose		=> 33,
    quote_space			=> 25,
    quote_null			=> 31,
    quote_binary		=> 32,
    decode_utf8			=> 35,
    _has_hooks			=> 36,
    _is_bound			=> 26,	# 26 .. 29
    );

# A `character'
sub _set_attr_C
{
    my ($self, $name, $val, $ec) = @_;
    defined $val or $val = 0;
    $] >= 5.008002 and utf8::decode ($val);
    $self->{$name} = $val;
    $ec = _check_sanity ($self) and
	croak ($self->SetDiag ($ec));
    $self->_cache_set ($_cache_id{$name}, $val);
    } # _set_attr_C

# A flag
sub _set_attr_X
{
    my ($self, $name, $val) = @_;
    defined $val or $val = 0;
    $self->{$name} = $val;
    $self->_cache_set ($_cache_id{$name}, 0 + $val);
    } # _set_attr_X

# A number
sub _set_attr_N
{
    my ($self, $name, $val) = @_;
    $self->{$name} = $val;
    $self->_cache_set ($_cache_id{$name}, 0 + $val);
    } # _set_attr_N

# Accessor methods.
#   It is unwise to change them halfway through a single file!
sub quote_char
{
    my $self = shift;
    if (@_) {
	my $qc = shift;
	$self->_set_attr_C ("quote_char", $qc);
	}
    $self->{quote_char};
    } # quote_char

sub escape_char
{
    my $self = shift;
    if (@_) {
	my $ec = shift;
	$self->_set_attr_C ("escape_char", $ec);
	}
    $self->{escape_char};
    } # escape_char

sub sep_char
{
    my $self = shift;
    @_ and $self->_set_attr_C ("sep_char", shift);
    $self->{sep_char};
    } # sep_char

sub eol
{
    my $self = shift;
    if (@_) {
	my $eol = shift;
	defined $eol or $eol = "";
	$self->{eol} = $eol;
	$self->_cache_set ($_cache_id{eol}, $eol);
	}
    $self->{eol};
    } # eol

sub always_quote
{
    my $self = shift;
    @_ and $self->_set_attr_X ("always_quote", shift);
    $self->{always_quote};
    } # always_quote

sub quote_space
{
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_space", shift);
    $self->{quote_space};
    } # quote_space

sub quote_null
{
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_null", shift);
    $self->{quote_null};
    } # quote_null

sub quote_binary
{
    my $self = shift;
    @_ and $self->_set_attr_X ("quote_binary", shift);
    $self->{quote_binary};
    } # quote_binary

sub binary
{
    my $self = shift;
    @_ and $self->_set_attr_X ("binary", shift);
    $self->{binary};
    } # binary

sub decode_utf8
{
    my $self = shift;
    @_ and $self->_set_attr_X ("decode_utf8", shift);
    $self->{decode_utf8};
    } # decode_utf8

sub keep_meta_info
{
    my $self = shift;
    @_ and $self->_set_attr_X ("keep_meta_info", shift);
    $self->{keep_meta_info};
    } # keep_meta_info

sub allow_loose_quotes
{
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_loose_quotes", shift);
    $self->{allow_loose_quotes};
    } # allow_loose_quotes

sub allow_loose_escapes
{
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_loose_escapes", shift);
    $self->{allow_loose_escapes};
    } # allow_loose_escapes

sub allow_whitespace
{
    my $self = shift;
    if (@_) {
	my $aw = shift;
	_unhealthy_whitespace ($self, $aw) and
	    croak ($self->SetDiag (1002));
	$self->_set_attr_X ("allow_whitespace", $aw);
	}
    $self->{allow_whitespace};
    } # allow_whitespace

sub allow_unquoted_escape
{
    my $self = shift;
    @_ and $self->_set_attr_X ("allow_unquoted_escape", shift);
    $self->{allow_unquoted_escape};
    } # allow_unquoted_escape

sub blank_is_undef
{
    my $self = shift;
    @_ and $self->_set_attr_X ("blank_is_undef", shift);
    $self->{blank_is_undef};
    } # blank_is_undef

sub empty_is_undef
{
    my $self = shift;
    @_ and $self->_set_attr_X ("empty_is_undef", shift);
    $self->{empty_is_undef};
    } # empty_is_undef

sub verbatim
{
    my $self = shift;
    @_ and $self->_set_attr_X ("verbatim", shift);
    $self->{verbatim};
    } # verbatim

sub auto_diag
{
    my $self = shift;
    if (@_) {
	my $v = shift;
	!defined $v || $v eq "" and $v = 0;
	$v =~ m/^[0-9]/ or $v = lc $v eq "false" ? 0 : 1; # true/truth = 1
	$self->_set_attr_X ("auto_diag", $v);
	}
    $self->{auto_diag};
    } # auto_diag

sub diag_verbose
{
    my $self = shift;
    if (@_) {
	my $v = shift;
	!defined $v || $v eq "" and $v = 0;
	$v =~ m/^[0-9]/ or $v = lc $v eq "false" ? 0 : 1; # true/truth = 1
	$self->_set_attr_X ("diag_verbose", $v);
	}
    $self->{diag_verbose};
    } # diag_verbose

# status
#
#   object method returning the success or failure of the most recent
#   combine () or parse ().  there are no side-effects.

sub status
{
    my $self = shift;
    return $self->{_STATUS};
    } # status

sub eof
{
    my $self = shift;
    return $self->{_EOF};
    } # status

sub types
{
    my $self = shift;
    if (@_) {
	if (my $types = shift) {
	    $self->{_types} = join "", map { chr $_ } @{$types};
	    $self->{types}  = $types;
	    }
	else {
	    delete $self->{types};
	    delete $self->{_types};
	    undef;
	    }
	}
    else {
	$self->{types};
	}
    } # types

sub callbacks
{
    my $self = shift;
    if (@_) {
	my $cb;
	my $hf = 0x00;
	if (defined $_[0]) {
	    grep { !defined $_ } @_ and croak ($self->SetDiag (1004));
	    $cb = @_ == 1 && ref $_[0] eq "HASH" ? shift
	        : @_ % 2 == 0                    ? { @_ }
	        : croak ($self->SetDiag (1004));
	    foreach my $cbk (keys %$cb) {
		(!ref $cbk && $cbk =~ m/^[\w.]+$/) && ref $cb->{$cbk} eq "CODE" or
		    croak ($self->SetDiag (1004));
		}
	    exists $cb->{error}        and $hf |= 0x01;
	    exists $cb->{after_parse}  and $hf |= 0x02;
	    exists $cb->{before_print} and $hf |= 0x04;
	    }
	elsif (@_ > 1) {
	    # (undef, whatever)
	    croak ($self->SetDiag (1004));
	    }
	$self->_set_attr_X ("_has_hooks", $hf);
	$self->{callbacks} = $cb;
	}
    $self->{callbacks};
    } # callbacks

# erro_diag
#
#   If (and only if) an error occurred, this function returns a code that
#   indicates the reason of failure

sub error_diag
{
    my $self = shift;
    my @diag = (0 + $last_new_err, $last_new_err, 0, 0);

    if ($self && ref $self && # Not a class method or direct call
	 $self->isa (__PACKAGE__) && exists $self->{_ERROR_DIAG}) {
	$diag[0] = 0 + $self->{_ERROR_DIAG};
	$diag[1] =     $self->{_ERROR_DIAG};
	$diag[2] = 1 + $self->{_ERROR_POS} if exists $self->{_ERROR_POS};
	$diag[3] =     $self->{_RECNO};

	$diag[0] && $self && $self->{callbacks} && $self->{callbacks}{error} and
	    return $self->{callbacks}{error}->(@diag);
	}

    my $context = wantarray;
    unless (defined $context) {	# Void context, auto-diag
	if ($diag[0] && $diag[0] != 2012) {
	    my $msg = "# CSV_XS ERROR: $diag[0] - $diag[1] \@ rec $diag[3] pos $diag[2]\n";
	    if ($self && ref $self) {	# auto_diag
		if ($self->{diag_verbose} and $self->{_ERROR_INPUT}) {
		    $msg .= "$self->{_ERROR_INPUT}'\n";
		    $msg .= " " x ($diag[2] - 1);
		    $msg .= "^\n";
		    }

		my $lvl = $self->{auto_diag};
		if ($lvl < 2) {
		    my @c = caller (2);
		    if (@c >= 11 && $c[10] && ref $c[10] eq "HASH") {
			my $hints = $c[10];
			(exists $hints->{autodie} && $hints->{autodie} or
			 exists $hints->{"guard Fatal"} &&
			!exists $hints->{"no Fatal"}) and
			    $lvl++;
			# Future releases of autodie will probably set $^H{autodie}
			#  to "autodie @args", like "autodie :all" or "autodie open"
			#  so we can/should check for "open" or "new"
			}
		    }
		$lvl > 1 ? die $msg : warn $msg;
		}
	    else {	# called without args in void context
		warn $msg;
		}
	    }
	return;
	}
    return $context ? @diag : $diag[1];
    } # error_diag

sub record_number
{
    my $self = shift;
    return $self->{_RECNO};
    } # record_number

# string
#
#   object method returning the result of the most recent combine () or the
#   input to the most recent parse (), whichever is more recent.  there are
#   no side-effects.

sub string
{
    my $self = shift;
    return ref $self->{_STRING} ? ${$self->{_STRING}} : undef;
    } # string

# fields
#
#   object method returning the result of the most recent parse () or the
#   input to the most recent combine (), whichever is more recent.  there
#   are no side-effects.

sub fields
{
    my $self = shift;
    return ref $self->{_FIELDS} ? @{$self->{_FIELDS}} : undef;
    } # fields

# meta_info
#
#   object method returning the result of the most recent parse () or the
#   input to the most recent combine (), whichever is more recent.  there
#   are no side-effects. meta_info () returns (if available)  some of the
#   field's properties

sub meta_info
{
    my $self = shift;
    return ref $self->{_FFLAGS} ? @{$self->{_FFLAGS}} : undef;
    } # meta_info

sub is_quoted
{
    my ($self, $idx, $val) = @_;
    ref $self->{_FFLAGS} &&
	$idx >= 0 && $idx < @{$self->{_FFLAGS}} or return;
    $self->{_FFLAGS}[$idx] & 0x0001 ? 1 : 0;
    } # is_quoted

sub is_binary
{
    my ($self, $idx, $val) = @_;
    ref $self->{_FFLAGS} &&
	$idx >= 0 && $idx < @{$self->{_FFLAGS}} or return;
    $self->{_FFLAGS}[$idx] & 0x0002 ? 1 : 0;
    } # is_binary

sub is_missing
{
    my ($self, $idx, $val) = @_;
    $idx < 0 || !ref $self->{_FFLAGS} and return;
    $idx >= @{$self->{_FFLAGS}} and return 1;
    $self->{_FFLAGS}[$idx] & 0x0010 ? 1 : 0;
    } # is_missing

# combine
#
#  Object method returning success or failure. The given arguments are
#  combined into a single comma-separated value. Failure can be the
#  result of no arguments or an argument containing an invalid character.
#  side-effects include:
#      setting status ()
#      setting fields ()
#      setting string ()
#      setting error_input ()

sub combine
{
    my $self = shift;
    my $str  = "";
    $self->{_FIELDS} = \@_;
    $self->{_FFLAGS} = undef;
    $self->{_STATUS} = (@_ > 0) && $self->Combine (\$str, \@_, 0);
    $self->{_STRING} = \$str;
    $self->{_STATUS};
    } # combine

# parse
#
#  Object method returning success or failure. The given argument is
#  expected to be a valid comma-separated value. Failure can be the
#  result of no arguments or an argument containing an invalid sequence
#  of characters. Side-effects include:
#      setting status ()
#      setting fields ()
#      setting meta_info ()
#      setting string ()
#      setting error_input ()

sub parse
{
    my ($self, $str) = @_;

    my $fields = [];
    my $fflags = [];
    $self->{_STRING} = \$str;
    if (defined $str && $self->Parse ($str, $fields, $fflags)) {
	$self->{_FIELDS} = $fields;
	$self->{_FFLAGS} = $fflags;
	$self->{_STATUS} = 1;
	}
    else {
	$self->{_FIELDS} = undef;
	$self->{_FFLAGS} = undef;
	$self->{_STATUS} = 0;
	}
    $self->{_STATUS};
    } # parse

sub column_names
{
    my ($self, @keys) = @_;
    @keys or
	return defined $self->{_COLUMN_NAMES} ? @{$self->{_COLUMN_NAMES}} : ();

    @keys == 1 && ! defined $keys[0] and
	return $self->{_COLUMN_NAMES} = undef;

    if (@keys == 1 && ref $keys[0] eq "ARRAY") {
	@keys = @{$keys[0]};
	}
    elsif (join "", map { defined $_ ? ref $_ : "" } @keys) {
	croak ($self->SetDiag (3001));
	}

    $self->{_BOUND_COLUMNS} && @keys != @{$self->{_BOUND_COLUMNS}} and
	croak ($self->SetDiag (3003));

    $self->{_COLUMN_NAMES} = [ map { defined $_ ? $_ : "\cAUNDEF\cA" } @keys ];
    @{$self->{_COLUMN_NAMES}};
    } # column_names

sub bind_columns
{
    my ($self, @refs) = @_;
    @refs or
	return defined $self->{_BOUND_COLUMNS} ? @{$self->{_BOUND_COLUMNS}} : undef;

    if (@refs == 1 && ! defined $refs[0]) {
	$self->{_COLUMN_NAMES} = undef;
	return $self->{_BOUND_COLUMNS} = undef;
	}

    $self->{_COLUMN_NAMES} && @refs != @{$self->{_COLUMN_NAMES}} and
	croak ($self->SetDiag (3003));

    join "", map { ref $_ eq "SCALAR" ? "" : "*" } @refs and
	croak ($self->SetDiag (3004));

    $self->_set_attr_N ("_is_bound", scalar @refs);
    $self->{_BOUND_COLUMNS} = [ @refs ];
    @refs;
    } # bind_columns

sub getline_hr
{
    my ($self, @args, %hr) = @_;
    $self->{_COLUMN_NAMES} or croak ($self->SetDiag (3002));
    my $fr = $self->getline (@args) or return;
    if (ref $self->{_FFLAGS}) {
	$self->{_FFLAGS}[$_] = 0x0010 for ($#{$fr} + 1) .. $#{$self->{_COLUMN_NAMES}};
	}
    @hr{@{$self->{_COLUMN_NAMES}}} = @$fr;
    \%hr;
    } # getline_hr

sub getline_hr_all
{
    my ($self, @args, %hr) = @_;
    $self->{_COLUMN_NAMES} or croak ($self->SetDiag (3002));
    my @cn = @{$self->{_COLUMN_NAMES}};
    [ map { my %h; @h{@cn} = @$_; \%h } @{$self->getline_all (@args)} ];
    } # getline_hr_all

sub print_hr
{
    my ($self, $io, $hr) = @_;
    $self->{_COLUMN_NAMES} or croak ($self->SetDiag (3009));
    ref $hr eq "HASH"      or croak ($self->SetDiag (3010));
    $self->print ($io, [ map { $hr->{$_} } $self->column_names ]);
    } # print_hr

sub fragment
{
    my ($self, $io, $spec) = @_;

    my $qd = qr{\s* [0-9]+ \s* }x;		# digit
    my $qs = qr{\s* (?: [0-9]+ | \* ) \s*}x;	# digit or star
    my $qr = qr{$qd (?: - $qs )?}x;		# range
    my $qc = qr{$qr (?: ; $qr )*}x;		# list
    defined $spec && $spec =~ m{^ \s*
	\x23 ? \s*				# optional leading #
	( row | col | cell ) \s* =
	( $qc					# for row and col
	| $qd , $qd (?: - $qs , $qs)?		# for cell (ranges)
	  (?: ; $qd , $qd (?: - $qs , $qs)? )*	# and cell (range) lists
	) \s* $}xi or croak ($self->SetDiag (2013));
    my ($type, $range) = (lc $1, $2);

    my @h = $self->column_names ();

    my @c;
    if ($type eq "cell") {
	my @spec;
	my $min_row;
	my $max_row = 0;
	for (split m/\s*;\s*/ => $range) {
	    my ($tlr, $tlc, $brr, $brc) = (m{
		    ^ \s* ([0-9]+     ) \s* , \s* ([0-9]+     ) \s*
		(?: - \s* ([0-9]+ | \*) \s* , \s* ([0-9]+ | \*) \s* )?
		    $}x) or croak ($self->SetDiag (2013));
	    defined $brr or ($brr, $brc) = ($tlr, $tlc);
	    $tlr == 0 || $tlc == 0 ||
		($brr ne "*" && ($brr == 0 || $brr < $tlr)) ||
		($brc ne "*" && ($brc == 0 || $brc < $tlc))
		    and croak ($self->SetDiag (2013));
	    $tlc--;
	    $brc-- unless $brc eq "*";
	    defined $min_row or $min_row = $tlr;
	    $tlr < $min_row and $min_row = $tlr;
	    $brr eq "*" || $brr > $max_row and
		$max_row = $brr;
	    push @spec, [ $tlr, $tlc, $brr, $brc ];
	    }
	my $r = 0;
	while (my $row = $self->getline ($io)) {
	    ++$r < $min_row and next;
	    my %row;
	    my $lc;
	    foreach my $s (@spec) {
		my ($tlr, $tlc, $brr, $brc) = @$s;
		$r <  $tlr || ($brr ne "*" && $r > $brr) and next;
		!defined $lc || $tlc < $lc and $lc = $tlc;
		my $rr = $brc eq "*" ? $#$row : $brc;
		$row{$_} = $row->[$_] for $tlc .. $rr;
		}
	    push @c, [ @row{sort { $a <=> $b } keys %row } ];
	    if (@h) {
		my %h; @h{@h} = @{$c[-1]};
		$c[-1] = \%h;
		}
	    $max_row ne "*" && $r == $max_row and last;
	    }
	return \@c;
	}

    # row or col
    my @r;
    my $eod = 0;
    for (split m/\s*;\s*/ => $range) {
	my ($from, $to) = m/^\s* ([0-9]+) (?: \s* - \s* ([0-9]+ | \* ))? \s* $/x
	    or croak ($self->SetDiag (2013));
	$to ||= $from;
	$to eq "*" and ($to, $eod) = ($from, 1);
	$from <= 0 || $to <= 0 || $to < $from and croak ($self->SetDiag (2013));
	$r[$_] = 1 for $from .. $to;
	}

    my $r = 0;
    $type eq "col" and shift @r;
    $_ ||= 0 for @r;
    while (my $row = $self->getline ($io)) {
	$r++;
	if ($type eq "row") {
	    if (($r > $#r && $eod) || $r[$r]) {
		push @c, $row;
		if (@h) {
		    my %h; @h{@h} = @{$c[-1]};
		    $c[-1] = \%h;
		    }
		}
	    next;
	    }
	push @c, [ map { ($_ > $#r && $eod) || $r[$_] ? $row->[$_] : () } 0..$#$row ];
	if (@h) {
	    my %h; @h{@h} = @{$c[-1]};
	    $c[-1] = \%h;
	    }
	}

    return \@c;
    } # fragment

my $csv_usage = q{usage: my $aoa = csv (in => $file);};

sub _csv_attr
{
    my %attr = (@_ == 1 && ref $_[0] eq "HASH" ? %{$_[0]} : @_) or croak;

    $attr{binary} = 1;

    my $enc = delete $attr{encoding} || "";

    my $fh;
    my $cls = 0;	# If I open a file, I have to close it
    my $in  = delete $attr{in}  || delete $attr{file} or croak $csv_usage;
    my $out = delete $attr{out} || delete $attr{file};

    if ($out) {
	$in or croak $csv_usage;	# No out without in
	defined $attr{eol} or $attr{eol} = "\r\n";
	if (ref $out or "GLOB" eq ref \$out) {
	    $fh = $out;
	    }
	else {
	    $enc =~ m/^[-\w.]+$/ and $enc = ":encoding($enc)";
	    open $fh, ">$enc", $out or croak "$out: $!";
	    $cls = 1;
	    }
	}

    if (   ref $in eq "CODE") {		# we need an out
	$out or croak qq{for CSV source, "out" is required};
	}
    elsif (ref $in eq "ARRAY") {	# we need an out
	$out or croak qq{for CSV source, "out" is required};
	}
    elsif (ref $in eq "SCALAR") {
	open $fh, "<", $in or croak "Cannot open from SCALAR usinng PerlIO";
	$cls = 1;
	}
    elsif (ref $in or "GLOB" eq ref \$in) {
	if (!ref $in && $] < 5.008005) {
	    $fh = \*$in;
	    }
	else {
	    $fh = $in;
	    }
	}
    else {
	$enc =~ m/^[-\w.]+$/ and $enc = ":encoding($enc)";
	open $fh, "<$enc", $in or croak "$in: $!";
	$cls = 1;
	}
    $fh or croak qq{No valid source passed. "in" is required};

    my $hdrs = delete $attr{headers};
    my $frag = delete $attr{fragment};

    my $cbai = delete $attr{callbacks}{after_in}   ||
	       delete $attr{after_in};
    my $cbbo = delete $attr{callbacks}{before_out} ||
	       delete $attr{before_out};
    my $cboi = delete $attr{callbacks}{on_in}      ||
	       delete $attr{on_in};

    defined $attr{auto_diag} or $attr{auto_diag} = 1;
    my $csv = Text::CSV_XS->new (\%attr) or croak $last_new_err;

    return {
	csv  => $csv,
	fh   => $fh,
	cls  => $cls,
	in   => $in,
	out  => $out,
	hdrs => $hdrs,
	frag => $frag,
	cbai => $cbai,
	cbbo => $cbbo,
	cboi => $cboi,
	};
    } # _csv_attr

sub csv
{
    # This is a function, not a method
    @_ && ref $_[0] ne __PACKAGE__ or croak $csv_usage;

    my $c = _csv_attr (@_);

    my ($csv, $in, $fh, $hdrs) = @{$c}{"csv", "in", "fh", "hdrs"};

    if ($c->{out}) {
	if (ref $in eq "CODE") {
	    my $hdr = 1;
	    while (my $row = $in->($csv)) {
		if (ref $row eq "ARRAY") {
		    $csv->print ($fh, $row);
		    next;
		    }
		if (ref $row eq "HASH") {
		    if ($hdr) {
			$hdrs ||= [ keys %$row ];
			$csv->print ($fh, $hdrs);
			$hdr = 0;
			}
		    $csv->print ($fh, [ @{$row}{@$hdrs} ]);
		    }
		}
	    }
	elsif (ref $in->[0] eq "ARRAY") { # aoa
	    ref $hdrs and $csv->print ($fh, $hdrs);
	    for (@{$in}) {
		$c->{cboi} and $c->{cboi}->($csv, $_);
		$c->{cbbo} and $c->{cbbo}->($csv, $_);
		$csv->print ($fh, $_);
		}
	    }
	else { # aoh
	    my @hdrs = ref $hdrs ? @{$hdrs} : keys %{$in->[0]};
	    defined $hdrs or $hdrs = "auto";
	    ref $hdrs || $hdrs eq "auto" and $csv->print ($fh, \@hdrs);
	    for (@{$in}) {
		$c->{cboi} and $c->{cboi}->($csv, $_);
		$c->{cbbo} and $c->{cbbo}->($csv, $_);
		$csv->print ($fh, [ @{$_}{@hdrs} ]);
		}
	    }

	$c->{cls} and close $fh;
	return 1;
	}

    ref $in eq "CODE" and croak "CODE only valid fro in when using out";

    if (defined $hdrs && !ref $hdrs) {
	$hdrs eq "skip" and         $csv->getline ($fh);
	$hdrs eq "auto" and $hdrs = $csv->getline ($fh);
	}

    my $frag = $c->{frag};
    my $ref = ref $hdrs
	? # aoh
	  do {
	    $csv->column_names ($hdrs);
	    $frag ? $csv->fragment ($fh, $frag) : $csv->getline_hr_all ($fh);
	    }
	: # aoa
	    $frag ? $csv->fragment ($fh, $frag) : $csv->getline_all ($fh);
    $ref or Text::CSV_XS->auto_diag;
    $c->{cls} and close $fh;
    if ($ref and $c->{cbai} || $c->{cboi}) {
	for (@{$ref}) {
	    $c->{cbai} and $c->{cbai}->($csv, $_);
	    $c->{cboi} and $c->{cboi}->($csv, $_);
	    }
	}
    return $ref;
    } # csv

1;

__END__

#line 2898

#line 2903
