#line 1 "Log/Agent.pm"
###########################################################################
#
#   Agent.pm
#
#   Copyright (C) 1999 Raphael Manfredi.
#   Copyright (C) 2002-2003, 2005, 2013 Mark Rogaski, mrogaski@cpan.org;
#   all rights reserved.
#
#   See the README file included with the
#   distribution for license information.
#
###########################################################################

use strict;
require Exporter;

########################################################################
package Log::Agent;

use vars qw($Driver $Prefix $Trace $Debug $Confess
	$OS_Error $AUTOLOAD $Caller $Priorities $Tags $DATUM %prio_cache);

use AutoLoader;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(
	logconfig
	logconfess logcroak logcarp logxcroak logxcarp
	logsay logerr logwarn logdie logtrc logdbg
);
@EXPORT_OK = qw(
	logwrite logtags
);

use Log::Agent::Priorities qw(:LEVELS priority_level level_from_prio);
use Log::Agent::Formatting qw(tag_format_args);

our $VERSION = '1.000';
$VERSION = eval $VERSION;

$Trace = NOTICE;	# Default tracing
$OS_Error = '';         # Data stash for the $! value

sub AUTOLOAD {
    ${Log::Agent::OS_Error} = $!;       # for safe-keeping, the braces
                                        # prevent CVS substitution
    $AutoLoader::AUTOLOAD = $AUTOLOAD;
    goto &AutoLoader::AUTOLOAD;
}

1;
__END__

#
# logconfig
#
# Configure the logging system at the application level. By default, logging
# uses the Log::Agent::Driver::Default driver.
#
# Available options (case insensitive):
#
#   -PREFIX   => string           logging prefix/tag to use, for Default agent
#   -DRIVER   => object           object heir of Log::Agent::Driver
#   -TRACE    => level            trace level
#   -DEBUG    => level            debug level
#   -LEVEL    => level            specifies common trace/debug level
#   -CONFESS  => flag             whether to automatically confess on logdie
#   -CALLER   => listref          info from caller to add and where
#   -PRIORITY => listref          message priority information to add
#   -TAGS     => listref          list of user-defined tags to add
#
# Notes:
#   -CALLER   allowed keys documented in Log::Agent::Tag::Caller's make()
#   -PRIORITY allowed keys documented in Log::Agent::Tag::Priority's make()
#   -TAGS     supplies list of Log::Agent::Tag objects
#
sub logconfig {
	my (%args) = @_;
	my ($calldef, $priodef, $tags);

	my %set = (
		-prefix			=> \$Prefix,		# Only for Default init
		-driver			=> \$Driver,
		-trace			=> \$Trace,
		-debug			=> \$Debug,
		-level			=> [\$Trace, \$Debug],
		-confess		=> \$Confess,
		-caller			=> \$calldef,
		-priority		=> \$priodef,
		-tags			=> \$tags,
	);

	while (my ($arg, $val) = each %args) {
		my $vset = $set{lc($arg)};
		unless (ref $vset) {
			require Carp;
			Carp::croak("Unknown switch $arg");
		}
		if		(ref $vset eq 'SCALAR')		{ $$vset = $val }
		elsif	(ref $vset eq 'ARRAY')		{ map { $$_ = $val } @$vset }
		elsif	(ref $vset eq 'REF')		{ $$vset = $val }
		else								{ die "bug in logconfig" }
	}

	unless (defined $Driver) {
		require Log::Agent::Driver::Default;
		# Keep only basename for default prefix
		$Prefix =~ s|^.*/(.*)|$1| if defined $Prefix;
		$Driver = Log::Agent::Driver::Default->make($Prefix);
	}

	$Prefix = $Driver->prefix;
	$Trace = level_from_prio($Trace) if defined $Trace && $Trace =~ /^\D+/;
	$Debug = level_from_prio($Debug) if defined $Debug && $Debug =~ /^\D+/;

	#
	# Handle -caller => [ <options for Log::Agent::Tag::Caller's make> ]
	#

	if (defined $calldef) {
		unless (ref $calldef eq 'ARRAY') {
			require Carp;
			Carp::croak("Argument -caller must supply an array ref");
		}
		require Log::Agent::Tag::Caller;
		$Caller = Log::Agent::Tag::Caller->make(-offset => 3, @{$calldef});
	};

	#
	# Handle -priority => [ <options for Log::Agent::Tag::Priority's make> ]
	#

	if (defined $priodef) {
		unless (ref $priodef eq 'ARRAY') {
			require Carp;
			Carp::croak("Argument -priority must supply an array ref");
		}
		$Priorities = $priodef;		# Objects created via prio_tag()
	};

	#
	# Handle -tags => [ <list of Log::Agent::Tag objects> ]
	#

	if (defined $tags) {
		unless (ref $tags eq 'ARRAY') {
			require Carp;
			Carp::croak("Argument -tags must supply an array ref");
		}
		my $type = "Log::Agent::Tag";
		if (grep { !ref $_ || !$_->isa($type) } @$tags) {
			require Carp;
			Carp::croak("Argument -tags must supply list of $type objects");
		}
		if (@$tags) {
			require Log::Agent::Tag_List;
			$Tags = Log::Agent::Tag_List->make(@$tags);
		} else {
			undef $Tags;
		}
	}

	# Install interceptor if needed
	DATUM_is_here() if defined $DATUM && $DATUM;
}

#
# inited
#
# Returns whether Log::Agent was inited.
# NOT exported, must be called as Log::Agent::inited().
#
sub inited {
	return 0 unless defined $Driver;
	return ref $Driver ? 1 : 0;
}

