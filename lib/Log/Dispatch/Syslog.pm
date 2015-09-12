#line 1 "Log/Dispatch/Syslog.pm"
package Log::Dispatch::Syslog;

use strict;
use warnings;

our $VERSION = '2.45';

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate ARRAYREF BOOLEAN HASHREF SCALAR);
Params::Validate::validation_options( allow_extra => 1 );

use Scalar::Util qw( reftype );
use Sys::Syslog 0.28 ();

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_init(%p);

    return $self;
}

my ($Ident) = $0 =~ /(.+)/;

sub _init {
    my $self = shift;

    my %p = validate(
        @_, {
            ident => {
                type    => SCALAR,
                default => $Ident
            },
            logopt => {
                type    => SCALAR,
                default => ''
            },
            facility => {
                type    => SCALAR,
                default => 'user'
            },
            socket => {
                type    => SCALAR | ARRAYREF | HASHREF,
                default => undef
            },
            lock => {
                type    => BOOLEAN,
                default => 0,
            },
        }
    );

    $self->{$_} = $p{$_} for qw( ident logopt facility socket lock );
    if ( $self->{lock} ) {
        require threads;
        require threads::shared;
    }

    $self->{priorities} = [
        'DEBUG',
        'INFO',
        'NOTICE',
        'WARNING',
        'ERR',
        'CRIT',
        'ALERT',
        'EMERG'
    ];
}

my $thread_lock : shared = 0;

sub log_message {
    my $self = shift;
    my %p    = @_;

    my $pri = $self->_level_as_number( $p{level} );

    lock($thread_lock) if $self->{lock};

    eval {
        if ( defined $self->{socket} ) {
            Sys::Syslog::setlogsock(
                ref $self->{socket} && reftype( $self->{socket} ) eq 'ARRAY'
                ? @{ $self->{socket} }
                : $self->{socket}
            );
        }

        Sys::Syslog::openlog(
            $self->{ident},
            $self->{logopt},
            $self->{facility}
        );
        Sys::Syslog::syslog( $self->{priorities}[$pri], $p{message} );
        Sys::Syslog::closelog;
    };

    warn $@ if $@ and $^W;
}

1;

# ABSTRACT: Object for logging to system log.

__END__

#line 221
