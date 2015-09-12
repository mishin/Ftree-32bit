#line 1 "Log/Agent/Tag/Priority.pm"
###########################################################################
#
#   Priority.pm
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
package Log::Agent::Tag::Priority;

require Log::Agent::Tag::String;
use vars qw(@ISA);
@ISA = qw(Log::Agent::Tag::String);

use Log::Agent::Priorities qw(level_from_prio prio_from_level);

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
#   -DISPLAY    a string like '[$priority:$level])'
#   -PRIORITY   the log priority string, e.g. "warning".
#   -LEVEL      the log level value, e.g. 4.
#
# Attributes:
#   none, besides the inherited ones
#
sub make {
	my $type = shift;
	my (%args) = @_;
	my $separator = " ";
	my $postfix = 0;
	my ($display, $priority, $level);

	my %set = (
		-display	=> \$display,
		-postfix	=> \$postfix,
		-separator	=> \$separator,
		-priority	=> \$priority,
		-level		=> \$level,
	);

	while (my ($arg, $val) = each %args) {
		my $vset = $set{lc($arg)};
		next unless ref $vset;
		$$vset = $val;
	}

	#
	# Normalize $priority to the full name (e.g. "err" -> "error")
	#

	$priority = prio_from_level level_from_prio $priority;

	#
	# Format according to -display specs.
	#
	# Since priority and level are fixed for this object, the resulting
	# string need only be computed once, i.e. now.
	#
	# The following variables are recognized:
	#
	#		$priority	 			priority name (e.g. "warning")
	#		$level					logging level
	#
	# We recognize both $level and ${level}.
	#

	$display =~ s/\$priority\b/$priority/g;
	$display =~ s/\${priority}/$priority/g;
	$display =~ s/\$level\b/$level/g;
	$display =~ s/\${level}/$level/g;

	#
	# Now create the constant tag string.
	#

	my $self = Log::Agent::Tag::String->make(
		-name		=> "priority",
		-value		=> $display,
		-postfix	=> $postfix,
		-separator	=> $separator,
	);

	return bless $self, $type;		# re-blessed in our package
}

1;			# for "require"
__END__

#line 185

