#line 1 "Term/ANSIColor.pm"
# Term::ANSIColor -- Color screen output using ANSI escape sequences.
#
# Copyright 1996, 1997, 1998, 2000, 2001, 2002, 2005, 2006, 2008, 2009, 2010,
#     2011, 2012, 2013, 2014 Russ Allbery <rra@cpan.org>
# Copyright 1996 Zenin
# Copyright 2012 Kurt Starsinic <kstarsinic@gmail.com>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# PUSH/POP support submitted 2007 by openmethods.com voice solutions
#
# Ah, September, when the sysadmins turn colors and fall off the trees....
#                               -- Dave Van Domelen

##############################################################################
# Modules and declarations
##############################################################################

package Term::ANSIColor;

use 5.006;
use strict;
use warnings;

use Carp qw(croak);
use Exporter ();

# use Exporter plus @ISA instead of use base for 5.6 compatibility.
## no critic (ClassHierarchies::ProhibitExplicitISA)

# Declare variables that should be set in BEGIN for robustness.
## no critic (Modules::ProhibitAutomaticExportation)
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS, @ISA, $VERSION);

# We use autoloading, which sets this variable to the name of the called sub.
our $AUTOLOAD;

# Set $VERSION and everything export-related in a BEGIN block for robustness
# against circular module loading (not that we load any modules, but
# consistency is good).
BEGIN {
    $VERSION = '4.03';

    # All of the basic supported constants, used in %EXPORT_TAGS.
    my @colorlist = qw(
      CLEAR           RESET             BOLD            DARK
      FAINT           ITALIC            UNDERLINE       UNDERSCORE
      BLINK           REVERSE           CONCEALED

      BLACK           RED               GREEN           YELLOW
      BLUE            MAGENTA           CYAN            WHITE
      ON_BLACK        ON_RED            ON_GREEN        ON_YELLOW
      ON_BLUE         ON_MAGENTA        ON_CYAN         ON_WHITE

      BRIGHT_BLACK    BRIGHT_RED        BRIGHT_GREEN    BRIGHT_YELLOW
      BRIGHT_BLUE     BRIGHT_MAGENTA    BRIGHT_CYAN     BRIGHT_WHITE
      ON_BRIGHT_BLACK ON_BRIGHT_RED     ON_BRIGHT_GREEN ON_BRIGHT_YELLOW
      ON_BRIGHT_BLUE  ON_BRIGHT_MAGENTA ON_BRIGHT_CYAN  ON_BRIGHT_WHITE
    );

    # 256-color constants, used in %EXPORT_TAGS.
    my @colorlist256 = (
        (map { ("ANSI$_", "ON_ANSI$_") } 0 .. 15),
        (map { ("GREY$_", "ON_GREY$_") } 0 .. 23),
    );
    for my $r (0 .. 5) {
        for my $g (0 .. 5) {
            push(@colorlist256, map { ("RGB$r$g$_", "ON_RGB$r$g$_") } 0 .. 5);
        }
    }

    # Exported symbol configuration.
    @ISA         = qw(Exporter);
    @EXPORT      = qw(color colored);
    @EXPORT_OK   = qw(uncolor colorstrip colorvalid coloralias);
    %EXPORT_TAGS = (
        constants    => \@colorlist,
        constants256 => \@colorlist256,
        pushpop      => [@colorlist, qw(PUSHCOLOR POPCOLOR LOCALCOLOR)],
    );
    Exporter::export_ok_tags('pushpop', 'constants256');
}

##############################################################################
# Package variables
##############################################################################

# If this is set, any color changes will implicitly push the current color
# onto the stack and then pop it at the end of the constant sequence, just as
# if LOCALCOLOR were used.
our $AUTOLOCAL;

# Caller sets this to force a reset at the end of each constant sequence.
our $AUTORESET;

# Caller sets this to force colors to be reset at the end of each line.
our $EACHLINE;

##############################################################################
# Internal data structures
##############################################################################

# This module does quite a bit of initialization at the time it is first
# loaded, primarily to set up the package-global %ATTRIBUTES hash.  The
# entries for 256-color names are easier to handle programmatically, and
# custom colors are also imported from the environment if any are set.

