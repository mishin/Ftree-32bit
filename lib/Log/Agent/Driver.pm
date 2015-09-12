#line 1 "Log/Agent/Driver.pm"
###########################################################################
#
#   Driver.pm
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
package Log::Agent::Driver;

#
# Ancestor for all Log::Agent drivers.
#

#
# Common attribute acccess, initialized via _init().
#
# prefix    the common (static) string info to prepend to messages
# penalty   the skip Carp penalty to offset to the fixed one
#

sub prefix  { $_[0]->{'prefix'} }
sub penalty { $_[0]->{'penalty'} }

#
# is_deferred
#
# Report routine as being deferred
#
sub is_deferred {
    require Carp;
    Carp::confess("deferred");
}

#
# ->make -- deferred
#
# Creation routine.
#
sub make {
    &is_deferred;
}

#
# ->channel_eq
#
# Compare two channels and return true if they go to the same output.
#
sub channel_eq {
    &is_deferred;
}

#
# ->_init
#
# Common initilization routine
#
sub _init {
    my $self = shift;
    my ($prefix, $penalty) = @_;
    $self->{'prefix'} = $prefix;    # Prefix info to prepend
    $self->{'penalty'} = $penalty;  # Carp stack skip penalty
}

#
# ->add_penalty        -- "exported" only to Log::Agent::Driver::Datum
#
# Add offset to current driver penalty
#
sub add_penalty {
    my $self = shift;
    my ($offset) = @_;
    $self->{penalty} += $offset;
}

my %level = (
    'c' => 1,
    'e' => 2,
    'w' => 4,
    'n' => 6,
);

#
# ->priority        -- frozen
#
# Return proper priority for emit() based on one of the following strings:
# "critical", "error", "warning", "notice". Those correspond to the hardwired
# strings for logconfess()/logdie(), logerr(), logwarn() and logsay().
#
# This routine is intended to be "frozen", i.e. it MUST NOT be redefined.
# Redefine map_pri() if needed, or don't call it in the first place.
#
sub priority {
    my $self = shift;
    my ($prio) = @_;
    my $level = $level{lc(substr($prio, 0, 1))} || 8;
    return $self->map_pri($prio, $level);
}

#
# ->write            -- deferred
#
# Write log entry, physically.
# A trailing "\n" is to be added if needed.
#
# $channel is one of 'debug', 'output', 'error' and can be used to determine
# where the emission of the log message should be done.
#
sub write {
    my $self = shift;
    my ($channel, $priority, $logstring) = @_;
    &is_deferred;
}

#
# ->emit            -- may be redefined
#
# Routine to call to emit log, resolve priority and prefix logstring.
# Ulitimately calls ->write() to perform the physical write.
#
sub emit {
    my $self = shift;
    my ($channel, $prio, $msg) = @_;
    $self->write($channel, $self->priority($prio), $self->prefix_msg($msg));
    return;
}


#
# ->map_pri            -- may be redefined
#
# Convert a ("priority", level) tupple to a single priority token suitable
# for `emit'.
#
# This is driver-specific: drivers may ignore priority altogether thanks to
# the previous level-based filtering done (-trace and -debug switches in the
# Log::Agent configuration), choose to give precedence to levels over priority
# when "priority:level" was specified, or always ignore levels and only use
# "priority".
#
# The default is to ignore "priority" and "levels", which is suitable to basic
# drivers. Only those (ala syslog) which rely on post-filtering need to be
# concerned.
#
sub map_pri {
    my $self = shift;
    my ($priority, $level) = @_;
    return '';        # ignored for basic drivers
}

#
# ->prefix_msg        -- deferred
#
# Prefix message with driver-specific string, if necessary.
#
# This routine may or may not use common attributes like the fixed
# static prefix or the process's pid.
#
sub prefix_msg {
    my $self = shift;
    my ($str) = @_;
    &is_deferred;
}

