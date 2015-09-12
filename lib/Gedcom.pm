#line 1 "Gedcom.pm"
# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom;

use Carp;
use Data::Dumper;
use FileHandle;

BEGIN { eval "use Text::Soundex" }           # We'll use this if it is available

use vars qw($VERSION $AUTOLOAD %Funcs);

my $Tags;
my %Top_tag_order;

BEGIN
{
  $VERSION = "1.19";

  $Tags =
  {
    ABBR => "Abbreviation",
    ADDR => "Address",
    ADOP => "Adoption",
    ADR1 => "Address1",
    ADR2 => "Address2",
    AFN  => "Afn",
    AGE  => "Age",
    AGNC => "Agency",
    ALIA => "Alias",
    ANCE => "Ancestors",
    ANCI => "Ances Interest",
    ANUL => "Annulment",
    ASSO => "Associates",
    AUTH => "Author",
    BAPL => "Baptism-LDS",
    BAPM => "Baptism",
    BARM => "Bar Mitzvah",
    BASM => "Bas Mitzvah",
    BIRT => "Birth",
    BLES => "Blessing",
    BLOB => "Binary Object",
    BURI => "Burial",
    CALN => "Call Number",
    CAST => "Caste",
    CAUS => "Cause",
    CENS => "Census",
    CHAN => "Change",
    CHAR => "Character",
    CHIL => "Child",
    CHR  => "Christening",
    CHRA => "Adult Christening",
    CITY => "City",
    CONC => "Concatenation",
    CONF => "Confirmation",
    CONL => "Confirmation L",
    CONT => "Continued",
    COPR => "Copyright",
    CORP => "Corporate",
    CREM => "Cremation",
    CTRY => "Country",
    DATA => "Data",
    DATE => "Date",
    DEAT => "Death",
    DESC => "Descendants",
    DESI => "Descendant Int",
    DEST => "Destination",
    DIV  => "Divorce",
    DIVF => "Divorce Filed",
    DSCR => "Phy Description",
    EDUC => "Education",
    EMIG => "Emigration",
    ENDL => "Endowment",
    ENGA => "Engagement",
    EVEN => "Event",
    FAM  => "Family",
    FAMC => "Family Child",
    FAMF => "Family File",
    FAMS => "Family Spouse",
    FCOM => "First Communion",
    FILE => "File",
    FORM => "Format",
    GEDC => "Gedcom",
    GIVN => "Given Name",
    GRAD => "Graduation",
    HEAD => "Header",
    HUSB => "Husband",
    IDNO => "Ident Number",
    IMMI => "Immigration",
    INDI => "Individual",
    LANG => "Language",
    LEGA => "Legatee",
    MARB => "Marriage Bann",
    MARC => "Marr Contract",
    MARL => "Marr License",
    MARR => "Marriage",
    MARS => "Marr Settlement",
    MEDI => "Media",
    NAME => "Name",
    NATI => "Nationality",
    NATU => "Naturalization",
    NCHI => "Children_count",
    NICK => "Nickname",
    NMR  => "Marriage_count",
    NOTE => "Note",
    NPFX => "Name_prefix",
    NSFX => "Name_suffix",
    OBJE => "Object",
    OCCU => "Occupation",
    ORDI => "Ordinance",
    ORDN => "Ordination",
    PAGE => "Page",
    PEDI => "Pedigree",
    PHON => "Phone",
    PLAC => "Place",
    POST => "Postal_code",
    PROB => "Probate",
    PROP => "Property",
    PUBL => "Publication",
    QUAY => "Quality Of Data",
    REFN => "Reference",
    RELA => "Relationship",
    RELI => "Religion",
    REPO => "Repository",
    RESI => "Residence",
    RESN => "Restriction",
    RETI => "Retirement",
    RFN  => "Rec File Number",
    RIN  => "Rec Id Number",
    ROLE => "Role",
    SEX  => "Sex",
    SLGC => "Sealing Child",
    SLGS => "Sealing Spouse",
    SOUR => "Source",
    SPFX => "Surn Prefix",
    SSN  => "Soc Sec Number",
    STAE => "State",
    STAT => "Status",
    SUBM => "Submitter",
    SUBN => "Submission",
    SURN => "Surname",
    TEMP => "Temple",
    TEXT => "Text",
    TIME => "Time",
    TITL => "Title",
    TRLR => "Trailer",
    TYPE => "Type",
    VERS => "Version",
    WIFE => "Wife",
    WILL => "Will",
  };

  %Top_tag_order =
  (
    HEAD => 1,
    SUBM => 2,
    INDI => 3,
    FAM  => 4,
    NOTE => 5,
    REPO => 6,
    SOUR => 7,
    TRLR => 8,
  );

  while (my ($tag, $name) = each (%$Tags))
  {
    $Funcs{$tag} = $Funcs{lc $tag} = $tag;
    if ($name)
    {
      $name =~ s/ /_/g;
      $Funcs{lc $name} = $tag;
    }
  }
}

