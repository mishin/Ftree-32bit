#line 1 "Log/Agent/Priorities.pm"
###########################################################################
#
#   Priorities.pm
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
package Log::Agent::Priorities;

require Exporter;
use AutoLoader 'AUTOLOAD';
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @LEVELS);
@ISA = qw(Exporter);

@LEVELS = qw(NONE EMERG ALERT CRIT ERROR WARN NOTICE INFO DEBUG);

@EXPORT = qw(priority_level);
@EXPORT_OK = qw(prio_from_level level_from_prio);
push(@EXPORT_OK, @LEVELS);

%EXPORT_TAGS = (LEVELS => \@LEVELS);

BEGIN {
	sub NONE ()		{-1}
	sub EMERG ()	 {0}
	sub ALERT ()	 {1}
	sub CRIT ()		 {2}
	sub ERROR ()	 {3}
	sub WARN ()		 {4}
	sub NOTICE ()	 {6}
	sub INFO ()		 {8}
	sub DEBUG ()	{10}
}

use vars qw(@basic_prio %basic_level);

@basic_prio = qw(
	emergency
	alert
	critical
	error
	warning warning
	notice notice
	info info);

%basic_level = (
	'em'	=> EMERG,		# emergency
	'al'	=> ALERT,		# alert
	'cr'	=> CRIT,		# critical
	'er'	=> ERROR,		# error
	'wa'	=> WARN,		# warning
	'no'	=> NOTICE,		# notice
	'in'	=> INFO,		# info
	'de'	=> DEBUG,		# debug
);

1;
__END__

#
# prio_from_level
#
# Given a level, compute suitable priority.
#
sub prio_from_level {
	my ($level) = @_;
	return 'none' if $level < 0;
	return 'debug' if $level >= @basic_prio;
	return $basic_prio[$level];
}

#
# level_from_prio
#
# Given a syslog priority, compute suitable level.
#
sub level_from_prio {
	my ($prio) = @_;
	return -1 if lc($prio) eq 'none';		# none & notice would look alike
	my $canonical = lc(substr($prio, 0, 2));
	return 10 unless exists $basic_level{$canonical};
	return $basic_level{$canonical} || -1;
}

#
# priority_level
#
# Decompiles priority which can be either a single digit, a "priority" string
# or a "priority:digit" string. Returns the priority (computed if none) and
# the level (computed if none).
#
sub priority_level {
	my ($id) = @_;
	return (prio_from_level($id), $id) if $id =~ /^\d+$/;
	return ($1, $2) if $id =~ /^([^:]+):(\d+)$/;
	return ($id, level_from_prio($id));
}

#line 174