# All basic supported attributes, including aliases.
#<<<
our %ATTRIBUTES = (
    'clear'          => 0,
    'reset'          => 0,
    'bold'           => 1,
    'dark'           => 2,
    'faint'          => 2,
    'italic'         => 3,
    'underline'      => 4,
    'underscore'     => 4,
    'blink'          => 5,
    'reverse'        => 7,
    'concealed'      => 8,

    'black'          => 30,   'on_black'          => 40,
    'red'            => 31,   'on_red'            => 41,
    'green'          => 32,   'on_green'          => 42,
    'yellow'         => 33,   'on_yellow'         => 43,
    'blue'           => 34,   'on_blue'           => 44,
    'magenta'        => 35,   'on_magenta'        => 45,
    'cyan'           => 36,   'on_cyan'           => 46,
    'white'          => 37,   'on_white'          => 47,

    'bright_black'   => 90,   'on_bright_black'   => 100,
    'bright_red'     => 91,   'on_bright_red'     => 101,
    'bright_green'   => 92,   'on_bright_green'   => 102,
    'bright_yellow'  => 93,   'on_bright_yellow'  => 103,
    'bright_blue'    => 94,   'on_bright_blue'    => 104,
    'bright_magenta' => 95,   'on_bright_magenta' => 105,
    'bright_cyan'    => 96,   'on_bright_cyan'    => 106,
    'bright_white'   => 97,   'on_bright_white'   => 107,
);
#>>>

# Generating the 256-color codes involves a lot of codes and offsets that are
# not helped by turning them into constants.

# The first 16 256-color codes are duplicates of the 16 ANSI colors,
# included for completeness.
for my $code (0 .. 15) {
    $ATTRIBUTES{"ansi$code"}    = "38;5;$code";
    $ATTRIBUTES{"on_ansi$code"} = "48;5;$code";
}

# 256-color RGB colors.  Red, green, and blue can each be values 0 through 5,
# and the resulting 216 colors start with color 16.
for my $r (0 .. 5) {
    for my $g (0 .. 5) {
        for my $b (0 .. 5) {
            my $code = 16 + (6 * 6 * $r) + (6 * $g) + $b;
            $ATTRIBUTES{"rgb$r$g$b"}    = "38;5;$code";
            $ATTRIBUTES{"on_rgb$r$g$b"} = "48;5;$code";
        }
    }
}

# The last 256-color codes are 24 shades of grey.
for my $n (0 .. 23) {
    my $code = $n + 232;
    $ATTRIBUTES{"grey$n"}    = "38;5;$code";
    $ATTRIBUTES{"on_grey$n"} = "48;5;$code";
}

# Reverse lookup.  Alphabetically first name for a sequence is preferred.
our %ATTRIBUTES_R;
for my $attr (reverse sort keys %ATTRIBUTES) {
    $ATTRIBUTES_R{ $ATTRIBUTES{$attr} } = $attr;
}

# Import any custom colors set in the environment.
our %ALIASES;
if (exists $ENV{ANSI_COLORS_ALIASES}) {
    my $spec = $ENV{ANSI_COLORS_ALIASES};
    $spec =~ s{\s+}{}xmsg;

    # Error reporting here is an interesting question.  Use warn rather than
    # carp because carp would report the line of the use or require, which
    # doesn't help anyone understand what's going on, whereas seeing this code
    # will be more helpful.
    ## no critic (ErrorHandling::RequireCarping)
    for my $definition (split m{,}xms, $spec) {
        my ($new, $old) = split m{=}xms, $definition, 2;
        if (!$new || !$old) {
            warn qq{Bad color mapping "$definition"};
        } else {
            my $result = eval { coloralias($new, $old) };
            if (!$result) {
                my $error = $@;
                $error =~ s{ [ ] at [ ] .* }{}xms;
                warn qq{$error in "$definition"};
            }
        }
    }
}

# Stores the current color stack maintained by PUSHCOLOR and POPCOLOR.  This
# is global and therefore not threadsafe.
our @COLORSTACK;