sub DESTROY {}

sub AUTOLOAD
{
  my ($self) = @_;                         # don't change @_ because of the goto
  my $func = $AUTOLOAD;
  # print "autoloading $func\n";
  $func =~ s/^.*:://;
  my $tag;
  croak "Undefined subroutine $func called"
    if $func !~ /^(add|get)_(.*)$/ ||
       !($tag = $Funcs{lc $2}) ||
       !exists $Top_tag_order{$tag};
  no strict "refs";
  if ($1 eq "add")
  {
    *$func = sub
    {
      my $self = shift;
      my ($arg, $val) = @_;
      my $xref;
      if (ref $arg)
      {
        $xref = $arg->{xref};
      }
      else
      {
        $val = $arg;
      }
      my $record = $self->add_record(tag => $tag, val => $val);
      if (defined $val && $tag eq "NOTE")
      {
        $record->{value} = $val;
      }
      $xref = $tag eq "SUBM" ? "SUBM" : substr $tag, 0, 1
        unless defined $xref;
      unless ($tag =~ /^(HEAD|TRLR)$/)
      {
        croak "Invalid xref $xref requested in $func"
          unless $xref =~ /^[^\W\d_]+(\d*)$/;
        $xref = $self->next_xref($xref) unless length $1;
        $record->{xref} = $xref;
        $self->{xrefs}{$xref} = $record;
      }
      $record
    };
  }
  else
  {
    *$func = sub
    {
      my $self   = shift;
      my ($xref) = @_;
      my $nxr    = !defined $xref;
      my @a      = grep { $_->{tag} eq $tag && ($nxr || $_->{xref} eq $xref) }
                        @{$self->{record}->_items};
      wantarray ? @a : $a[0]
    };
  }
  goto &$func
}

use Gedcom::Grammar    1.19;
use Gedcom::Individual 1.19;
use Gedcom::Family     1.19;
use Gedcom::Event      1.19;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  @_ = (gedcom_file => @_) if @_ == 1;
  my $self =
  {
    records   => [],
    tags      => $Tags,
    read_only => 0,
    types     => {},
    xrefs     => {},
    encoding  => "ansel",
    @_
  };

  # TODO - find a way to do this nicely for different grammars
  $self->{types}{INDI} = "Individual";
  $self->{types}{FAM}  = "Family";
  $self->{types}{$_}   = "Event"
    for qw( ADOP ANUL BAPM BARM BASM BIRT BLES BURI CAST CENS CENS CHR CHRA CONF
            CREM DEAT DIV DIVF DSCR EDUC EMIG ENGA EVEN EVEN FCOM GRAD IDNO IMMI
            MARB MARC MARL MARR MARS NATI NATU NCHI NMR OCCU ORDN PROB PROP RELI
            RESI RETI SSN WILL );
  bless $self, $class;

  # first read in the grammar
  my $grammar;
  if (defined $self->{grammar_file})
  {
    my $version;
    if (defined $self->{grammar_version})
    {
      $version = $self->{grammar_version};
    }
    else
    {
      ($version) = $self->{grammar_file} =~ /(\d+(\.\d+)*)/;
    }
    die "version must be a gedcom version number\n" unless $version;
    return undef unless
      $grammar = Gedcom::Grammar->new(file     => $self->{grammar_file},
                                      version  => $version,
                                      callback => $self->{callback});
  }
  else
  {
    $self->{grammar_version} = 5.5 unless defined $self->{grammar_version};
    (my $v = $self->{grammar_version}) =~ tr/./_/;
    my $g = "Gedcom::Grammar_$v";
    eval "use $g $VERSION";
    die $@ if $@;
    no strict "refs";
    return undef unless $grammar = ${$g . "::grammar"};
  }
  my @c = ($self->{grammar} = $grammar);
  while (@c)
  {
    @c = map { $_->{top} = $grammar; @{$_->{items}} } @c;
  }

  # now read in or create the gedcom file
  return undef unless
    my $r = $self->{record} = Gedcom::Record->new
    (
      defined $self->{gedcom_file} ? (file => $self->{gedcom_file}) : (),
      line     => 0,
      tag      => "GEDCOM",
      grammar  => $grammar->structure("GEDCOM"),
      gedcom   => $self,
      callback => $self->{callback}
    );

  unless (defined $self->{gedcom_file})
  {

    # Add the required elements, unless they are already there.

    unless ($r->get_record("head"))
    {
      my $me = "Unknown user";
      my $login = $me;
      if ($login = getlogin || (getpwuid($<))[0] || $ENV{USER} || $ENV{LOGIN})
      {
        my $name;
        eval { $name = (getpwnam($login))[6] };
        $me = $name || $login;
      }
      my $date = localtime;

      my ($l0, $l1, $l2, $l3);
      $l0 = $self->add_header;
        $l1 = $l0->add("SOUR", "Gedcom.pm");
        $l1->add("NAME", "Gedcom.pm");
        $l1->add("VERS", $VERSION);
          $l2 = $l1->add("CORP", "Paul Johnson");
          $l2->add("ADDR", "http://www.pjcj.net");
          $l2 = $l1->add("DATA");
            $l3 = $l2->add("COPR",
                           'Copyright 1998-2013, Paul Johnson (paul@pjcj.net)');
        $l1 = $l0->add("NOTE", "");
      for (split /\n/, <<'EOH')
This output was generated by Gedcom.pm.
Gedcom.pm is Copyright 1999-2013, Paul Johnson (paul@pjcj.net)
Version 1.19 - 18th August 2013

Gedcom.pm is free.  It is licensed under the same terms as Perl itself.

The latest version of Gedcom.pm should be available from my homepage:
http://www.pjcj.net
EOH
      {
        $l1->add("CONT", $_);
      };
        $l1 = $l0->add("GEDC");
        $l1->add("VERS", $self->{grammar}{version});
        $l1->add("FORM", "LINEAGE-LINKED");
      $l0->add("DATE", $date);
      $l0->add("CHAR", uc ($self->{encoding} || "ansel"));
      my $s = $r->get_record("subm");
      unless ($s)
      {
        $s = $self->add_submitter;
        $s->add("NAME", $me);
      }
      $l0->add("SUBM", $s->xref);
    }

    $self->add_trailer unless $r->get_record("trlr");
  }

  $self->collect_xrefs;

  $self
}