#
# DATUM_is_here		-- undocumented, but for Carp::Datum
#
# Tell Log::Agent that the Carp::Datum package was loaded and configured
# for debug.
#
# If there is a driver configured already, install the interceptor.
# Otherwise, record that DATUM is here and the interceptor will be installed
# by logconfig().
#
# NOT exported, must be called as Log::Agent::DATUM_is_here().
#
sub DATUM_is_here {
	$DATUM = 1;
	return unless defined $Driver;
	return if ref $Driver eq 'Log::Agent::Driver::Datum';

	#
	# Install the interceptor.
	#

	require Log::Agent::Driver::Datum;
	$Driver = Log::Agent::Driver::Datum->make($Driver);
}

#
# log_default
#
# Initialize a default logging driver.
#
sub log_default {
	return if defined $Driver;
	logconfig();
}

#
# logconfess
#
# Die with a full stack trace
#
sub logconfess {
	my $ptag = prio_tag(priority_level(CRIT)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logconfess($str);
	bug("back from logconfess in driver $Driver\n");
}

#
# logcroak
#
# Fatal error, from the perspective of our caller
# Error is logged, and then we die.
#
sub logcroak {
	goto &logconfess if $Confess;		# Redirected when -confess
	my $ptag = prio_tag(priority_level(CRIT)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logxcroak(0, $str);
	bug("back from logxcroak in driver $Driver\n");
}

#
# logxcroak
#
# Same a logcroak, but with a specific additional offset.
#
sub logxcroak {
	my $offset = shift;
	goto &logconfess if $Confess;		# Redirected when -confess
	my $ptag = prio_tag(priority_level(CRIT)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logxcroak($offset, $str);
	bug("back from logxcroak in driver $Driver\n");
}

#
# logdie
#
# Fatal error
# Error is logged, and then we die.
#
sub logdie {
	goto &logconfess if $Confess;		# Redirected when -confess
	my $ptag = prio_tag(priority_level(CRIT)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logdie($str);
	bug("back from logdie in driver $Driver\n");
}

#
# logerr
#
# Log error, at the "error" level.
#
sub logerr {
	return if $Trace < ERROR;
	my $ptag = prio_tag(priority_level(ERROR)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logerr($str);
}

#
# logcarp
#
# Warning, from the perspective of our caller (at the "warning" level)
#
sub logcarp {
	return if $Trace < WARN;
	my $ptag = prio_tag(priority_level(WARN)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logxcarp(0, $str);
}

#
# logxcarp
#
# Same a logcarp, but with a specific additional offset.
#
sub logxcarp {
	return if $Trace < WARN;
	my $offset = shift;
	my $ptag = prio_tag(priority_level(WARN)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logxcarp($offset, $str);
}

#
# logwarn
#
# Log warning at the "warning" level.
#
sub logwarn {
	return if $Trace < WARN;
	my $ptag = prio_tag(priority_level(WARN)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logwarn($str);
}

#
# logsay
#
# Log message at the "notice" level.
#
sub logsay {
	return if $Trace < NOTICE;
	my $ptag = prio_tag(priority_level(NOTICE)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logsay($str);
}

#
# logtrc		-- frozen
#
# Trace the message if trace level is set high enough.
# Trace level must either be a single digit or "priority" or "priority:digit".
#
sub logtrc {
	my $id = shift;
	my ($prio, $level) = priority_level($id);
	return if $level > $Trace;
	my $ptag = prio_tag($prio, $level) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logwrite('output', $prio, $level, $str);
}

#
# logdbg		-- frozen
#
# Emit debug message if debug level is set high enough.
# Debug level must either be a single digit or "priority" or "priority:digit".
#
sub logdbg {
	my $id = shift;
	my ($prio, $level) = priority_level($id);
	return if !defined($Debug) || $level > $Debug;
	my $ptag = prio_tag($prio, $level) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logwrite('debug', $prio, $level, $str);
}

#
# logtags
#
# Returns info on user-defined logging tags.
# Asking for this creates the underlying taglist object if not already present.
#
sub logtags {
	return $Tags if defined $Tags;
	require Log::Agent::Tag_List;
	return $Tags = Log::Agent::Tag_List->make();
}

###
### Utilities
###

#
# logwrite		-- not exported by default
#
# Write message to the specified channel, at the given priority.
#
sub logwrite {
	my ($channel, $id) = splice(@_, 0, 2);
	my ($prio, $level) = priority_level($id);
	my $ptag = prio_tag($prio, $level) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	&log_default unless defined $Driver;
	$Driver->logwrite($channel, $prio, $level, $str);
}

#
# bug
#
# Log bug, and die.
#
sub bug {
	my $ptag = prio_tag(priority_level(EMERG)) if defined $Priorities;
	my $str = tag_format_args($Caller, $ptag, $Tags, \@_);
	logerr("BUG: $str");
	die "${Prefix}: $str\n";
}

#
# prio_tag
#
# Returns Log::Agent::Tag::Priority message that is suitable for tagging
# at this priority/level, if configured to log priorities.
#
# Objects are cached into %prio_cache.
#
sub prio_tag {
	my ($prio, $level) = @_;
	my $ptag = $prio_cache{$prio, $level};
	return $ptag if defined $ptag;

	require Log::Agent::Tag::Priority;

	#
	# Common attributes (formatting, postfixing, etc...) are held in
	# the $Priorities global variable.  We add the priority/level here.
	#

	$ptag = Log::Agent::Tag::Priority->make(
		-priority	=> $prio,
		-level		=> $level,
		@$Priorities
	);

	return $prio_cache{$prio, $level} = $ptag;
}

#line 807
