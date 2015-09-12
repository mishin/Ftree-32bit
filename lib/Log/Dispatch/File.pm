#line 1 "Log/Dispatch/File.pm"
package Log::Dispatch::File;

use strict;
use warnings;

our $VERSION = '2.45';

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate SCALAR BOOLEAN);
Params::Validate::validation_options( allow_extra => 1 );

use Scalar::Util qw( openhandle );

# Prevents death later on if IO::File can't export this constant.
*O_APPEND = \&APPEND unless defined &O_APPEND;

sub APPEND {0}

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_make_handle;

    return $self;
}

sub _basic_init {
    my $self = shift;

    $self->SUPER::_basic_init(@_);

    my %p = validate(
        @_, {
            filename => { type => SCALAR },
            mode     => {
                type    => SCALAR,
                default => '>'
            },
            binmode => {
                type    => SCALAR,
                default => undef
            },
            autoflush => {
                type    => BOOLEAN,
                default => 1
            },
            close_after_write => {
                type    => BOOLEAN,
                default => 0
            },
            permissions => {
                type     => SCALAR,
                optional => 1
            },
            syswrite => {
                type    => BOOLEAN,
                default => 0
            },
        }
    );

    $self->{filename}    = $p{filename};
    $self->{binmode}     = $p{binmode};
    $self->{autoflush}   = $p{autoflush};
    $self->{close}       = $p{close_after_write};
    $self->{permissions} = $p{permissions};
    $self->{syswrite}    = $p{syswrite};

    if ( $self->{close} ) {
        $self->{mode} = '>>';
    }
    elsif (
           exists $p{mode}
        && defined $p{mode}
        && (
            $p{mode} =~ /^(?:>>|append)$/
            || (   $p{mode} =~ /^\d+$/
                && $p{mode} == O_APPEND() )
        )
        ) {
        $self->{mode} = '>>';
    }
    else {
        $self->{mode} = '>';
    }

}

sub _make_handle {
    my $self = shift;

    $self->_open_file() unless $self->{close};
}

sub _open_file {
    my $self = shift;

    open my $fh, $self->{mode}, $self->{filename}
        or die "Cannot write to '$self->{filename}': $!";

    if ( $self->{autoflush} ) {
        my $oldfh = select $fh;
        $| = 1;
        select $oldfh;
    }

    if ( $self->{permissions}
        && !$self->{chmodded} ) {
        my $current_mode = ( stat $self->{filename} )[2] & 07777;
        if ( $current_mode ne $self->{permissions} ) {
            chmod $self->{permissions}, $self->{filename}
                or die
                "Cannot chmod $self->{filename} to $self->{permissions}: $!";
        }

        $self->{chmodded} = 1;
    }

    if ( $self->{binmode} ) {
        binmode $fh, $self->{binmode};
    }

    $self->{fh} = $fh;
}

sub log_message {
    my $self = shift;
    my %p    = @_;

    if ( $self->{close} ) {
        $self->_open_file;
    }

    my $fh = $self->{fh};

    if ( $self->{syswrite} ) {
        defined syswrite( $fh, $p{message} )
            or die "Cannot write to '$self->{filename}': $!";
    }
    else {
        print $fh $p{message}
            or die "Cannot write to '$self->{filename}': $!";
    }

    if ( $self->{close} ) {
        close $fh
            or die "Cannot close '$self->{filename}': $!";
    }
}

sub DESTROY {
    my $self = shift;

    if ( $self->{fh} ) {
        my $fh = $self->{fh};
        close $fh if openhandle($fh);
    }
}

1;

# ABSTRACT: Object for logging to files

__END__

#line 286
