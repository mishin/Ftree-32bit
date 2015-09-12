#line 1 "Authen/SASL/Perl/EXTERNAL.pm"
# Copyright (c) 1998-2002 Graham Barr <gbarr@pobox.com> and 2001 Chris Ridd
# <chris.ridd@isode.com>.  All rights reserved.  This program
# is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.

package Authen::SASL::Perl::EXTERNAL;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "2.14";
@ISA	 = qw(Authen::SASL::Perl);

my %secflags = (
	noplaintext  => 1,
	nodictionary => 1,
	noanonymous  => 1,
);

sub _order { 2 }
sub _secflags {
  shift;
  grep { $secflags{$_} } @_;
}

sub mechanism { 'EXTERNAL' }

sub client_start {
  my $self = shift;
  my $v = $self->_call('user');
  defined($v) ? $v : ''
}

#sub client_step {
#  shift->_call('user');
#}

1;

__END__

#line 98
