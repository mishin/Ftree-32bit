#line 1 "Log/Log4perl/Util.pm"
package Log::Log4perl::Util;

require Exporter;
our @EXPORT_OK = qw( params_check );
our @ISA       = qw( Exporter );

use File::Spec;

###########################################
sub params_check {
###########################################
    my( $hash, $required, $optional ) = @_;

    my $pkg       = caller();
    my %hash_copy = %$hash;

    if( defined $required ) {
        for my $p ( @$required ) {
            if( !exists $hash->{ $p } or
                !defined $hash->{ $p } ) {
                die "$pkg: Required parameter $p missing.";
            }
            delete $hash_copy{ $p };
        }
    }

    if( defined $optional ) {
        for my $p ( @$optional ) {
            delete $hash_copy{ $p };
        }
        if( scalar keys %hash_copy ) {
            die "$pkg: Unknown parameter: ", join( ",", keys %hash_copy );
        }
    }
}

##################################################
sub module_available {  # Check if a module is available
##################################################
    my($full_name) = @_;

      # Weird cases like "strict;" (including the semicolon) would 
      # succeed with the eval below, so check those up front. 
      # I can't believe Perl doesn't have a proper way to check if a 
      # module is available or not!
    return 0 if $full_name =~ /[^\w:]/;

    local $SIG{__DIE__} = sub {};

    eval "require $full_name";

    if($@) {
        return 0;
    }

    return 1;
}

##################################################
sub tmpfile_name {  # File::Temp without the bells and whistles
##################################################

    my $name = File::Spec->catfile(File::Spec->tmpdir(), 
                              'l4p-tmpfile-' . 
                              "$$-" .
                              int(rand(9999999)));

        # Some crazy versions of File::Spec use backslashes on Win32
    $name =~ s#\\#/#g;
    return $name;
}

1;

__END__



#line 119