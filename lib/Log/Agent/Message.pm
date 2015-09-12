#line 1 "Log/Agent/Message.pm"
###########################################################################
#
#   Message.pm
#
#   Copyright (C) 1999 Raphael Manfredi.
#   Copyright (C) 2002-2003, 2005, 2013 Mark Rogaski, mrogaski@cpan.org;
#   all rights reserved.
#
#   See the README file included with the
#   distribution for license information.
#
##########################################################################

use strict;

########################################################################
package Log::Agent::Message;

use overload
	qw("" stringify);

#
# ->make
#
# Creation routine.
#
# Attributes:
#	str				formatted message string coming from user
#	prepend_list	list of strings to prepend to `str'
#	append_list		list of strings to append to `str'
#
sub make {
	my $self = bless [], shift;		# Array for minimal overhead
	$self->[0] = $_[0];
	return $self;
}

#
# Attribute access
#

sub str				{ $_[0]->[0] }
sub prepend_list	{ $_[0]->[1] }
sub append_list		{ $_[0]->[2] }

#
# Attribute setting
#

sub set_str				{ $_[0]->[0] = $_[1] }
sub set_prepend_list	{ $_[0]->[1] = $_[1] }
sub set_append_list		{ $_[0]->[2] = $_[1] }

#
# ->prepend
#
# Add string to the prepend list, at its TAIL.
# (i.e. the first to prepend gets output first)
#
sub prepend {
	my $self = shift;
	my ($str) = @_;

	my $array = $self->prepend_list;
	$array = $self->set_prepend_list([]) unless $array;

	push(@{$array}, $str);
}

#
# ->prepend_first
#
# Add string to the prepend list, at its HEAD.
#
sub prepend_first {
	my $self = shift;
	my ($str) = @_;

	my $array = $self->prepend_list;
	$array = $self->set_prepend_list([]) unless $array;

	unshift(@{$array}, $str);
}

#
# ->append
#
# Add string to the append list, at its HEAD.
# (i.e. the first to append gets output last)
#
sub append {
	my $self = shift;
	my ($str) = @_;

	my $array = $self->append_list;
	$array = $self->set_append_list([]) unless $array;

	unshift(@{$array}, $str);
}

#
# ->append_last
#
# Add string to the append list, at its TAIL.
#
sub append_last {
	my $self = shift;
	my ($str) = @_;

	my $array = $self->append_list;
	$array = $self->set_append_list([]) unless $array;

	push(@{$array}, $str);
}

#
# ->stringify
# (stringify)
#
# Returns complete string, with all prepended strings first, then the
# original string followed by all the appended strings.
#
sub stringify {
	my $self = shift;
	return $self->[0] if @{$self} == 1;		# Optimize usual case

	my $prepend = $self->prepend_list;
	my $append = $self->append_list;

	return
		($prepend ? join('', @{$prepend}) : '') .
		$self->str .
		($append ? join('', @{$append}) : '');
}

#
# ->clone
#
# Clone object
# (not a deep clone, but prepend and append lists are also shallow-cloned.)
#
sub clone {
	my $self = shift;
	my $other = bless [], ref $self;
	$other->[0] = $self->[0];
	return $other if @{$self} == 1;			# Optimize usual case

	if (defined $self->[1]) {
		my @array = @{$self->[1]};
		$other->[1] = \@array;
	}
	if (defined $self->[2]) {
		my @array = @{$self->[2]};
		$other->[2] = \@array;
	}

	return $other;
}

1;	# for require
__END__

#line 247
