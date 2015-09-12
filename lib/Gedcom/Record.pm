#line 1 "Gedcom/Record.pm"
# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Record;

use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = "1.19";
@ISA     = qw( Gedcom::Item );

use Carp;
BEGIN { eval "use Date::Manip" }             # We'll use this if it is available

use Gedcom::Item       1.19;
use Gedcom::Comparison 1.19;

BEGIN
{
  use subs keys %Gedcom::Funcs;
  *tag_record    = \&Gedcom::Item::get_item;
  *delete_record = \&Gedcom::Item::delete_item;
  *get_record    = \&record;
}

sub DESTROY {}

sub AUTOLOAD
{
  my ($self) = @_;                         # don't change @_ because of the goto
  my $func = $AUTOLOAD;
  # print "autoloading $func\n";
  $func =~ s/^.*:://;
  carp "Undefined subroutine $func called" unless $Gedcom::Funcs{lc $func};
  no strict "refs";
  *$func = sub
  {
    my $self = shift;
    my ($count) = @_;
    my $v;
    # print "[[ $func ]]\n";
    if (wantarray)
    {
      return map
        { $_ && do { $v = $_->full_value; defined $v && length $v ? $v : $_ } }
        $self->record([$func, $count]);
    }
    else
    {
      my $r = $self->record([$func, $count]);
      return $r && do { $v = $r->full_value; defined $v && length $v ? $v : $r }
    }
  };
  goto &$func
}

sub record
{
  my $self = shift;
  my @records = ($self);
  for my $func (map { ref() ? $_ : split } @_)
  {
    my $count = 0;
    ($func, $count) = @$func if ref $func eq "ARRAY";
    if (ref $func)
    {
      warn "Invalid record of type ", ref $func, " requested";
      return undef;
    }
    my $record = $Gedcom::Funcs{lc $func};
    unless ($record)
    {
      warn $func
      ? "Non standard record of type $func requested"
      : "Record type not specified";
      $record = $func;
    }

    @records = map { $_->tag_record($record, $count) } @records;

    # fams and famc need to be resolved
    @records = map { $self->resolve($_->{value}) } @records
      if $record eq "FAMS" || $record eq "FAMC";
  }
  wantarray ? @records : $records[0]
}

sub get_value
{
  my $self = shift;
  if (wantarray)
  {
    return map { my $v = $_->full_value; defined $v and length $v ? $v : () }
               $self->record(@_);
  }
  else
  {
    my $record = $self->record(@_);
    return $record && $record->full_value;
  }
}

sub tag_value
{
  my $self = shift;
  if (wantarray)
  {
    return map { my $v = $_->full_value; defined $v and length $v ? $v : () }
               $self->tag_record(@_);
  }
  else
  {
    my $record = $self->tag_record(@_);
    return $record && $record->full_value;
  }
}

sub add_record
{
  my $self = shift;
  my (%args) = @_;

  die "No tag specified" unless defined $args{tag};

  my $record = Gedcom::Record->new
  (
    gedcom   => $self->{gedcom},
    callback => $self->{callback},
    tag      => $args{tag},
  );

  if (!defined $self->{grammar})
  {
    warn "$self->{tag} has no grammar\n";
  }
  elsif (my @g = $self->{grammar}->item($args{tag}))
  {
    # use DDS; print Dump \@g;
    my $grammar = $g[0];
    for my $g (@g)
    {
      # print "testing $args{tag} ", $args{val}  // "undef", " against ",
                                   # $g->{value} // "undef", "\n";
      if ($args{tag} eq "NOTE")
      {
        if (( defined $args{xref} && $g->{value} =~ /xref/i) ||
            (!defined $args{xref} && $g->{value} !~ /xref/i))
        {
          # print "note match\n";
          $grammar = $g;
          last;
        }
      }
      else
      {
        if (( defined $args{val} &&  $g->{value}) ||
            (!defined $args{val} && !$g->{value}))
        {
          # print "match\n";
          $grammar = $g;
          last;
        }
      }
    }
    $self->parse($record, $grammar);
  }
  else
  {
    warn "$args{tag} is not a sub-item of $self->{tag}\n";
  }

  push @{$self->{items}}, $record;

  $record
}

