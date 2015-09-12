#line 1 "Log/Log4perl/Resurrector.pm"
package Log::Log4perl::Resurrector;
use warnings;
use strict;

# [rt.cpan.org #84818]
use if $^O eq "MSWin32", "Win32"; 

use File::Temp qw(tempfile);
use File::Spec;

use constant INTERNAL_DEBUG => 0;

our $resurrecting = '';

###########################################
sub import {
###########################################
    resurrector_init();
}

##################################################
sub resurrector_fh {
##################################################
    my($file) = @_;

    local($/) = undef;
    open FILE, "<$file" or die "Cannot open $file";
    my $text = <FILE>;
    close FILE;

    print "Read ", length($text), " bytes from $file\n" if INTERNAL_DEBUG;

    my($tmp_fh, $tmpfile) = tempfile( UNLINK => 1 );
    print "Opened tmpfile $tmpfile\n" if INTERNAL_DEBUG;

    $text =~ s/^\s*###l4p//mg;

    print "Text=[$text]\n" if INTERNAL_DEBUG;

    print $tmp_fh $text;
    seek $tmp_fh, 0, 0;

    return $tmp_fh;
}

###########################################
sub resurrector_loader {
###########################################
    my ($code, $module) = @_;

    print "resurrector_loader called with $module\n" if INTERNAL_DEBUG;

      # Avoid recursion
    if($resurrecting eq $module) {
        print "ignoring $module (recursion)\n" if INTERNAL_DEBUG;
        return undef;
    }
    
    local $resurrecting = $module;
    
    
      # Skip Log4perl appenders
    if($module =~ m#^Log/Log4perl/Appender#) {
        print "Ignoring $module (Log4perl-internal)\n" if INTERNAL_DEBUG;
        return undef;
    }

    my $path = $module;

      # Skip unknown files
    if(!-f $module) {
          # We might have a 'use lib' statement that modified the
          # INC path, search again.
        $path = pm_search($module);
        if(! defined $path) {
            print "File $module not found\n" if INTERNAL_DEBUG;
            return undef;
        }
        print "File $module found in $path\n" if INTERNAL_DEBUG;
    }

    print "Resurrecting module $path\n" if INTERNAL_DEBUG;

    my $fh = resurrector_fh($path);

    my $abs_path = File::Spec->rel2abs( $path );
    print "Setting %INC entry of $module to $abs_path\n" if INTERNAL_DEBUG;
    $INC{$module} = $abs_path;

    return $fh;
}

###########################################
sub pm_search {
###########################################
    my($pmfile) = @_;

    for(@INC) {
          # Skip subrefs
        next if ref($_);
        my $path = File::Spec->catfile($_, $pmfile);
        return $path if -f $path;
    }

    return undef;
}

###########################################
sub resurrector_init {
###########################################
    unshift @INC, \&resurrector_loader;
}

1;

__END__



#line 215
