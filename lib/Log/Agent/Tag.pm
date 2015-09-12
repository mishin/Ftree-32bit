#line 1 "Log/Agent/Tag.pm"
###########################################################################
#
#   Tag.pm
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
package Log::Agent::Tag;

#
# ->make
#
# Creation routine.
#
sub make {
	my $self = bless {}, shift;
	require Carp;
	Carp::confess("deferred");
}

#
# Attribute access
#

sub postfix		{ $_[0]->{'postfix'} }
sub name		{ $_[0]->{'name'} }
sub separator	{ $_[0]->{'separator'} }

#
# ->_init
#
# Initialization routine for common attributes:
#
#   postfix            if true, appends tag to message, otherwise prepends
#   name               the tag name
#   separator          the string to use before or after tag (defaults to " ")
#
# Called by each creation routine in heirs.
#
sub _init {
	my $self = shift;
	my ($name, $postfix, $separator) = @_;
	$separator = " " unless defined $separator;
	$self->{name}      = $name;
	$self->{postfix}   = $postfix;
	$self->{separator} = $separator;
	return;
}

#
# ->string			-- deferred
#
# Build tag string.
# Must be implemented by heirs.
#
sub string {
	require Carp;
	Carp::confess("deferred");
}

#
# ->insert			-- frozen
#
# Merge string into the log message, according to our configuration.
#
sub insert {
	my $self = shift;
	my ($str) = @_;			# A Log::Agent::Message object

	my $string = $self->string;
	my $separator = $self->separator;

	#
	# Merge into the Log::Agent::Message object string.
	#

	if ($self->postfix) {
		$str->append($separator . $string);
	} else {
		$str->prepend($string . $separator);
	}

	return;
}

1;			# for "require"
__END__

#line 220

