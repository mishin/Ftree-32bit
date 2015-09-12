#line 1 "Log/Log4perl/Layout/PatternLayout.pm"
##################################################
package Log::Log4perl::Layout::PatternLayout;
##################################################

use 5.006;
use strict;
use warnings;

use constant _INTERNAL_DEBUG => 0;

use Carp;
use Log::Log4perl::Util;
use Log::Log4perl::Level;
use Log::Log4perl::DateFormat;
use Log::Log4perl::NDC;
use Log::Log4perl::MDC;
use Log::Log4perl::Util::TimeTracker;
use File::Spec;
use File::Basename;

our $TIME_HIRES_AVAILABLE_WARNED = 0;
our $HOSTNAME;
our %GLOBAL_USER_DEFINED_CSPECS = ();

our $CSPECS = 'cCdFHIlLmMnpPrRtTxX%';

BEGIN {
    # Check if we've got Sys::Hostname. If not, just punt.
    $HOSTNAME = "unknown.host";
    if(Log::Log4perl::Util::module_available("Sys::Hostname")) {
        require Sys::Hostname;
        $HOSTNAME = Sys::Hostname::hostname();
    }
}

use base qw(Log::Log4perl::Layout);

no strict qw(refs);

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $options       = ref $_[0] eq "HASH" ? shift : {};
    my $layout_string = @_ ? shift : '%m%n';
    
    my $self = {
        format                => undef,
        info_needed           => {},
        stack                 => [],
        CSPECS                => $CSPECS,
        dontCollapseArrayRefs => $options->{dontCollapseArrayRefs}{value},
        last_time             => undef,
        undef_column_value    => 
            (exists $options->{ undef_column_value } 
                ? $options->{ undef_column_value } 
                : "[undef]"),
    };

    $self->{timer} = Log::Log4perl::Util::TimeTracker->new(
        time_function => $options->{time_function}
    );

    if(exists $options->{ConversionPattern}->{value}) {
        $layout_string = $options->{ConversionPattern}->{value};
    }

    if(exists $options->{message_chomp_before_newline}) {
        $self->{message_chomp_before_newline} = 
          $options->{message_chomp_before_newline}->{value};
    } else {
        $self->{message_chomp_before_newline} = 1;
    }

    bless $self, $class;

    #add the global user-defined cspecs
    foreach my $f (keys %GLOBAL_USER_DEFINED_CSPECS){
            #add it to the list of letters
        $self->{CSPECS} .= $f;
             #for globals, the coderef is already evaled, 
        $self->{USER_DEFINED_CSPECS}{$f} = $GLOBAL_USER_DEFINED_CSPECS{$f};
    }

    #add the user-defined cspecs local to this appender
    foreach my $f (keys %{$options->{cspec}}){
        $self->add_layout_cspec($f, $options->{cspec}{$f}{value});
    }

    # non-portable line breaks
    $layout_string =~ s/\\n/\n/g;
    $layout_string =~ s/\\r/\r/g;

    $self->define($layout_string);

    return $self;
}

##################################################
sub define {
##################################################
    my($self, $format) = @_;

        # If the message contains a %m followed by a newline,
        # make a note of that so that we can cut a superfluous 
        # \n off the message later on
    if($self->{message_chomp_before_newline} and $format =~ /%m%n/) {
        $self->{message_chompable} = 1;
    } else {
        $self->{message_chompable} = 0;
    }

    # Parse the format
    $format =~ s/%(-?\d*(?:\.\d+)?) 
                       ([$self->{CSPECS}])
                       (?:{(.*?)})*/
                       rep($self, $1, $2, $3);
                      /gex;

    $self->{printformat} = $format;
}

