#line 1 "Gedcom/Item.pm"
# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Item;

use Symbol;

use vars qw($VERSION);
$VERSION = "1.19";

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self =
  {
    level => -3,
    file  => "*",
    line  => 0,
    items => [],
    @_
  };
  bless $self, $class;
  $self->read if $self->{file} && $self->{file} ne "*";
  $self;
}

sub copy
{
  my $self = shift;
  my $item  = $self->new;
  for my $key (qw(level xref tag value pointer min max gedcom))
  {
    $item->{$key} = $self->{$key} if exists $self->{$key}
  }
  $item->{items} = [ map { $_->copy } @{$self->_items} ];
  $item
}

sub hash
{
  my $self = shift;
  my $item  = {};
  for my $key (qw(level xref tag value pointer min max))
  {
    $item->{$key} = $self->{$key} if exists $self->{$key}
  }
  $item->{items} = [ map { $_->hash } @{$self->_items} ];
  $item
}

sub read
{
  my $self = shift;

# $self->{fh} = FileHandle->new($self->{file})
  my $fh = $self->{fh} = gensym;
  open $fh, $self->{file} or die "Can't open file $self->{file}: $!\n";

  # try to determine encoding
  my $encoding = "unknown";
  my $bom = 0;
  my $line1 = <$fh>;
  if ($line1 =~ /^\xEF\xBB\xBF/)
  {
    $encoding = "utf-8";
    $bom = 1;
  }
  else
  {
    while (<$fh>)
    {
      if (my ($char) = /\s*1\s+CHAR\s+(.*?)\s*$/i)
      {
        $encoding = $char =~ /utf\W*8/i ? "utf-8" : $char;
        last;
      }
    }
  }

  # print "encoding is [$encoding]\n";
  $self->{gedcom}->set_encoding($encoding) if $self->{gedcom};
  if ($encoding eq "utf-8" && $] >= 5.8)
  {
    binmode $fh,    ":encoding(UTF-8)";
    binmode STDOUT, ":encoding(UTF-8)";
    binmode STDERR, ":encoding(UTF-8)";
  }
  else
  {
    binmode $fh;
  }

  # find out how big the file is
  seek($fh, 0, 2);
  my $size = tell $fh;
  seek($fh, $bom ? 3 : 0, 0);  # skip BOM

  # initial callback
  my $callback = $self->{callback};;
  my $title = "Reading";
  my $txt1 = "Reading $self->{file}";
  my $count = 0;
  return undef
    if $callback &&
       !$callback->($title, $txt1, "Record $count", tell $fh, $size);

  $self->level($self->{grammar} ? -1 : -2);

  my $if = "$self->{file}.index";
  my ($gf, $gc);
  if ($self->{gedcom}{read_only} &&
      defined ($gf = -M $self->{file}) && defined ($gc = -M $if) && $gc < $gf)
  {
    if (! open I, $if)
    {
      die "Can't open $if: $!";
    }
    else
    {
      my $g = $self->{gedcom}{grammar}->structure("GEDCOM");
      while (<I>)
      {
        my @vals = split /\|/;
        my $record =
          Gedcom::Record->new(gedcom  => $self->{gedcom},
                              tag     => $vals[0],
                              line    => $vals[3],
                              cpos    => $vals[4],
                              grammar => $g->item($vals[0]),
                              fh      => $fh,
                              level   => 0);
        $record->{xref}  = $vals[1] if length $vals[1];
        $record->{value} = $vals[2] if length $vals[2];
        my $class = $self->{gedcom}{types}{$vals[0]};
        bless $record, "Gedcom::$class" if $class;
        push @{$self->{items}}, $record;
      }
      close I or warn "Can't close $if";
    }
  }

  unless (@{$self->{items}})
  {
    # $#{$self->{items}} = 20000;
    # $#{$self->{items}} = -1;
    # If we have a grammar, then we are reading a gedcom file and must use
    # the grammar to verify what is being read.
    # If we do not have a grammar, then that is what we are reading.
    while (my $item = $self->next_item($self))
    {
      if ($self->{grammar})
      {
        my $tag = $item->{tag};
        my @g = $self->{grammar}->item($tag);
        # print "<$tag> => <@g>\n";
        if (@g)
        {
          $self->parse($item, $g[0]);
          push @{$self->{items}}, $item;
          $count++;
        }
        else
        {
          $tag = "<empty tag>" unless defined $tag && length $tag;
          warn "$self->{file}:$item->{line}: $tag is not a top level tag\n";
        }
      }
      else
      {
        # just add the grammar item
        push @{$self->{items}}, $item;
        $count++;
      }
      return undef
        if ref $item &&
           $callback &&
           !$callback->($title, $txt1, "Record $count line " . $item->{line},
                        tell $fh, $size);
    }
  }

