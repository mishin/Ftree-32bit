#line 1 "Gedcom/Grammar.pm"
# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Grammar;

use Data::Dumper;

use Gedcom::Item 1.19;

use vars qw($VERSION @ISA);
$VERSION = "1.19";
@ISA     = qw( Gedcom::Item );

sub structure
{
  my $self = shift;
  my ($struct) = @_;
  unless (exists $self->{top}{structures})
  {
    $self->{top}{structures} =
      { map { $_->{structure} ? ($_->{structure} => $_) : () }
            @{$self->{top}{items}} };
  }
  # print Dumper $self->{top}{structures};
  $self->{top}{structures}{$struct}
}

sub item
{
  my $self = shift;
  my ($tag) = @_;
  return unless defined $tag;
  my $valid_items = $self->valid_items;
  # use Data::Dumper; print "[$tag] -- ", Dumper($self), Dumper $valid_items;
  return unless exists $valid_items->{$tag};
  map { $_->{grammar} } @{$valid_items->{$tag}}
}

sub min
{
  my $self = shift;
  exists $self->{min} ? $self->{min} : 1
}

sub max
{
  my $self = shift;
  exists $self->{max} ? $self->{max} eq "M" ? 0 : $self->{max} : 1
}

sub items
{
  my $self = shift;
  keys %{$self->valid_items}
}

sub _valid_items
{
  my $self = shift;
  my %valid_items;
  for my $item (@{$self->{items}})
  {
    my $min = $item->min;
    my $max = $item->max;
    if ($item->{tag})
    {
      push @{$valid_items{$item->{tag}}},
      {
        grammar => $item,
        min     => $min,
        max     => $max
      };
    }
    else
    {
      die "What's a " . Data::Dumper->new([$item], ["grammar"])
        unless my ($value) = $item->{value} =~ /<<(.*)>>/;
      die "Can't find $value in gedcom structures"
        unless my $structure = $self->structure($value);
      $item->{structure} = $structure;
      while (my($tag, $g) = each %{$structure->valid_items})
      {
        push @{$valid_items{$tag}},
        map {
              grammar => $_->{grammar},
              # min and max can be calculated by multiplication because
              # the grammar always permits multiple selection records, and
              # selection records never have compulsory records.  This may
              # change in future grammars, but I would not expect it to -
              # such a grammar would seem to have little practical use.
              min     => $_->{min} * $min,
              max     => $_->{max} * $max
            }, @$g;
      }
      if (exists $item->{items} && @{$item->{items}})
      {
        my $extra_items = $item->_valid_items;
        while (my ($sub_item, $sub_grammars) = each %valid_items)
        {
          for my $sub_grammar (@$sub_grammars)
          {
              $sub_grammar->{grammar}->valid_items;
              while (my ($i, $g) = each %$extra_items)
              {
                # print "adding $i to $sub_item\n";
                $sub_grammar->{grammar}{_valid_items}{$i} = $g;
              }
          }
          # print "giving @{[keys %{$sub_grammar->{grammar}->valid_items}]}\n";
        }
      }
    }
  }
  # print "valid items are @{[keys %valid_items]}\n";
  \%valid_items
}

sub valid_items
{
  my $self = shift;
  $self->{_valid_items} ||= $self->_valid_items
}

1;

__END__

#line 220