sub set_encoding
{
  my $self = shift;
  ($self->{encoding}) = @_;
}

sub write
{
  my $self  = shift;
  my $file  = shift or die "No filename specified";
  my $flush = shift;
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  binmode $self->{fh}, ":encoding(UTF-8)"
    if $self->{encoding} eq "utf-8" && $] >= 5.8;
  $self->{record}->write($self->{fh}, -1, $flush);
  $self->{fh}->close or die "Can't close $file: $!";
}

sub write_xml
{
  my $self = shift;
  my $file = shift or die "No filename specified";
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  binmode $self->{fh}, ":encoding(UTF-8)"
    if $self->{encoding} eq "utf-8" && $] >= 5.8;
  $self->{fh}->print(<<'EOH');
<?xml version="1.0" encoding="utf-8"?>

<!--

This output was generated by Gedcom.pm.
Gedcom.pm is Copyright 1999-2013, Paul Johnson (paul@pjcj.net)
Version 1.19 - 18th August 2013

Gedcom.pm is free.  It is licensed under the same terms as Perl itself.

The latest version of Gedcom.pm should be available from my homepage:
http://www.pjcj.net

EOH
  $self->{fh}->print("Generated on " . localtime() . "\n\n-->\n\n");
  $self->{record}->write_xml($self->{fh});
  $self->{fh}->close or die "Can't close $file: $!";
}

sub add_record
{
  my $self = shift;
  $self->{record}->add_record(@_);
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{xrefs} = {};
  $self->{record}->collect_xrefs($callback);
}

sub resolve_xref
{
  my $self = shift;;
  my ($x) = @_;
  my $xref;
  $xref = $self->{xrefs}{$x =~ /^\@(.+)\@$/ ? $1 : $x} if defined $x;
  $xref
}

sub resolve_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{record}->resolve_xrefs($callback);
}

sub unresolve_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{record}->unresolve_xrefs($callback);
}

sub validate
{
  my $self = shift;
  my ($callback) = @_;
  $self->{validate_callback} = $callback;
  my $ok = $self->{record}->validate_syntax;
  for my $item (@{$self->{record}->_items})
  {
    $ok = 0 unless $item->validate_semantics;
  }
  $ok
}

sub normalise_dates
{
  my $self = shift;
  $self->{record}->normalise_dates(@_);
}

sub renumber
{
  my $self = shift;
  my (%args) = @_;
  $self->resolve_xrefs;

  # initially, renumber any records passed in
  for my $xref (@{$args{xrefs}})
  {
    $self->{xrefs}{$xref}->renumber(\%args, 1) if exists $self->{xrefs}{$xref};
  }

  # now, renumber any records left over
  $_->renumber(\%args, 1) for @{$self->{record}->_items};

  # actually change the xref
  for my $record (@{$self->{record}->_items})
  {
    $record->{xref} = delete $record->{new_xref};
    delete $record->{recursed}
  }

  # and update the xrefs
  $self->collect_xrefs;

  %args
}