# unless ($self->{gedcom}{read_only})
# {
#   $self->{fh}->close or die "Can't close file $self->{file}: $!";
#   delete $self->{fh};
# }

  if ($self->{gedcom}{read_only} && defined $gf && (! defined $gc || $gc > $gf))
  {
    if (! open I, ">$if")
    {
      warn "Can't open $if";
    }
    else
    {
      for my $item (@{$self->{items}})
      {
        print I join("|", map { $item->{$_} || "" }
                              qw(tag xref value line cpos));
        print I "\n";
      }
      close I or warn "Can't close $if";
    }
  }

  $self;
}

sub add_items
{
  my $self = shift;
  my ($item, $parse) = @_;
# print "adding items to: "; $item->print;
  if (!$parse &&
      $item->{level} >= 0 &&
      $self->{gedcom}{read_only} &&
      $self->{gedcom}{grammar})
  {
    # print "ignoring items\n";
    $self->skip_items($item);
  }
  else
  {
    if ($parse && $self->{gedcom}{read_only} && $self->{gedcom}{grammar})
    {
#     print "reading items\n";
      if (defined $item->{cpos})
      {
        seek($self->{fh}, $item->{cpos}, 0);
        $. = $item->{line};
      }
    }
    $item->{items} = [];
    while (my $next = $self->next_item($item))
    {
      unless (ref $next)
      {
        # The grammar requires a single selection from its items
        $item->{selection} = 1;
        next;
      }
      my $level = $item->{level};
      my $next_level = $next->{level};
      if (!defined $next_level || $next_level <= $level)
      {
        $self->{stored_item} = $next;
        # print "stored ***********************************\n";
        return;
      }
      else
      {
        warn "$self->{file}:$item->{line}: " .
             "Can't add level $next_level to $level\n"
          if $next_level > $level + 1;
        push @{$item->{items}}, $next;
      }
    }
    $item->{_items} = 1 unless $item->{gedcom}{read_only};
  }
}

sub skip_items
{
  my $self = shift;
  my ($item) = @_;
  my $level = $item->{level};
  my $cpos = $item->{cpos} = tell $self->{fh};
# print "skipping items to level $level at $item->{line}:$cpos\n";
  my $fh = $self->{fh};
  while (my $l = <$fh>)
  {
    chomp $l;
#   print "parsing <$l>\n";
    if (my ($lev) = $l =~ /^\s*(\d+)/)
    {
      if ($lev <= $level)
      {
#       print "pushing <$l>\n";
        seek($self->{fh}, $cpos, 0);
        $.--;
        last;
      }
    }
    $cpos = tell $self->{fh};
  }
}

