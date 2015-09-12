#line 1 "Log/Log4perl/DateFormat.pm"
###########################################
package Log::Log4perl::DateFormat;
###########################################
use warnings;
use strict;

use Carp qw( croak );

our $GMTIME = 0;

my @MONTH_NAMES = qw(
January February March April May June July
August September October November December);

my @WEEK_DAYS = qw(
Sunday Monday Tuesday Wednesday Thursday Friday Saturday);

###########################################
sub new {
###########################################
    my($class, $format) = @_;

    my $self = { 
                  stack => [],
                  fmt   => undef,
               };

    bless $self, $class;

        # Predefined formats
    if($format eq "ABSOLUTE") {
        $format = "HH:mm:ss,SSS";
    } elsif($format eq "DATE") {
        $format = "dd MMM yyyy HH:mm:ss,SSS";
    } elsif($format eq "ISO8601") {
        $format = "yyyy-MM-dd HH:mm:ss,SSS";
    } elsif($format eq "APACHE") {
        $format = "[EEE MMM dd HH:mm:ss yyyy]";
    }

    if($format) { 
        $self->prepare($format);
    }

    return $self;
}

###########################################
sub prepare {
###########################################
    my($self, $format) = @_;

    # the actual DateTime spec allows for literal text delimited by
    # single quotes; a single quote can be embedded in the literal
    # text by using two single quotes.
    #
    # my strategy here is to split the format into active and literal
    # "chunks"; active chunks are prepared using $self->rep() as
    # before, while literal chunks get transformed to accommodate
    # single quotes and to protect percent signs.
    #
    # motivation: the "recommended" ISO-8601 date spec for a time in
    # UTC is actually:
    #
    #     YYYY-mm-dd'T'hh:mm:ss.SSS'Z'

    my $fmt = "";

    foreach my $chunk ( split /('(?:''|[^'])*')/, $format ) {
        if ( $chunk =~ /\A'(.*)'\z/ ) {
              # literal text
            my $literal = $1;
            $literal =~ s/''/'/g;
            $literal =~ s/\%/\%\%/g;
            $fmt .= $literal;
        } elsif ( $chunk =~ /'/ ) {
              # single quotes should always be in a literal
            croak "bad date format \"$format\": " .
                  "unmatched single quote in chunk \"$chunk\"";
        } else {
            # handle active chunks just like before
            $chunk =~ s/(([GyMdhHmsSEeDFwWakKzZ])\2*)/$self->rep($1)/ge;
            $fmt .= $chunk;
        }
    }

    return $self->{fmt} = $fmt;
}

