#line 1 "Log/Agent/Tag/String.pm"
###########################################################################
#
#   String.pm
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
package Log::Agent::Tag::String;

require Log::Agent::Tag;
use vars qw(@ISA);
@ISA = qw(Log::Agent::Tag);

#
# ->make
#
# Creation routine.
#
# Calling arguments: a hash table list.
#
# The keyed argument list may contain:
#	-POSTFIX	whether to postfix log message or prefix it.
#   -SEPARATOR  separator string to use between tag and message
#   -NAME       tag's name (optional)
#   -VALUE      string value to use
#
# Attributes:
#   string      the string value
#
sub make {
	my $self = bless {}, shift;
	my (%args) = @_;
	my ($name, $postfix, $separator, $value);

	my %set = (
		-name		=> \$name,
		-value		=> \$value,
		-postfix	=> \$postfix,
		-separator	=> \$separator,
	);

	while (my ($arg, $val) = each %args) {
		my $vset = $set{lc($arg)};
		next unless ref $vset;
		$$vset = $val;
	}

	$self->_init($name, $postfix, $separator);
	$self->{string} = $value;

	return $self;
}

#
# Defined routines
#

sub string		{ $_[0]->{'string'} }

1;			# for "require"
__END__

#line 127