sub add
{
  my $self = shift;
  my ($xref, $val);
  if (@_ > 1 && ref $_[-1] ne "ARRAY")
  {
    $val = pop;
    if (UNIVERSAL::isa($val, "Gedcom::Record"))
    {
      $xref = $val;
      $val  = undef;
    }
  }

  my @funcs = map { ref() ? $_ : split } @_;
  $funcs[-1] = [$funcs[-1], 0] unless ref $funcs[-1];
  push @{$funcs[-1]}, { xref => $xref, val => $val };
  my $record = $self->get_and_create(@funcs);

  if (defined $xref)
  {
    $record->{value} = $xref->{xref};
    $self->{gedcom}{xrefs}{$xref->{xref}} = $xref;
  }

  if (defined $val)
  {
    $record->{value} = $val;
  }

  $record
}

sub set
{
  my $self = shift;
  my $val = pop;

  my @funcs = map { ref() ? $_ : split } @_;
  my $r = $self->get_and_create(@funcs);

  if (UNIVERSAL::isa($val, "Gedcom::Record"))
  {
    $r->{value} = $val->{xref};
    $self->{gedcom}{xrefs}{$val->{xref}} = $val;
  }
  else
  {
    $r->{value} = $val;
  }

  $r
}

sub get_and_create
{
  my $self = shift;
  my @funcs = @_;

  # use DDS; print "get_and_create: " , Dump \@funcs;

  my $rec = $self;
  for my $f (0 .. $#funcs)
  {
    my ($func, $count, $args) = ($funcs[$f], 1);
    $args = {} unless defined $args;
    ($func, $count, $args) = @$func if ref $func eq "ARRAY";
    $count--;

    if (ref $func)
    {
      warn "Invalid record of type ", ref $func, " requested";
      return undef;
    }

    my $record = $Gedcom::Funcs{lc $func};
    unless ($record)
    {
      warn $func
      ? "Non standard record of type $func requested"
      : "Record type not specified";
      $record = $func;
    }

    # print "$func [$count] - $record\n";

    my @records = $rec->tag_record($record);

    if ($count < 0)
    {
      $rec = $rec->add_record(tag => $record, %$args);
    }
    elsif ($#records < $count)
    {
      my $new;
      $new = $rec->add_record(tag => $record, %$args)
        for (0 .. @records - $count);
      $rec = $new;
    }
    else
    {
      $rec = $records[$count];
    }
  }

  $rec
}

sub parse
{
  # print "parsing\n";
  my $self = shift;
  my ($record, $grammar, $test) = @_;
  $test ||= 0;

  # print "checking "; $record->print();
  # print "against ";  $grammar->print();
  # print "test is $test\n";

  my $t = $record->{tag};
  my $g = $grammar->{tag};
  die "Can't match $t with $g" if $t && $t ne $g;               # internal error

  $record->{grammar} = $grammar;
  my $class = $record->{gedcom}{types}{$t};
  bless $record, "Gedcom::$class" if $class;

  my $match = 1;

  for my $r (@{$record->{items}})
  {
    my $tag = $r->{tag};
    my @i;
    # print "- valid sub-items of $t are @{[keys %{$grammar->valid_items}]}\n";
    for my $i ($grammar->item($tag))
    {
      # Try to get rid of matches we don't want because they only match
      # in name.

      # Check that the level is appropriate.
      # print " - ", $i->level, "|", $r->level, "\n";
      next unless $i->level =~ /^[+0]/ || $i->level == $r->level;

      # Check we have a pointer iff we need one.
      # print " + ", $i->value, "|", $r->value, "|", $r->pointer, "\n";
      # next if $i->value && $r->value && ($i->value =~ /^<XREF:/ ^ $r->pointer);
      next if $i->value && ($i->value =~ /^<XREF:/ ^ ($r->pointer || 0));

      # print "pushing\n";
      push @i, $i;
    }

    # print "valid sub-items of $t are @{[keys %{$grammar->valid_items}]}\n";
    # print "<$tag> => <@i>\n";

    unless (@i)
    {
      # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
      # TODO - should CONT and CONC be allowed anywhere?
      unless (substr($tag, 0, 1) eq "_")
      {
        warn "$self->{file}:$r->{line}: $tag is not a sub-item of $t\n",
             "Valid sub-items are ",
             join(", ", sort keys %{$grammar->{_valid_items}}), "\n"
          unless $test;
        $match = 0;
        next;
      }
    }

    # print "$self->{file}:$r->{line}: Ambiguous tag $tag as sub-item of $t, ",
          # "found ", scalar @i, " matches\n" if @i > 1;
    my $m = 0;
    for my $i (@i)
    {
      last if $m = $self->parse($r, $i, @i > 1);
    }

    if (@i > 1 && !$m)
    {
      # TODO - I'm not even sure if this can happen.
      warn "$self->{file}:$r->{line}: Ambiguous tag $tag as sub-item of $t, ",
           "found ", scalar @i, " matches, all of which have errors.  ",
           "Reporting errors from last match.\n";
      $self->parse($r, $i[-1]);
      $match = 0;
      # TODO - count the errors in each match and use the best.
    }
  }
  # print "parsed $match\n";

  $match
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{gedcom}{xrefs}{$self->{xref}} = $self if defined $self->{xref};
  $_->collect_xrefs($callback) for @{$self->{items}};
  $self
}

sub resolve_xref
{
  shift->{gedcom}->resolve_xref(@_);
}

sub resolve
{
  my $self = shift;
  my @x = map
  {
    ref($_)
    ? $_
    : do { my $x = $self->{gedcom}->resolve_xref($_); defined $x ? $x : () }
  } @_;
  wantarray ? @x : $x[0];
}

sub resolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  if (my $xref = $self->{gedcom}->resolve_xref($self->{value}))
  {
    $self->{value} = $xref;
  }
  $_->resolve_xrefs($callback) for @{$self->_items};
  $self
}

sub unresolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  $self->{value} = $self->{value}{xref}
    if defined $self->{value}
       and UNIVERSAL::isa $self->{value}, "Gedcom::Record"
       and exists $self->{value}{xref};
  $_->unresolve_xrefs($callback) for @{$self->_items};
  $self
}