##################################################
sub rep {
##################################################
    my($self, $num, $op, $curlies) = @_;

    return "%%" if $op eq "%";

    # If it's a %d{...} construct, initialize a simple date
    # format formatter, so that we can quickly render later on.
    # If it's just %d, assume %d{yyyy/MM/dd HH:mm:ss}
    if($op eq "d") {
        if(defined $curlies) {
            $curlies = Log::Log4perl::DateFormat->new($curlies);
        } else {
            $curlies = Log::Log4perl::DateFormat->new("yyyy/MM/dd HH:mm:ss");
        }
    } elsif($op eq "m") {
        $curlies = $self->curlies_csv_parse($curlies);
    }

    push @{$self->{stack}}, [$op, $curlies];

    $self->{info_needed}->{$op}++;

    return "%${num}s";
}

###########################################
sub curlies_csv_parse {
###########################################
    my($self, $curlies) = @_;

    my $data = {};

    if(defined $curlies and length $curlies) {
        $curlies =~ s/\s//g;

        for my $field (split /,/, $curlies) {
            my($key, $value) = split /=/, $field;
            $data->{$key} = $value;
        }
    }

    return $data;
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    $caller_level = 0 unless defined  $caller_level;

    my %info    = ();

    $info{m}    = $message;
        # See 'define'
    chomp $info{m} if $self->{message_chompable};

    my @results = ();

    my $caller_offset = Log::Log4perl::caller_depth_offset( $caller_level );

    if($self->{info_needed}->{L} or
       $self->{info_needed}->{F} or
       $self->{info_needed}->{C} or
       $self->{info_needed}->{l} or
       $self->{info_needed}->{M} or
       $self->{info_needed}->{T} or
       0
      ) {

        my ($package, $filename, $line, 
            $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, 
            $hints, $bitmask) = caller($caller_offset);

        # If caller() choked because of a whacko caller level,
        # correct undefined values to '[undef]' in order to prevent 
        # warning messages when interpolating later
        unless(defined $bitmask) {
            for($package, 
                $filename, $line,
                $subroutine, $hasargs,
                $wantarray, $evaltext, $is_require,
                $hints, $bitmask) {
                $_ = '[undef]' unless defined $_;
            }
        }

        $info{L} = $line;
        $info{F} = $filename;
        $info{C} = $package;

        if($self->{info_needed}->{M} or
           $self->{info_needed}->{l} or
           0) {
            # To obtain the name of the subroutine which triggered the 
            # logger, we need to go one additional level up.
            my $levels_up = 1; 
            {
                my @callinfo = caller($caller_offset+$levels_up);

                if(_INTERNAL_DEBUG) {
                    callinfo_dump( $caller_offset, \@callinfo );
                }

                $subroutine = $callinfo[3];
                    # If we're inside an eval, go up one level further.
                if(defined $subroutine and
                   $subroutine eq "(eval)") {
                    print "Inside an eval, one up\n" if _INTERNAL_DEBUG;
                    $levels_up++;
                    redo;
                }
            }
            $subroutine = "main::" unless $subroutine;
            print "Subroutine is '$subroutine'\n" if _INTERNAL_DEBUG;
            $info{M} = $subroutine;
            $info{l} = "$subroutine $filename ($line)";
        }
    }

    $info{X} = "[No curlies defined]";
    $info{x} = Log::Log4perl::NDC->get() if $self->{info_needed}->{x};
    $info{c} = $category;
    $info{d} = 1; # Dummy value, corrected later
    $info{n} = "\n";
    $info{p} = $priority;
    $info{P} = $$;
    $info{H} = $HOSTNAME;

    my $current_time;

    if($self->{info_needed}->{r} or $self->{info_needed}->{R}) {
        if(!$TIME_HIRES_AVAILABLE_WARNED++ and 
           !$self->{timer}->hires_available()) {
            warn "Requested %r/%R pattern without installed Time::HiRes\n";
        }
        $current_time = [$self->{timer}->gettimeofday()];
    }

    if($self->{info_needed}->{r}) {
        $info{r} = $self->{timer}->milliseconds( $current_time );
    }
    if($self->{info_needed}->{R}) {
        $info{R} = $self->{timer}->delta_milliseconds( $current_time );
    }

        # Stack trace wanted?
    if($self->{info_needed}->{T}) {
        local $Carp::CarpLevel =
              $Carp::CarpLevel + $caller_offset;
        my $mess = Carp::longmess(); 
        chomp($mess);
        # $mess =~ s/(?:\A\s*at.*\n|^\s*Log::Log4perl.*\n|^\s*)//mg;
        $mess =~ s/(?:\A\s*at.*\n|^\s*)//mg;
        $mess =~ s/\n/, /g;
        $info{T} = $mess;
    }

        # As long as they're not implemented yet ..
    $info{t} = "N/A";

        # Iterate over all info fields on the stack
    for my $e (@{$self->{stack}}) {
        my($op, $curlies) = @$e;

        my $result;

        if(exists $self->{USER_DEFINED_CSPECS}->{$op}) {
            next unless $self->{info_needed}->{$op};
            $self->{curlies} = $curlies;
            $result = $self->{USER_DEFINED_CSPECS}->{$op}->($self, 
                              $message, $category, $priority, 
                              $caller_offset+1);
        } elsif(exists $info{$op}) {
            $result = $info{$op};
            if($curlies) {
                $result = $self->curly_action($op, $curlies, $info{$op},
                                              $self->{printformat}, \@results);
            } else {
                # just for %d
                if($op eq 'd') {
                    $result = $info{$op}->format($self->{timer}->gettimeofday());
                }
            }
        } else {
            warn "Format %'$op' not implemented (yet)";
            $result = "FORMAT-ERROR";
        }

        $result = $self->{undef_column_value} unless defined $result;
        push @results, $result;
    }

      # dbi appender needs that
    if( scalar @results == 1 and
        !defined $results[0] ) {
        return undef;
    }

    return (sprintf $self->{printformat}, @results);
}