##############################################################################
# Implementation (constant form)
##############################################################################

# Time to have fun!  We now want to define the constant subs, which are named
# the same as the attributes above but in all caps.  Each constant sub needs
# to act differently depending on whether $AUTORESET is set.  Without
# autoreset:
#
#     BLUE "text\n"  ==>  "\e[34mtext\n"
#
# If $AUTORESET is set, we should instead get:
#
#     BLUE "text\n"  ==>  "\e[34mtext\n\e[0m"
#
# The sub also needs to handle the case where it has no arguments correctly.
# Maintaining all of this as separate subs would be a major nightmare, as well
# as duplicate the %ATTRIBUTES hash, so instead we define an AUTOLOAD sub to
# define the constant subs on demand.  To do that, we check the name of the
# called sub against the list of attributes, and if it's an all-caps version
# of one of them, we define the sub on the fly and then run it.
#
# If the environment variable ANSI_COLORS_DISABLED is set to a true value,
# just return the arguments without adding any escape sequences.  This is to
# make it easier to write scripts that also work on systems without any ANSI
# support, like Windows consoles.
#
## no critic (ClassHierarchies::ProhibitAutoloading)
## no critic (Subroutines::RequireArgUnpacking)
sub AUTOLOAD {
    my ($sub, $attr) = $AUTOLOAD =~ m{ \A ([\w:]*::([[:upper:]\d_]+)) \z }xms;

    # Check if we were called with something that doesn't look like an
    # attribute.
    if (!($attr && defined($ATTRIBUTES{ lc $attr }))) {
        croak("undefined subroutine &$AUTOLOAD called");
    }

    # If colors are disabled, just return the input.  Do this without
    # installing a sub for (marginal, unbenchmarked) speed.
    if ($ENV{ANSI_COLORS_DISABLED}) {
        return join(q{}, @_);
    }

    # We've untainted the name of the sub.
    $AUTOLOAD = $sub;

    # Figure out the ANSI string to set the desired attribute.
    my $escape = "\e[" . $ATTRIBUTES{ lc $attr } . 'm';

    # Save the current value of $@.  We can't just use local since we want to
    # restore it before dispatching to the newly-created sub.  (The caller may
    # be colorizing output that includes $@.)
    my $eval_err = $@;

    # Generate the constant sub, which should still recognize some of our
    # package variables.  Use string eval to avoid a dependency on
    # Sub::Install, even though it makes it somewhat less readable.
    ## no critic (BuiltinFunctions::ProhibitStringyEval)
    ## no critic (ValuesAndExpressions::ProhibitImplicitNewlines)
    my $eval_result = eval qq{
        sub $AUTOLOAD {
            if (\$ENV{ANSI_COLORS_DISABLED}) {
                return join(q{}, \@_);
            } elsif (\$AUTOLOCAL && \@_) {
                return PUSHCOLOR('$escape') . join(q{}, \@_) . POPCOLOR;
            } elsif (\$AUTORESET && \@_) {
                return '$escape' . join(q{}, \@_) . "\e[0m";
            } else {
                return '$escape' . join(q{}, \@_);
            }
        }
        1;
    };

    # Failure is an internal error, not a problem with the caller.
    ## no critic (ErrorHandling::RequireCarping)
    if (!$eval_result) {
        die "failed to generate constant $attr: $@";
    }

    # Restore $@.
    ## no critic (Variables::RequireLocalizedPunctuationVars)
    $@ = $eval_err;

    # Dispatch to the newly-created sub.
    ## no critic (References::ProhibitDoubleSigils)
    goto &$AUTOLOAD;
}
## use critic (Subroutines::RequireArgUnpacking)