my $D =  0;                                               # turn on debug output
my $I = -1;                                            # indent for debug output

sub validate_syntax
{
  my $self = shift;
  return 1 unless exists $self->{grammar};
  my $ok = 1;
  $self->{gedcom}{validate_callback}->($self)
    if defined $self->{gedcom}{validate_callback};
  my $grammar = $self->{grammar};
  $I++;
  print "  " x $I . "validate_syntax(" .
        (defined $grammar->{tag} ? $grammar->{tag} : "") . ")\n" if $D;
  my $file = $self->{gedcom}{record}{file};
  my $here = "$file:$self->{line}: $self->{tag}" .
             (defined $self->{xref} ? " $self->{xref}" : "");
  my %counts;
  for my $record (@{$self->_items})
  {
    print "  " x $I . "level $record->{level} on $self->{level}\n" if $D;
    $ok = 0, warn "$here: Can't add level $record->{level} to $self->{level}\n"
      if $record->{level} > $self->{level} + 1;
    $counts{$record->{tag}}++;
    $ok = 0 unless $record->validate_syntax;
  }
  my $valid_items = $grammar->valid_items;
  for my $tag (sort keys %$valid_items)
  {
    for my $g (@{$valid_items->{$tag}})
    {
      my $min = $g->{min};
      my $max = $g->{max};
      my $matches = delete $counts{$tag} || 0;
      my $msg = "$here has $matches $tag" . ($matches == 1 ? "" : "s");
      print "  " x $I . "$msg - min is $min max is $max\n" if $D;
      $ok = 0, warn "$msg - minimum is $min\n" if $matches < $min;
      $ok = 0, warn "$msg - maximum is $max\n" if $matches > $max && $max;
    }
  }
  for my $tag (keys %counts)
  {
    for my $c ($self->tag_record($tag))
    {
      $ok = 0, warn "$file:$c->{line}: $tag is not a sub-item of $self->{tag}\n"
        unless substr($tag, 0, 1) eq "_";
        # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
        # TODO - should CONT and CONC be allowed anywhere?
    }
  }
  $I--;
  $ok;
}

my $Check =
{
  INDI =>
  {
    FAMS => [ "HUSB", "WIFE" ],
    FAMC => [ "CHIL" ]
  },
  FAM =>
  {
    HUSB => [ "FAMS" ],
    WIFE => [ "FAMS" ],
    CHIL => [ "FAMC" ],
  },
};