###########################################
sub rep {
###########################################
    my ($self, $string) = @_;

    my $first = substr $string, 0, 1;
    my $len   = length $string;

    my $time=time();
    my @g = gmtime($time);
    my @t = localtime($time);
    my $z = $t[1]-$g[1]+($t[2]-$g[2])*60+($t[7]-$g[7])*1440+
            ($t[5]-$g[5])*(525600+(abs($t[7]-$g[7])>364)*1440);
    my $offset = sprintf("%+.2d%.2d", $z/60, "00");

    #my ($s,$mi,$h,$d,$mo,$y,$wd,$yd,$dst) = localtime($time);

    # Here's how this works:
    # Detect what kind of parameter we're dealing with and determine
    # what type of sprintf-placeholder to return (%d, %02d, %s or whatever).
    # Then, we're setting up an array, specific to the current format,
    # that can be used later on to compute the components of the placeholders
    # one by one when we get the components of the current time later on
    # via localtime.
    
    # So, we're parsing the "yyyy/MM" format once, replace it by, say
    # "%04d:%02d" and store an array that says "for the first placeholder,
    # get the localtime-parameter on index #5 (which is years since the
    # epoch), add 1900 to it and pass it on to sprintf(). For the 2nd 
    # placeholder, get the localtime component at index #2 (which is hours)
    # and pass it on unmodified to sprintf.
    
    # So, the array to compute the time format at logtime contains
    # as many elements as the original SimpleDateFormat contained. Each
    # entry is a array ref, holding an array with 2 elements: The index
    # into the localtime to obtain the value and a reference to a subroutine
    # to do computations eventually. The subroutine expects the original
    # localtime() time component (like year since the epoch) and returns
    # the desired value for sprintf (like y+1900).

    # This way, we're parsing the original format only once (during system
    # startup) and during runtime all we do is call localtime *once* and
    # run a number of blazingly fast computations, according to the number
    # of placeholders in the format.

###########
#G - epoch#
###########
    if($first eq "G") {
        # Always constant
        return "AD";

###################
#e - epoch seconds#
###################
    } elsif($first eq "e") {
          # index (0) irrelevant, but we return time() which 
          # comes in as 2nd parameter
        push @{$self->{stack}}, [0, sub { return $_[1] }];
        return "%d";

##########
#y - year#
##########
    } elsif($first eq "y") {
        if($len >= 4) {
            # 4-digit year
            push @{$self->{stack}}, [5, sub { return $_[0] + 1900 }];
            return "%04d";
        } else {
            # 2-digit year
            push @{$self->{stack}}, [5, sub { $_[0] % 100 }];
            return "%02d";
        }

###########
#M - month#
###########
    } elsif($first eq "M") {
        if($len >= 3) {
            # Use month name
            push @{$self->{stack}}, [4, sub { return $MONTH_NAMES[$_[0]] }];
           if($len >= 4) {
                return "%s";
            } else {
               return "%.3s";
            }
        } elsif($len == 2) {
            # Use zero-padded month number
            push @{$self->{stack}}, [4, sub { $_[0]+1 }];
            return "%02d";
        } else {
            # Use zero-padded month number
            push @{$self->{stack}}, [4, sub { $_[0]+1 }];
            return "%d";
        }

##################
#d - day of month#
##################
    } elsif($first eq "d") {
        push @{$self->{stack}}, [3, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#h - am/pm hour#
##################
    } elsif($first eq "h") {
        push @{$self->{stack}}, [2, sub { ($_[0] % 12) || 12 }];
        return "%0" . $len . "d";

##################
#H - 24 hour#
##################
    } elsif($first eq "H") {
        push @{$self->{stack}}, [2, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#m - minute#
##################
    } elsif($first eq "m") {
        push @{$self->{stack}}, [1, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#s - second#
##################
    } elsif($first eq "s") {
        push @{$self->{stack}}, [0, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#E - day of week #
##################
    } elsif($first eq "E") {
        push @{$self->{stack}}, [6, sub { $WEEK_DAYS[$_[0]] }];
       if($len >= 4) {
            return "%${len}s";
        } else {
           return "%.3s";
        }

######################
#D - day of the year #
######################
    } elsif($first eq "D") {
        push @{$self->{stack}}, [7, sub { $_[0] + 1}];
        return "%0" . $len . "d";

######################
#a - am/pm marker    #
######################
    } elsif($first eq "a") {
        push @{$self->{stack}}, [2, sub { $_[0] < 12 ? "AM" : "PM" }];
        return "%${len}s";

######################
#S - milliseconds    #
######################
    } elsif($first eq "S") {
        push @{$self->{stack}}, 
             [9, sub { substr sprintf("%06d", $_[0]), 0, $len }];
        return "%s";

###############################
#Z - RFC 822 time zone  -0800 #
###############################
    } elsif($first eq "Z") {
        push @{$self->{stack}}, [10, sub { $offset }];
        return "$offset";

#############################
#Something that's not defined
#(F=day of week in month
# w=week in year W=week in month
# k=hour in day K=hour in am/pm
# z=timezone
#############################
    } else {
        return "-- '$first' not (yet) implemented --";
    }

    return $string;
}

###########################################
sub format {
###########################################
    my($self, $secs, $msecs) = @_;

    $msecs = 0 unless defined $msecs;

    my @time; 

    if($GMTIME) {
        @time = gmtime($secs);
    } else {
        @time = localtime($secs);
    }

        # add milliseconds
    push @time, $msecs;

    my @values = ();

    for(@{$self->{stack}}) {
        my($val, $code) = @$_;
        if($code) {
            push @values, $code->($time[$val], $secs);
        } else {
            push @values, $time[$val];
        }
    }

    return sprintf($self->{fmt}, @values);
}

1;

__END__



#line 462