# Append a new color to the top of the color stack and return the top of
# the stack.
#
# $text - Any text we're applying colors to, with color escapes prepended
#
# Returns: The text passed in
sub PUSHCOLOR {
    my (@text) = @_;
    my $text = join(q{}, @text);

    # Extract any number of color-setting escape sequences from the start of
    # the string.
    my ($color) = $text =~ m{ \A ( (?:\e\[ [\d;]+ m)+ ) }xms;

    # If we already have a stack, append these escapes to the set from the top
    # of the stack.  This way, each position in the stack stores the complete
    # enabled colors for that stage, at the cost of some potential
    # inefficiency.
    if (@COLORSTACK) {
        $color = $COLORSTACK[-1] . $color;
    }

    # Push the color onto the stack.
    push(@COLORSTACK, $color);
    return $text;
}

# Pop the color stack and return the new top of the stack (or reset, if
# the stack is empty).
#
# @text - Any text we're applying colors to
#
# Returns: The concatenation of @text prepended with the new stack color
sub POPCOLOR {
    my (@text) = @_;
    pop(@COLORSTACK);
    if (@COLORSTACK) {
        return $COLORSTACK[-1] . join(q{}, @text);
    } else {
        return RESET(@text);
    }
}

# Surround arguments with a push and a pop.  The effect will be to reset the
# colors to whatever was on the color stack before this sequence of colors was
# applied.
#
# @text - Any text we're applying colors to
#
# Returns: The concatenation of the text and the proper color reset sequence.
sub LOCALCOLOR {
    my (@text) = @_;
    return PUSHCOLOR(join(q{}, @text)) . POPCOLOR();
}

##############################################################################
# Implementation (attribute string form)
##############################################################################

# Return the escape code for a given set of color attributes.
#
# @codes - A list of possibly space-separated color attributes
#
# Returns: The escape sequence setting those color attributes
#          undef if no escape sequences were given
#  Throws: Text exception for any invalid attribute
sub color {
    my (@codes) = @_;
    @codes = map { split } @codes;

    # Return the empty string if colors are disabled.
    if ($ENV{ANSI_COLORS_DISABLED}) {
        return q{};
    }

    # Build the attribute string from semicolon-separated numbers.
    my $attribute = q{};
    for my $code (@codes) {
        $code = lc($code);
        if (defined($ATTRIBUTES{$code})) {
            $attribute .= $ATTRIBUTES{$code} . q{;};
        } elsif (defined($ALIASES{$code})) {
            $attribute .= $ALIASES{$code} . q{;};
        } else {
            croak("Invalid attribute name $code");
        }
    }

    # We added one too many semicolons for simplicity.  Remove the last one.
    chop($attribute);

    # Return undef if there were no attributes.
    return ($attribute ne q{}) ? "\e[${attribute}m" : undef;
}

# Return a list of named color attributes for a given set of escape codes.
# Escape sequences can be given with or without enclosing "\e[" and "m".  The
# empty escape sequence '' or "\e[m" gives an empty list of attrs.
#
# There is one special case.  256-color codes start with 38 or 48, followed by
# a 5 and then the 256-color code.
#
# @escapes - A list of escape sequences or escape sequence numbers
#
# Returns: An array of attribute names corresponding to those sequences
#  Throws: Text exceptions on invalid escape sequences or unknown colors
sub uncolor {
    my (@escapes) = @_;
    my (@nums, @result);

    # Walk the list of escapes and build a list of attribute numbers.
    for my $escape (@escapes) {
        $escape =~ s{ \A \e\[ }{}xms;
        $escape =~ s{ m \z }   {}xms;
        my ($attrs) = $escape =~ m{ \A ((?:\d+;)* \d*) \z }xms;
        if (!defined($attrs)) {
            croak("Bad escape sequence $escape");
        }

        # Pull off 256-color codes (38;5;n or 48;5;n) as a unit.
        push(@nums, $attrs =~ m{ ( 0*[34]8;0*5;\d+ | \d+ ) (?: ; | \z ) }xmsg);
    }

    # Now, walk the list of numbers and convert them to attribute names.
    # Strip leading zeroes from any of the numbers.  (xterm, at least, allows
    # leading zeroes to be added to any number in an escape sequence.)
    for my $num (@nums) {
        $num =~ s{ ( \A | ; ) 0+ (\d) }{$1$2}xmsg;
        my $name = $ATTRIBUTES_R{$num};
        if (!defined($name)) {
            croak("No name for escape sequence $num");
        }
        push(@result, $name);
    }

    # Return the attribute names.
    return @result;
}

# Given a string and a set of attributes, returns the string surrounded by
# escape codes to set those attributes and then clear them at the end of the
# string.  The attributes can be given either as an array ref as the first
# argument or as a list as the second and subsequent arguments.
#
# If $EACHLINE is set, insert a reset before each occurrence of the string
# $EACHLINE and the starting attribute code after the string $EACHLINE, so
# that no attribute crosses line delimiters (this is often desirable if the
# output is to be piped to a pager or some other program).
#
# $first - An anonymous array of attributes or the text to color
# @rest  - The text to color or the list of attributes
#
# Returns: The text, concatenated if necessary, surrounded by escapes to set
#          the desired colors and reset them afterwards
#  Throws: Text exception on invalid attributes
sub colored {
    my ($first, @rest) = @_;
    my ($string, @codes);
    if (ref($first) && ref($first) eq 'ARRAY') {
        @codes = @{$first};
        $string = join(q{}, @rest);
    } else {
        $string = $first;
        @codes  = @rest;
    }

    # Return the string unmolested if colors are disabled.
    if ($ENV{ANSI_COLORS_DISABLED}) {
        return $string;
    }

    # Find the attribute string for our colors.
    my $attr = color(@codes);

    # If $EACHLINE is defined, split the string on line boundaries, suppress
    # empty segments, and then colorize each of the line sections.
    if (defined($EACHLINE)) {
        my @text = map { ($_ ne $EACHLINE) ? $attr . $_ . "\e[0m" : $_ }
          grep { length($_) > 0 }
          split(m{ (\Q$EACHLINE\E) }xms, $string);
        return join(q{}, @text);
    } else {
        return $attr . $string . "\e[0m";
    }
}

# Define a new color alias, or return the value of an existing alias.
#
# $alias - The color alias to define
# $color - The standard color the alias will correspond to (optional)
#
# Returns: The standard color value of the alias
#          undef if one argument was given and the alias was not recognized
#  Throws: Text exceptions for invalid alias names, attempts to use a
#          standard color name as an alias, or an unknown standard color name
sub coloralias {
    my ($alias, $color) = @_;
    if (!defined($color)) {
        if (!exists $ALIASES{$alias}) {
            return;
        } else {
            return $ATTRIBUTES_R{ $ALIASES{$alias} };
        }
    }
    if ($alias !~ m{ \A [\w._-]+ \z }xms) {
        croak(qq{Invalid alias name "$alias"});
    } elsif ($ATTRIBUTES{$alias}) {
        croak(qq{Cannot alias standard color "$alias"});
    } elsif (!exists $ATTRIBUTES{$color}) {
        croak(qq{Invalid attribute name "$color"});
    }
    $ALIASES{$alias} = $ATTRIBUTES{$color};
    return $color;
}

# Given a string, strip the ANSI color codes out of that string and return the
# result.  This removes only ANSI color codes, not movement codes and other
# escape sequences.
#
# @string - The list of strings to sanitize
#
# Returns: (array)  The strings stripped of ANSI color escape sequences
#          (scalar) The same, concatenated
sub colorstrip {
    my (@string) = @_;
    for my $string (@string) {
        $string =~ s{ \e\[ [\d;]* m }{}xmsg;
    }
    return wantarray ? @string : join(q{}, @string);
}

# Given a list of color attributes (arguments for color, for instance), return
# true if they're all valid or false if any of them are invalid.
#
# @codes - A list of color attributes, possibly space-separated
#
# Returns: True if all the attributes are valid, false otherwise.
sub colorvalid {
    my (@codes) = @_;
    @codes = map { split(q{ }, lc($_)) } @codes;
    for my $code (@codes) {
        if (!defined($ATTRIBUTES{$code}) && !defined($ALIASES{$code})) {
            return;
        }
    }
    return 1;
}

##############################################################################
# Module return value and documentation
##############################################################################

# Ensure we evaluate to true.
1;
__END__

#line 1223