#
# ->carpmess
#
# Utility routine for logconfess and logcroak which builds the "die" message
# by calling the appropriate routine in Carp, and offseting the stack
# according to our call stack configuration, plus any offset.
#
sub carpmess {
    my $self = shift;
    my ($offset, $str, $fn) = @_;

    #
    # While confessing, we have basically tell $fn() to skip 2 stack frames:
    # this call, and our caller chain back to Log::Agent (calls within the
    # same hierarchy are automatically stripped by Carp).
    #
    # To that, we add any additional penalty level, as told us by the creation
    # routine of each driver, which accounts for extra levels used before
    # calling us.
    #

    require Carp;

    my $skip = $offset + 2 + $self->penalty;
    $Carp::CarpLevel += $skip;
    my $original = $str->str;        # Original user message
    my $msg = &$fn('__MESSAGE__');
    $Carp::CarpLevel -= $skip;

    #
    # If we have a newline in the message, we have a full stack trace.
    # Replace the original message string with the first line, and
    # append the remaining.
    #

    chomp($msg);                    # Remove final "\n" added

    if ($msg =~ s/^(.*?)\n//) {
        my $first = $1;

        #
        # Patch incorrect computation by Carp, which occurs when we request
        # a short message and we get a long one.  In that case, what we
        # want is the first line of the extra message.
        #
        # This bug manifests when the whole call chain above Log::Agent
        # lies in "main".  When objects are involved, it seems to work
        # correctly.
        #
        # The kludge here is valid for perl 5.005_03.  If some day Carp is
        # fixed, we will have to test for the Perl version.  The right fix,
        # I believe, would be to have Carp skip frame first, and not last
        # as it currently does.
        #        -- RAM, 30/09/2000
        #

        if ($fn == \&Carp::shortmess) {                # Kludge alert!!

            #
            # And things just got a little uglier with 5.8.0 
            #
            # -- mrogaski, 1 Aug 2002
            #
            my $index = $] >= 5.008 ? 1 : 0;

            $first =~ s/(at (.+) line \d+)$//;
            my $bad = $1;
            my @stack = split(/\n/, $msg);
            my ($at) = $stack[$index] =~ /(at \S+ line \d+)$/ 
                    if defined $stack[$index];
            $at = "$bad (Log::Agent could not fix it)" unless $at;
            $first .= $at;
            $str->set_str($first);
        } else {
            $str->set_str($first);
            $str->append_last("\n");
            $str->append_last($msg);    # Stack at the very tail of message
        }
    } else {
        $str->set_str($msg);        # Change original message inplace
    }

    $msg = $str->str;

    # Another Carp workaround kludge.
    $msg =~ s/ at .*\d\.at / at /;

    $msg =~ s/__MESSAGE__/$original/;
    $str->set_str($msg);

    return $str;
}

#
# ->logconfess
#
# Confess fatal error
# Error is logged, and then we confess.
#
sub logconfess {
    my $self = shift;
    my ($str) = @_;
    my $msg = $self->carpmess(0, $str, \&Carp::longmess);
    $self->emit('error', 'critical', $msg);
    die "$msg\n";
}

#
# ->logxcroak
#
# Fatal error, from the perspective of the caller.
# Error is logged, and then we confess.
#
sub logxcroak {
    my $self = shift;
    my ($offset, $str) = @_;
    my $msg = $self->carpmess($offset, $str, \&Carp::shortmess);
    $self->emit('error', 'critical', $msg);
    die "$msg\n";
}

#
# ->logdie
#
# Fatal error
# Error is logged, and then we die.
#
sub logdie {
    my $self = shift;
    my ($str) = @_;
    $self->emit('error', 'critical', $str);
    die "$str\n";
}

#
# logerr
#
# Log error
#
sub logerr {
    my $self = shift;
    my ($str) = @_;
    $self->emit('error', 'error', $str);
}

#
# ->logxcarp
#
# Log warning, from the perspective of the caller.
#
sub logxcarp {
    my $self = shift;
    my ($offset, $str) = @_;
    my $msg = $self->carpmess($offset, $str, \&Carp::shortmess);
    $self->emit('error', 'warning', $msg);
}

#
# logwarn
#
# Log warning
#
sub logwarn {
    my $self = shift;
    my ($str) = @_;
    $self->emit('error', 'warning', $str);
}

#
# logsay
#
# Log message at the "notice" level.
#
sub logsay {
    my $self = shift;
    my ($str) = @_;
    $self->emit('output', 'notice', $str);
}

#
# logwrite
#
# Emit the message to the specified channel
#
sub logwrite {
    my $self = shift;
    my ($chan, $prio, $level, $str) = @_;
    $self->write($chan, $self->map_pri($prio, $level),
        $self->prefix_msg($str));
}

1;    # for require
__END__

#line 614