##################################################
sub curly_action {
##################################################
    my($self, $ops, $curlies, $data, $printformat, $results) = @_;

    if($ops eq "c") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "C") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "X") {
        $data = Log::Log4perl::MDC->get($curlies);
    } elsif($ops eq "d") {
        $data = $curlies->format( $self->{timer}->gettimeofday() );
    } elsif($ops eq "M") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "m") {
        if(exists $curlies->{chomp}) {
            chomp $data;
        }
        if(exists $curlies->{indent}) {
            if(defined $curlies->{indent}) {
                  # fixed indent
                $data =~ s/\n/ "\n" . (" " x $curlies->{indent})/ge;
            } else {
                  # indent on the lead-in
                no warnings; # trailing array elements are undefined
                my $indent = length sprintf $printformat, @$results;
                $data =~ s/\n/ "\n" . (" " x $indent)/ge;
            }
        }
    } elsif($ops eq "F") {
        my @parts = File::Spec->splitdir($data);
            # Limit it to max curlies entries
        if(@parts > $curlies) {
            splice @parts, 0, @parts - $curlies;
        }
        $data = File::Spec->catfile(@parts);
    } elsif($ops eq "p") {
        $data = substr $data, 0, $curlies;
    }

    return $data;
}

##################################################
sub shrink_category {
##################################################
    my($category, $len) = @_;

    my @components = split /\.|::/, $category;

    if(@components > $len) {
        splice @components, 0, @components - $len;
        $category = join '.', @components;
    } 

    return $category;
}