sub validate_semantics
{
  my $self = shift;
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  # print "validating: "; $self->print; print $self->summary, "\n";
  my $ok = 1;
  my $xrefs = $self->{gedcom}{xrefs};
  my $chk = $Check->{$self->{tag}};
  for my $f (keys %$chk)
  {
    my $found = 1;
    RECORD:
    for my $record ($self->tag_value($f))
    {
      $found = 0;
      $record = $xrefs->{$record} unless ref $record;
      if ($record)
      {
        for my $back (@{$chk->{$f}})
        {
          # print "back $back\n";
          for my $i ($record->tag_value($back))
          {
            # print "record is $i\n";
            $i = $xrefs->{$i} unless ref $i;
            if ($i && $i->{xref} eq $self->{xref})
            {
              $found = 1;
              # print "found...\n";
              next RECORD;
            }
          }
        }
        unless ($found)
        {
          # TODO - use the line of the offending record
          $ok = 0;
          my $file = $self->{gedcom}{record}{file};
          warn "$file:$self->{line}: $f $record->{xref} " .
               "does not reference $self->{tag} $self->{xref}. Add the line:\n".
               "$file:" . ($record->{line} + 1) . ": 1   " .
               join("or ", @{$chk->{$f}}) .  " $self->{xref}\n";
        }
      }
    }
  }
  $ok;
}

sub normalise_dates
{
  my $self = shift;
  unless ($INC{"Date/Manip.pm"})
  {
    warn "Date::Manip.pm is required to use normalise_dates()";
    return;
  }
  if( eval { Date::Manip->VERSION( 6 ); } and !eval { Date::Manip->VERSION( 6.13 ); } ) {
    warn "Unable to normalize dates with this version of Date::Manip. Please upgrade to version 6.13.";
    return;
  }
  my $format = shift || "%A, %E %B %Y";
  if (defined $self->{tag} && $self->{tag} =~ /^date$/i)
  {
    if (defined $self->{value} && $self->{value})
    {
      # print "date was $self->{value}\n";
      my @dates = split / or /, $self->{value};
      for my $dt (@dates)
      {
        # don't change the date if it is just < 7 digits
        if ($dt !~ /^\s*(\d+)\s*$/ || length $1 > 6)
        {
          my $date = ParseDate($dt);
          my $d = UnixDate($date, $format);
          $dt = $d if $d;
        }
      }
      $self->{value} = join " or ", @dates;
      # print "date is  $self->{value}\n";
    }
  }
  $_->normalise_dates($format) for @{$self->_items};
  $self->delete_items if $self->level > 1;
}

sub renumber
{
  my $self = shift;
  my ($args, $recurse) = @_;
  # TODO - add the xref if there is supposed to be one
  return if exists $self->{recursed} or not defined $self->{xref};
  # we can't actually change the xrefs until the end
  my $x = $self->{tag} eq "SUBM" ? "SUBM" : substr $self->{tag}, 0, 1;
  $self->{new_xref} = $x . ++$args->{$self->{tag}}
    unless exists $self->{new_xref};
  return unless $recurse and not exists $self->{recursed};
  $self->{recursed} = 1;
  if ($self->{tag} eq "INDI")
  {
    my @r = map { $self->$_() } qw(fams famc spouse children parents siblings);
    $_->renumber($args, 0) for @r;
    $_->renumber($args, 1) for @r;
  }
}

sub child_value
{
  # NOTE - This function is deprecated - use tag_value instead
  my $self = shift;;
  $self->tag_value(@_)
}

sub child_values
{
  # NOTE - This function is deprecated - use tag_value instead
  my $self = shift;;
  $self->tag_value(@_)
}

sub compare
{
    my $self = shift;
    my ($r) = @_;
    Gedcom::Comparison->new($self, $r)
}

sub summary
{
  my $self = shift;
  my $s = "";
  $s .= sprintf("%-5s", $self->{xref});
  my $r = $self->tag_record("NAME");
  $s .= sprintf(" %-40s", $r ? $r->{value} : "");
  $r = $self->tag_record("SEX");
  $s .= sprintf(" %1s", $r ? $r->{value} : "");
  my $d = "";
  if ($r = $self->tag_record("BIRT") and my $date = $r->tag_record("DATE"))
  {
    $d = $date->{value};
  }
  $s .= sprintf(" %16s", $d);
  $s;
}

1;

__END__

#line 888
