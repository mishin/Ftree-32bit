#line 1 "Log/Log4perl/Config/BaseConfigurator.pm"
package Log::Log4perl::Config::BaseConfigurator;

use warnings;
use strict;
use constant _INTERNAL_DEBUG => 0;

*eval_if_perl      = \&Log::Log4perl::Config::eval_if_perl;
*compile_if_perl   = \&Log::Log4perl::Config::compile_if_perl;
*leaf_path_to_hash = \&Log::Log4perl::Config::leaf_path_to_hash;

################################################
sub new {
################################################
    my($class, %options) = @_;

    my $self = { 
        utf8 => 0,
        %options,
    };

    bless $self, $class;

    $self->file($self->{file}) if exists $self->{file};
    $self->text($self->{text}) if exists $self->{text};

    return $self;
}

################################################
sub text {
################################################
    my($self, $text) = @_;

        # $text is an array of scalars (lines)
    if(defined $text) {
        if(ref $text eq "ARRAY") {
            $self->{text} = $text;
        } else {
            $self->{text} = [split "\n", $text];
        }
    }

    return $self->{text};
}

################################################
sub file {
################################################
    my($self, $filename) = @_;

    open my $fh, "$filename" or die "Cannot open $filename ($!)";

    if( $self->{ utf8 } ) {
        binmode $fh, ":utf8";
    }

    $self->file_h_read( $fh );
    close $fh;
}

################################################
sub file_h_read {
################################################
    my($self, $fh) = @_;

        # Dennis Gregorovic <dgregor@redhat.com> added this
        # to protect apps which are tinkering with $/ globally.
    local $/ = "\n";

    $self->{text} = [<$fh>];
}

################################################
sub parse {
################################################
    die __PACKAGE__ . "::parse() is a virtual method. " .
        "It must be implemented " .
        "in a derived class (currently: ", ref(shift), ")";
}

################################################
sub parse_post_process {
################################################
    my($self, $data, $leaf_paths) = @_;
    
    #   [
    #     'category',
    #     'value',
    #     'WARN, Logfile'
    #   ],
    #   [
    #     'appender',
    #     'Logfile',
    #     'value',
    #     'Log::Log4perl::Appender::File'
    #   ],
    #   [
    #     'appender',
    #     'Logfile',
    #     'filename',
    #     'value',
    #     'test.log'
    #   ],
    #   [
    #     'appender',
    #     'Logfile',
    #     'layout',
    #     'value',
    #     'Log::Log4perl::Layout::PatternLayout'
    #   ],
    #   [
    #     'appender',
    #     'Logfile',
    #     'layout',
    #     'ConversionPattern',
    #     'value',
    #     '%d %F{1} %L> %m %n'
    #   ]

    for my $path ( @{ Log::Log4perl::Config::leaf_paths( $data )} ) {

        print "path=@$path\n" if _INTERNAL_DEBUG;

        if(0) {
        } elsif( 
            $path->[0] eq "appender" and
            $path->[2] eq "trigger"
          ) {
            my $ref = leaf_path_to_hash( $path, $data );
            my $code = compile_if_perl( $$ref );

            if(_INTERNAL_DEBUG) {
                if($code) {
                    print "Code compiled: $$ref\n";
                } else {
                    print "Not compiled: $$ref\n";
                }
            }

            $$ref = $code if defined $code;
        } elsif (
            $path->[0] eq "filter"
          ) {
            # do nothing
        } elsif (
            $path->[0] eq "appender" and
            $path->[2] eq "warp_message"
          ) {
            # do nothing
        } elsif (
            $path->[0] eq "appender" and
            $path->[3] eq "cspec" or
            $path->[1] eq "cspec"
          ) {
              # could be either
              #    appender appndr layout cspec
              # or 
              #    PatternLayout cspec U value ...
              #
            # do nothing
        } else {
            my $ref = leaf_path_to_hash( $path, $data );

            if(_INTERNAL_DEBUG) {
                print "Calling eval_if_perl on $$ref\n";
            }

            $$ref = eval_if_perl( $$ref );
        }
    }

    return $data;
}

1;

__END__



#line 346