sub next_item
{
  my $self   = shift;
  my ($item) = @_;
  my $bpos   = tell $self->{fh};
  my $bline  = $.;
  # print "At $bpos:$bline\n";
  my $rec;
  my $fh = $self->{fh};
  if ($rec = $self->{stored_item})
  {
    $self->{stored_item} = undef;
  }
  elsif ((!$rec || !$rec->{level}) && (my $line = $self->next_text_line))
  {
    # TODO - tidy this up
    my $line_number = $.;
    # print "line $line_number is <$line>";
    if (my ($structure) = $line =~ /^\s*(\w+): =\s*$/)
    {
      $rec = $self->new(level     => -1,
                        structure => $structure,
                        line      => $line_number);
#     print "found structure $structure\n";
    }
    elsif (my ($level, $xref, $tag, $value, $min, $max) =
      $line =~ /^\s*                       # optional whitespace at start
                ((?:\+?\d+)|n)             # start level
                \s*                        # optional whitespace
                (?:                        # xref
                  (@<?.*>?@)               # text in @<?>?@
                  \s+                      # whitespace
                )?                         # optional
                (?:                        # tag
                  (?!<<)                   # don't match a type
                  ([\w\s\[\]\|<>]+?)       # non greedy
                  \s+                      # whitespace
                )?                         # optional
                (?:                        # value
                  (                        #
                    (?:                    # one of
                      @?<?.*?\s*>?@?       # text element - non greedy
                      |                    # or
                      \[\s*                # start list
                      (?:                  #
                        @?<.*>@?           # text element
                        \s*\|?\s*          # optionally delimited
                      )+                   # one or more
                      \]                   # end list
                    )                      #
                  )                        #
                  \s+                      # whitespace
                )??                        # optional - non greedy
                (?:                        # value
                  \{                       # open brace
                    (\d+)                  # min
                    :                      # :
                    (\d+|M)                # max
                    \*?                    # optional *
                  [\}\]]                   # close brace or bracket
                )?                         # optional
                \*?                        # optional *
                \s*$/x)                    # optional whitespace at end
#     $line =~ /^\s*                       # optional whitespace at start
#               (\d+)                      # start level
#               \s*                        # optional whitespace
#               (?:                        # xref
#                 (@.*@)                   # text in @@
#                 \s+                      # whitespace
#               )?                         # optional
#               (\w+)                      # tag
#               \s*                        # whitespace
#               (?:                        # value
#                 (@?.*?@?)                # text element - non greedy
#                 \s+                      # whitespace
#               )??                        # optional - non greedy
#               \s*$/x)                    # optional whitespace at end
    {
      # print "found $level below $item->{level}\n";
      if ($level eq "n" || $level > $item->{level})
      {
        unless ($rec)
        {
          $rec = $self->new(line => $line_number);
          $rec->{gedcom} = $self->{gedcom} if $self->{gedcom}{grammar};
        }
        $rec->{level} = ($level eq "n" ? 0 : $level) if defined $level;
        $rec->{xref}  = $xref  =~ /^\@(.+)\@$/ ? $1 : $xref
          if defined $xref;
        $rec->{tag}   = $tag                         if defined $tag;
        $rec->{value} = ($rec->{pointer} = $value =~ /^\@(.+)\@$/) ? $1 : $value
          if defined $value;
        $rec->{min}   = $min                         if defined $min;
        $rec->{max}   = $max                         if defined $max;
      }
      else
      {
        # print " -- pushing back\n";
        seek($fh, $bpos, 0);
        $. = $bline;
      }
    }
    elsif ($line =~ /^\s*[\[\|\]]\s*(?:\/\*.*\*\/\s*)?$/)
    {
      # The grammar requires a single selection from its items.
      return "selection";
    }
    else
    {
      chomp $line;
      my $file = $self->{file};
      die "\n$file:$line_number: Can't parse line: $line\n";
    }
  }

# print "\ncomparing "; $item->print;
# print "with      "; $rec->print if $rec;
  $self->add_items($rec)
    if $rec && defined $rec->{level} && ($rec->{level} > $item->{level});
  $rec;
}

sub next_line
{
  my $self = shift;
  my $fh = $self->{fh};
  my $line = <$fh>;
  $line;
}

sub next_text_line
{
  my $self = shift;
  my $line = "";
  my $fh = $self->{fh};
  $line = <$fh> until !defined $line || $line =~ /\S/;
  $line;
}

sub write
{
  my $self = shift;
  my ($fh, $level, $flush) = @_;
  $level ||= 0;
  my @p;
  push(@p, $level . "  " x $level)         unless $flush || $level < 0;
  push(@p, "\@$self->{xref}\@")            if     defined $self->{xref} &&
                                                  length $self->{xref};
  push(@p, $self->{tag})                   if     $level >= 0;
  push(@p, ref $self->{value}
           ? "\@$self->{value}{xref}\@"
           : $self->resolve_xref($self->{value})
             ? "\@$self->{value}\@"
             : $self->{value})             if     defined $self->{value} &&
                                                  length $self->{value};
  $fh->print("@p");
  $fh->print("\n")                         unless $level < 0;
  for my $c (0 .. @{$self->_items} - 1)
  {
    $self->{items}[$c]->write($fh, $level + 1, $flush);
    $fh->print("\n")                       if     $level < 0 &&
                                                  $c < @{$self->{items}} - 1;
  }
}

