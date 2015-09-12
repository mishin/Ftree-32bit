#line 1 "Gedcom/Individual.pm"
# Copyright 1999-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Individual;

use Gedcom::Record 1.19;

use vars qw($VERSION @ISA);
$VERSION = "1.19";
@ISA     = qw( Gedcom::Record );

sub name
{
  my $self = shift;
  my $name = $self->tag_value("NAME");
  return "" unless defined $name;
  $name =~ s/\s+/ /g;
  $name =~ s| ?/ ?(.*?) ?/ ?| /$1/ |;
  $name =~ s/^\s+//g;
  $name =~ s/\s+$//g;
  $name
}

sub cased_name
{
  my $self = shift;
  my $name = $self->name;
  $name =~ s|/([^/]*)/?|uc $1|e;
  $name
}

sub surname
{
  my $self = shift;
  my ($surname) = $self->name =~ m|/([^/]*)/?|;
  $surname || ""
}

sub given_names
{
  my $self = shift;
  my $name = $self->name;
  $name =~ s|/([^/]*)/?| |;
  $name =~ s|^\s+||;
  $name =~ s|\s+$||;
  $name =~ s|\s+| |g;
  $name
}

sub soundex
{
  my $self = shift;
  unless ($INC{"Text/Soundex.pm"})
  {
    warn "Text::Soundex.pm is required to use soundex()";
    return undef
  }
  Gedcom::soundex($self->surname)
}

sub sex
{
  my $self = shift;
  my $sex = $self->tag_value("SEX");
  if(defined $sex){
    $sex =~ /^F/i ? "F" : $sex =~ /^M/i ? "M" : "U";
  }else{
    "U";
  }
}

sub father
{
  my $self = shift;
  my @a = map { $_->husband } $self->famc;
  wantarray ? @a : $a[0]
}

sub mother
{
  my $self = shift;
  my @a = map { $_->wife } $self->famc;
  wantarray ? @a : $a[0]
}

sub parents
{
  my $self = shift;
  ($self->father, $self->mother)
}

sub husband
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->husband } $self->fams;
  wantarray ? @a : $a[0]
}

sub wife
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->wife } $self->fams;
  wantarray ? @a : $a[0]
}

sub spouse
{
  my $self = shift;
  my @a = ($self->husband, $self->wife);
  wantarray ? @a : $a[0]
}

sub siblings
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->children } $self->famc;
  wantarray ? @a : $a[0]
}

sub half_siblings
{
  my $self = shift;
  my @all_siblings_multiple = map { $_->children } ( map { $_->fams } $self->parents );
  my @excludelist = ($self, $self->siblings);
  my @a = grep {
      my $cur = $_;
      my $half_sibling=1;
      foreach my $test(@excludelist){
        if($cur->{xref} eq $test->{xref} ){
          $half_sibling=0;
          last;
        }
      }
      push @excludelist, $cur if($half_sibling); # in order to avoid multiple output
      $half_sibling;
    } @all_siblings_multiple;
  wantarray ? @a : $a[0]
}

sub older_siblings
{
  my $self = shift;
  my @a = map { $_->children } $self->famc;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $self->{xref}
  }
  splice @a, $i;
  wantarray ? @a : $a[-1]
}

sub younger_siblings
{
  my $self = shift;
  my @a = map { $_->children } $self->famc;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $self->{xref}
  }
  splice @a, 0, $i + 1;
  wantarray ? @a : $a[0]
}

sub brothers
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->siblings;
  wantarray ? @a : $a[0]
}

sub half_brothers
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->half_siblings;
  wantarray ? @a : $a[0]
}

sub sisters
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->siblings;
  wantarray ? @a : $a[0]
}

sub half_sisters
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->half_siblings;
  wantarray ? @a : $a[0]
}

sub children
{
  my $self = shift;
  my @a = map { $_->children } $self->fams;
  wantarray ? @a : $a[0]
}

sub sons
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->children;
  wantarray ? @a : $a[0]
}

sub daughters
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->children;
  wantarray ? @a : $a[0]
}

sub descendents
{
  my $self = shift;
  my @d;
  my @c = $self->children;
  while (@c)
  {
    push @d, @c;
    @c = map { $_->children } @c;
  }
  @d
}

sub ancestors
{
  my $self = shift;
  my @d;
  my @c = $self->parents;
  while (@c)
  {
    push @d, @c;
    @c = map { $_->parents } @c;
  }
  @d
}

sub delete
{
  my $self = shift;
  my $xref = $self->{xref};
  my $ret = 1;
  for my $f ( [ "(HUSB|WIFE)", [$self->fams] ], [ "CHIL", [$self->famc] ] )
  {
    for my $fam (@{$f->[1]})
    {
      # print "deleting from $fam->{xref}\n";
      for my $record (@{$fam->_items})
      {
        # print "looking at $record->{tag} $record->{value}\n";
        if (($record->{tag} =~ /$f->[0]/) &&
            $self->resolve($record->{value})->{xref} eq $xref)
        {
          $ret = 0 unless $fam->delete_record($record);
        }
      }
      $self->{gedcom}{record}->delete_record($fam)
        unless $fam->tag_value("HUSB") ||
               $fam->tag_value("WIFE") ||
               $fam->tag_value("CHIL");
      # TODO - write Family::delete ?
      #      - delete associated notes?
    }
  }
  $ret = 0 unless $self->{gedcom}{record}->delete_record($self);
  $_[0] = undef if $ret;                          # Can't reuse a deleted person
  $ret
}

sub print
{
  my $self = shift;
  $self->_items if shift;
  $self->SUPER::print; $_->print for @{$self->{items}};
# print "fams:\n"; $_->print for $self->fams;
# print "famc:\n"; $_->print for $self->famc;
}

sub print_generations
{
  my $self = shift;
  my ($generations, $indent) = @_;
  $generations = 0 unless $generations;
  $indent      = 0 unless $indent;
  return unless $generations > 0;
  my $i = "  " x $indent;
  print "$i$self->{xref} (", $self->rin, ") ", $self->name, "\n" unless $indent;
  $self->print;
  for my $fam ($self->fams)
  {
    # $fam->print;
    for my $spouse ($fam->parents)
    {
      next unless $spouse;
      # print "[$spouse]\n";
      next if $self->xref eq $spouse->xref;
      print "$i= $spouse->{xref} (", $spouse->rin, ") ", $spouse->name, "\n";
    }
    for my $child ($fam->children)
    {
      print "$i> $child->{xref} (", $child->rin, ") ", $child->name, "\n";
      $child->print_generations($generations - 1, $indent + 1);
    }
  }
}

sub famc
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("FAMC"));
  wantarray ? @a : $a[0]
}

sub fams
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("FAMS"));
  wantarray ? @a : $a[0]
}

1;

__END__

#line 480