sub sort_sub
{
  # subroutine to sort on tag order first, and then on xref

  my $t = sub
  {
    my ($r) = @_;
    return -2 unless defined $r->{tag};
    exists $Top_tag_order{$r->{tag}} ? $Top_tag_order{$r->{tag}} : -1
  };

  my $x = sub
  {
    my ($r) = @_;
    return -2 unless defined $r->{xref};
    $r->{xref} =~ /(\d+)/;
    defined $1 ? $1 : -1
  };

  sub
  {
    $t->($a) <=> $t->($b)
              ||
    $x->($a) <=> $x->($b)
  }
}

sub order
{
  my $self     = shift;
  my $sort_sub = shift || sort_sub;   # use default sort unless one is passed in
  @{$self->{record}{items}} = sort $sort_sub @{$self->{record}->_items}
}

sub items
{
  my $self = shift;
  @{$self->{record}->_items}
}

sub heads        { grep $_->tag eq "HEAD",           shift->items }
sub submitters   { grep $_->tag eq "SUBM",           shift->items }
sub individuals  { grep ref eq "Gedcom::Individual", shift->items }
sub families     { grep ref eq "Gedcom::Family",     shift->items }
sub notes        { grep $_->tag eq "NOTE",           shift->items }
sub repositories { grep $_->tag eq "REPO",           shift->items }
sub sources      { grep $_->tag eq "SOUR",           shift->items }
sub trailers     { grep $_->tag eq "TRLR",           shift->items }

sub get_individual
{
  my $self = shift;
  my $name = "@_";
  my $all = wantarray;
  my @i;

  my $i = $self->resolve_xref($name) || $self->resolve_xref(uc $name);
  if ($i)
  {
    return $i unless $all;
    push @i, $i;
  }

  # search for the name in the specified order
  my $ordered = sub
  {
    my ($n, @ind) = @_;
    map { $_->[1] } grep { $_ && $_->[0] =~ $n } @ind
  };

  # search for the name in any order
  my $unordered = sub
  {
    my ($names, $t, @ind) = @_;
    map { $_->[1] }
        grep
        {
          my $i = $_->[0];
          my $r = 1;
          for my $n (@$names)
          {
            # remove matches as they are found
            # we don't want to match the same name twice
            last unless $r = $i =~ s/$n->[$t]//;
          }
          $r
        }
        @ind;
  };

  # look for various matches in decreasing order of exactitude
  my @individuals = $self->individuals;

  # Store the name with the individual to avoid continually recalculating it.
  # This is a bit like a Schwartzian transform, with a grep instead of a sort.
  my @ind =
    map { [ do { my $n = $_->tag_value("NAME"); defined $n ? $n : "" } => $_ ] }
    @individuals;

  for my $n ( map { qr/^$_$/, qr/\b$_\b/, $_ } map { $_, qr/$_/i } qr/\Q$name/ )
  {
    push @i, $ordered->($n, @ind);
    return $i[0] if !$all && @i;
  }

  # create an array with one element per name
  # each element is an array of REs in decreasing order of exactitude
  my @names = map { [ map { qr/\b$_\b/, $_ } map { qr/$_/, qr/$_/i } "\Q$_" ] }
              split / /, $name;
  for my $t (0 .. $#{$names[0]})
  {
    push @i, $unordered->(\@names, $t, @ind);
    return $i[0] if !$all && @i;
  }

  # check soundex
  my @sdx = map { my $s = $_->soundex; $s ? [ $s => $_ ] : () } @individuals;

  my $soundex = soundex($name);
  for my $n ( map { qr/$_/ } $name, ($soundex || ()) )
  {
    push @i, $ordered->($n, @sdx);
    return $i[0] if !$all && @i;
  }

  return undef unless $all;

  my @s;
  my %s;
  for (@i)
  {
    unless (exists $s{$_->{xref}})
    {
      push @s, $_;
      $s{$_->{xref}}++;
    }
  }

  @s
}

sub next_xref
{
  my $self = shift;
  my ($type) = @_;
  my $re = qr/^$type(\d+)$/;
  my $last = 0;
  for my $c (@{$self->{record}->_items})
  {
    $last = $1 if defined $c->{xref} and $c->{xref} =~ /$re/ and $1 > $last;
  }
  $type . ++$last
}

sub top_tag
{
  my $self = shift;
  my ($tag) = @_;
  $Top_tag_order{$tag}
}

1;

__END__

#line 1240