##################################################
sub add_global_cspec {
##################################################
# This is a Class method.
# Accepts a coderef or text
##################################################

    unless($Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE) {
        die "\$Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE setting " .
            "prohibits user defined cspecs";
    }

    my ($letter, $perlcode) = @_;

    croak "Illegal value '$letter' in call to add_global_cspec()"
        unless ($letter =~ /^[a-zA-Z]$/);

    croak "Missing argument for perlcode for 'cspec.$letter' ".
          "in call to add_global_cspec()"
        unless $perlcode;

    croak "Please don't redefine built-in cspecs [$CSPECS]\n".
          "like you do for \"cspec.$letter\"\n "
        if ($CSPECS =~/$letter/);

    if (ref $perlcode eq 'CODE') {
        $GLOBAL_USER_DEFINED_CSPECS{$letter} = $perlcode;

    }elsif (! ref $perlcode){
        
        $GLOBAL_USER_DEFINED_CSPECS{$letter} = 
            Log::Log4perl::Config::compile_if_perl($perlcode);

        if ($@) {
            die qq{Compilation failed for your perl code for }.
                qq{"log4j.PatternLayout.cspec.$letter":\n}.
                qq{This is the error message: \t$@\n}.
                qq{This is the code that failed: \n$perlcode\n};
        }

        croak "eval'ing your perlcode for 'log4j.PatternLayout.cspec.$letter' ".
              "doesn't return a coderef \n".
              "Here is the perl code: \n\t$perlcode\n "
            unless (ref $GLOBAL_USER_DEFINED_CSPECS{$letter} eq 'CODE');

    }else{
        croak "I don't know how to handle perlcode=$perlcode ".
              "for 'cspec.$letter' in call to add_global_cspec()";
    }
}

##################################################
sub add_layout_cspec {
##################################################
# object method
# adds a cspec just for this layout
##################################################
    my ($self, $letter, $perlcode) = @_;

    unless($Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE) {
        die "\$Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE setting " .
            "prohibits user defined cspecs";
    }

    croak "Illegal value '$letter' in call to add_layout_cspec()"
        unless ($letter =~ /^[a-zA-Z]$/);

    croak "Missing argument for perlcode for 'cspec.$letter' ".
          "in call to add_layout_cspec()"
        unless $perlcode;

    croak "Please don't redefine built-in cspecs [$CSPECS] \n".
          "like you do for 'cspec.$letter'"
        if ($CSPECS =~/$letter/);

    if (ref $perlcode eq 'CODE') {

        $self->{USER_DEFINED_CSPECS}{$letter} = $perlcode;

    }elsif (! ref $perlcode){
        
        $self->{USER_DEFINED_CSPECS}{$letter} =
            Log::Log4perl::Config::compile_if_perl($perlcode);

        if ($@) {
            die qq{Compilation failed for your perl code for }.
                qq{"cspec.$letter":\n}.
                qq{This is the error message: \t$@\n}.
                qq{This is the code that failed: \n$perlcode\n};
        }
        croak "eval'ing your perlcode for 'cspec.$letter' ".
              "doesn't return a coderef \n".
              "Here is the perl code: \n\t$perlcode\n "
            unless (ref $self->{USER_DEFINED_CSPECS}{$letter} eq 'CODE');


    }else{
        croak "I don't know how to handle perlcode=$perlcode ".
              "for 'cspec.$letter' in call to add_layout_cspec()";
    }

    $self->{CSPECS} .= $letter;
}

###########################################
sub callinfo_dump {
###########################################
    my($level, $info) = @_;

    my @called_by = caller(0);

    # Just for internal debugging
    $called_by[1] = basename $called_by[1];
    print "caller($level) at $called_by[1]-$called_by[2] returned ";

    my @by_idx;

    # $info->[1] = basename $info->[1] if defined $info->[1];

    my $i = 0;
    for my $field (qw(package filename line subroutine hasargs
                      wantarray evaltext is_require hints bitmask)) {
        $by_idx[$i] = $field;
        $i++;
    }

    $i = 0;
    for my $value (@$info) {
        my $field = $by_idx[ $i ];
        print "$field=", 
              (defined $info->[$i] ? $info->[$i] : "[undef]"),
              " ";
        $i++;
    }

    print "\n";
}

1;

__END__



#line 889
