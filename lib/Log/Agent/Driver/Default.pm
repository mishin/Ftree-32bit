#line 1 "Log/Agent/Driver/Default.pm"
###########################################################################
#
#   Default.pm
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
require Log::Agent::Driver;

########################################################################
package Log::Agent::Driver::Default;

use vars qw(@ISA);

@ISA = qw(Log::Agent::Driver);

#
# ->make			-- defined
#
# Creation routine.
#
sub make {
	my $self = bless {}, shift;
	my ($prefix) = @_;
	$self->_init($prefix, 0);					# 0 is the skip Carp penalty
	select((select(main::STDERR), $| = 1)[0]);	# Autoflush
	return $self;
}

#
# ->prefix_msg		-- defined
#
# Prepend "prefix: " to the error string, or nothing if no prefix, in which
# case we capitalize the very first letter of the string.
#
sub prefix_msg {
	my $self = shift;
	my ($str) = @_;
	my $prefix = $self->prefix;
	return ucfirst($str) if !defined($prefix) || $prefix eq '';
	return "$prefix: " . $str;
}

#
# ->write			-- defined
#
sub write {
	my $self = shift;
	my ($channel, $priority, $logstring) = @_;
	local $\ = undef;
	print main::STDERR "$logstring\n";
}

#
# ->channel_eq		-- defined
#
# All channels equals here
#
sub channel_eq {
	my $self = shift;
	return 1;
}

#
# ->logconfess		-- redefined
#
# Fatal error, with stack trace
#
sub logconfess {
	my $self = shift;
	my ($str) = @_;
	require Carp;
	my $msg = $self->carpmess(0, $str, \&Carp::longmess);
	die $self->prefix_msg("$msg\n");
}

#
# ->logxcroak		-- redefined
#
# Fatal error, from perspective of caller
#
sub logxcroak {
	my $self = shift;
	my ($offset, $str) = @_;
	require Carp;
	my $msg = $self->carpmess($offset, $str, \&Carp::shortmess);
	die $self->prefix_msg("$msg\n");
}

#
# ->logdie			-- redefined
#
# Fatal error
#
sub logdie {
	my $self = shift;
	my ($str) = @_;
	die $self->prefix_msg("$str\n");
}

#
# ->logerr			-- redefined
#
# Signal error on stderr
#
sub logerr {
	my $self = shift;
	my ($str) = @_;
	warn $self->prefix_msg("$str\n");
}

#
# ->logwarn			-- redefined
#
# Warn, with "WARNING" clearly emphasized
#
sub logwarn {
	my $self = shift;
	my ($str) = @_;
	$str->prepend("WARNING: ");
	warn $self->prefix_msg("$str\n");
}

#
# ->logxcarp		-- redefined
#
# Warn from perspective of caller, with "WARNING" clearly emphasized.
#
sub logxcarp {
	my $self = shift;
	my ($offset, $str) = @_;
	$str->prepend("WARNING: ");
	require Carp;
	my $msg = $self->carpmess($offset, $str, \&Carp::shortmess);
	warn $self->prefix_msg("$msg\n");
}

1;	# for require
__END__

#line 204
