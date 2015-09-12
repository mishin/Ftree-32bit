#line 1 "Gedcom/Family.pm"
# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Family;

use Gedcom::Record 1.19;

use vars qw($VERSION @ISA);
$VERSION = "1.19";
@ISA     = qw( Gedcom::Record );

sub husband
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("HUSB"));
  wantarray ? @a : $a[0]
}

sub wife
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("WIFE"));
  wantarray ? @a : $a[0]
}

sub parents
{
  my $self = shift;
  ($self->husband, $self->wife)
}

sub number_of_children
{
  my ($self) = @_;
  my $nchi = $self->tag_value("NCHI");
  defined $nchi ? $nchi : ($#{[$self->children]} + 1)
}

sub children
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("CHIL"));
  wantarray ? @a : $a[0]
}

sub boys
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->children;
  wantarray ? @a : $a[0]
}

sub girls
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->children;
  wantarray ? @a : $a[0]
}

sub add_husband
{
  my $self = shift;
  my ($husband) = @_;
  $husband = $self->{gedcom}->get_individual($husband)
    unless UNIVERSAL::isa($husband, "Gedcom::Individual");
  $self->add("husband", $husband);
  $husband->add("fams", $self->{xref});
}

sub add_wife
{
  my $self = shift;
  my ($wife) = @_;
  $wife = $self->{gedcom}->get_individual($wife)
    unless UNIVERSAL::isa($wife, "Gedcom::Individual");
  $self->add("wife", $wife);
  $wife->add("fams", $self->{xref});
}

sub add_child
{
  my $self = shift;
  my ($child) = @_;
  $child = $self->{gedcom}->get_individual($child)
    unless UNIVERSAL::isa($child, "Gedcom::Individual");
  $self->add("child", $child);
  $child->add("famc", $self->{xref});
}

sub print
{
  my $self = shift;
  $self->_items if shift;
  $self->SUPER::print; $_->print for @{$self->{items}};
}

1;

__END__

#line 180