sub write_xml
{
  my $self = shift;
  my ($fh, $level) = @_;

  return if $self->{tag} && $self->{tag} =~ /^(CON[CT]|TRLR)$/;

  my $spaced = 0;
  my $events = 0;

  $level = 0 unless $level;
  my $indent = "  " x $level;

  my $tag = $level >= 0 && $self->{tag};

  my $value = $self->{value}
              ? ref $self->{value}
                ? $self->{value}{xref}
                : $self->full_value
              : undef;
  $value =~ s/\s+$// if defined $value;

  my $sub_items = @{$self->_items};

  my $p = "";
  if ($tag)
  {
    $tag = $events &&
           defined $self->{gedcom}{types}{$self->{tag}} &&
                   $self->{gedcom}{types}{$self->{tag}} eq "Event"
      ? "EVEN"
      : $self->{tag};

    $tag = "GED" if $tag eq "GEDCOM";

    $p .= $indent;
    $p .= "<$tag";

    if ($tag eq "EVEN")
    {
      $p .= qq( EV="$self->{tag}");
    }
    elsif ($tag =~ /^(FAM[SC]|HUSB|WIFE|CHIL|SUBM|NOTE)$/ &&
           defined $value &&
           $self->resolve_xref($self->{value}))
    {
      $p .= qq( REF="$value");
      $value = undef;
      $tag = undef unless $sub_items;
    }
    elsif ($self->{xref})
    {
      $p .= qq( ID="$self->{xref}");
    }

    $p .= "/" unless defined $value || $tag;
    $p .= ">";
    $p .= "\n"
      if $sub_items ||
         (!$spaced &&
          (!(defined $value || $tag) || $tag eq "EVEN" || $self->{xref}));
  }

  if (defined $value)
  {
    $p .= "$indent  " if $spaced || $sub_items;
    $p .= $value;
    $p .= "\n"        if $spaced || $sub_items;
  }

  $fh->print($p);

  for my $c (0 .. $sub_items - 1)
  {
    $self->{items}[$c]->write_xml($fh, $level + 1);
  }

  if ($tag)
  {
    $fh->print($indent) if $spaced || $sub_items;
    $fh->print("</$tag>\n");
  }
}

sub print
{
  my $self = shift;
  for my $v (qw( level xref tag value min max ))
  {
    print($v, ": ", $self->{$v}, " ") if defined $self->{$v};
  }
  print "\n";
}

sub get_item
{
  my $self = shift;
  my ($tag, $count) = @_;
  if (wantarray && !$count)
  {
    return grep { $_->{tag} eq $tag } @{$self->_items};
  }
  else
  {
    $count = 1 unless $count;
    for my $c (@{$self->_items})
    {
      return $c if $c->{tag} eq $tag && !--$count;
    }
  }
  undef
}

sub get_child
{
  # NOTE - This function is deprecated - use get_item instead
  my $self = shift;
  my ($t) = @_;
  my ($tag, $count) = $t =~ /^_?(\w+?)(\d*)$/;
  $self->get_item($tag, $count);
}

sub get_children
{
  # NOTE - This function is deprecated - use get_item instead
  my $self = shift;
  $self->get_item(@_)
}

sub parent
{
  my $self = shift;

  my $i = "$self";
  my @records = ($self->{gedcom}{record});

  while (@records)
  {
    my $r = shift @records;
    for (@{$r->_items})
    {
      return $r if $i eq "$_";
      push @records, $r;
    }
  }

  undef
}

sub delete
{
  my $self = shift;

  my $parent = $self->parent;

  return unless $parent;

  $parent->delete_item($self);
}

sub delete_item
{
  my $self = shift;
  my ($item) = @_;

  my $i = "$item";
  my $n = 0;
  for (@{$self->_items})
  {
    last if $i eq "$_";
    $n++;
  }

  return 0 unless $n < @{$self->{items}};

  # print "deleting item $n of $#{$self->{items}}\n";
  splice @{$self->{items}}, $n, 1;
  delete $self->{gedcom}{xrefs}{$item->{xref}} if defined $item->{xref};

  1
}

for my $func (qw(level xref tag value pointer min max gedcom file line))
{
  no strict "refs";
  *$func = sub
  {
    my $self = shift;
    $self->{$func} = shift if @_;
    $self->{$func}
  }
}

sub full_value
{
  my $self = shift;
  my $value = $self->{value};
  $value =~ s/[\r\n]+$// if defined $value;
  for my $item (@{$self->_items})
  {
    my $v = defined $item->{value} ? $item->{value} : "";
    $v =~ s/[\r\n]+$//;
    $value .= "\n$v" if $item->{tag} eq "CONT";
    $value .=    $v  if $item->{tag} eq "CONC";
  }
  $value
}

sub _items
{
  my $self = shift;
  $self->{gedcom}{record}->add_items($self, 1)
    if !defined $self->{_items} && $self->{level} >= 0;
  $self->{_items} = 1;
  $self->{items}
}

sub items
{
  my $self = shift;
  @{$self->_items}
}

sub delete_items
{
  my $self = shift;
  delete $self->{_items};
  delete $self->{items};
}

1;

__END__

#line 1009
