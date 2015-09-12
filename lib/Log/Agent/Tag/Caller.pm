#line 1 "Log/Agent/Tag/Caller.pm"
###########################################################################
#
#   Caller.pm
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
package Log::Agent::Tag::Caller;

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
#    -OFFSET        value for the offset attribute [NOT DOCUMENTED]
#    -INFO        string of keywords like "package filename line subroutine"
#    -FORMAT        formatting instructions, like "%s:%d", used along with -INFO
#    -POSTFIX    whether to postfix log message or prefix it.
#   -DISPLAY    a string like '($subroutine/$line)', supersedes -INFO
#   -SEPARATOR  separator string to use between tag and message
#
# Attributes:
#    indices        listref of indices to select in the caller() array
#    offset        how many stack frames are between us and the caller we trace
#    format        how to format extracted caller() info
#    postfix        true if info to append to logged string
#
sub make {
    my $self = bless {}, shift;
    my (%args) = @_;

    $self->{'offset'} = 0;

    my $info;
    my $postfix = 0;
    my $separator;

    my %set = (
        -offset        => \$self->{'offset'},
        -info        => \$info,
        -format        => \$self->{'format'},
        -postfix    => \$postfix,
        -display    => \$self->{'display'},
        -separator    => \$separator,
    );

    while (my ($arg, $val) = each %args) {
        my $vset = $set{lc($arg)};
        next unless ref $vset;
        $$vset = $val;
    }

    $self->_init("caller", $postfix, $separator);

    return $self if $self->display;        # A display string takes precedence

    #
    # pre-process info to compute the indices
    #

    my $i = 0;
    my %indices = map { $_ => $i++ } qw(pac fil lin sub);    # abbrevs
    my @indices = ();

    foreach my $token (split(' ', $info)) {
        my $abbr = substr($token, 0, 3);
        push(@indices, $indices{$abbr}) if exists $indices{$abbr};
    }

    $self->{'indices'} = \@indices;

    return $self;
}

#
# Attribute access
#

sub offset        { $_[0]->{'offset'} }
sub indices        { $_[0]->{'indices'} }
sub format        { $_[0]->{'format'} }
sub display        { $_[0]->{'display'} }
sub postfix        { $_[0]->{'postfix'} }

#
# expand_a
#
# Expand the %a macro and return new string.
#
if ($] >= 5.005) { eval q{                # if VERSION >= 5.005

# 5.005 and later version grok /(?<!)/
sub expand_a {
    my ($str, $aref) = @_;
    $str =~ s/((?<!%)(?:%%)*)%a/join(':', @$aref)/ge;
    return $str;
}

}} else { eval q{                        # else /* VERSION < 5.005 */

# pre-5.005 does not grok /(?<!)/
sub expand_a {
    my ($str, $aref) = @_;
    $str =~ s/%%/\01/g;
    $str =~ s/%a/join(':', @$aref)/ge;
    $str =~ s/\01/%%/g;
    return $str;
}

}}                                        # endif /* VERSION >= 5.005 */

#
# ->string        -- defined
#
# Compute string with properly formatted caller info
#
sub string {
    my $self = shift;

    #
    # The following code:
    #
    #    sub foo {
    #        my ($pack, $file, $line, $sub) = caller(0);
    #        print "excuting $sub called at $file/$line in $pack";
    #    }
    #
    # will report who called us, except that $sub will be US, not our CALLER!
    # This is an "anomaly" somehow, and therefore to get the routine name
    # that called us, we need to move one frame above the ->offset value.
    #

    my @caller = caller($self->offset);
    
    # Kludge for anomalies in caller()
    # Thanks to Jeff Boes for finding the second one!
    $caller[3] = (caller($self->offset + 1))[3] || '(main)';

    my ($package, $filename, $line, $subroutine) = @caller;

    #
    # If there is a display, it takes precedence and is formatted accordingly,
    # with limited variable substitution. The variables that are recognized
    # are:
    #
    #        $package or $pack        package name of caller
    #        $filename or $file        filename of caller
    #        $line                    line number of caller
    #        $subroutine or $sub        routine name of caller
    #
    # We recognize both $line and ${line}, the difference being that the
    # first needs to be at a word boundary (i.e. $lineage would not result
    # in any expansion).
    #
    # Otherwise, the necessary information is gathered from the caller()
    # output, and formatted via sprintf, along with the special %a macro
    # which stands for all the information, separated by ':'.
    #
    # NB: The default format is "[%a]" for postfixed info, "(%a)" otherwise.
    #

    my $display = $self->display;
    if ($display) {
        $display =~ s/\$pack(?:age)?\b/$package/g;
        $display =~ s/\${pack(?:age)?}/$package/g;
        $display =~ s/\$file(?:name)?\b/$filename/g;
        $display =~ s/\${file(?:name)?}/$filename/g;
        $display =~ s/\$line\b/$line/g;
        $display =~ s/\${line}/$line/g;
        $display =~ s/\$sub(?:routine)?\b/$subroutine/g;
        $display =~ s/\${sub(?:routine)?}/$subroutine/g;
    } else {
        my @show = map { $caller[$_] } @{$self->indices};
        my $format = $self->format || ($self->postfix ? "[%a]" : "(%a)");
        $format = expand_a($format, \@show);    # depends on Perl's version
        $display = sprintf $format, @show;
    }

    return $display;
}

1;            # for "require"
__END__

#line 327

