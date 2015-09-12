#line 1 "Log/Dispatch.pm"
package Log::Dispatch;

use 5.006;

use strict;
use warnings;

our $VERSION = '2.45';

use base qw( Log::Dispatch::Base );

use Module::Runtime qw( use_package_optimistically );
use Params::Validate 0.15 qw(validate_with ARRAYREF CODEREF);
use Carp ();

our %LEVELS;

BEGIN {
    my %level_map = (
        (
            map { $_ => $_ }
                qw(
                debug
                info
                notice
                warning
                error
                critical
                alert
                emergency
                )
        ),
        warn  => 'warning',
        err   => 'error',
        crit  => 'critical',
        emerg => 'emergency',
    );

    foreach my $l ( keys %level_map ) {
        my $sub = sub {
            my $self = shift;
            $self->log(
                level   => $level_map{$l},
                message => @_ > 1 ? "@_" : $_[0],
            );
        };

        $LEVELS{$l} = 1;

        no strict 'refs';
        *{$l} = $sub;
    }
}

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = validate_with(
        params => \@_,
        spec   => {
            outputs   => { type => ARRAYREF,           optional => 1 },
            callbacks => { type => ARRAYREF | CODEREF, optional => 1 }
        },
        allow_extra => 1,    # for backward compatibility
    );

    my $self = bless {}, $class;

    my @cb = $self->_get_callbacks(%p);
    $self->{callbacks} = \@cb if @cb;

    if ( my $outputs = $p{outputs} ) {
        if ( ref $outputs->[1] eq 'HASH' ) {

            # 2.23 API
            # outputs => [
            #   File => { min_level => 'debug', filename => 'logfile' },
            #   Screen => { min_level => 'warning' }
            # ]
            while ( my ( $class, $params ) = splice @$outputs, 0, 2 ) {
                $self->_add_output( $class, %$params );
            }
        }
        else {

            # 2.24+ syntax
            # outputs => [
            #   [ 'File',   min_level => 'debug', filename => 'logfile' ],
            #   [ 'Screen', min_level => 'warning' ]
            # ]
            foreach my $arr (@$outputs) {
                die "expected arrayref, not '$arr'"
                    unless ref $arr eq 'ARRAY';
                $self->_add_output(@$arr);
            }
        }
    }

    return $self;
}

sub clone {
    my $self = shift;

    my %clone = (
        callbacks => [ @{ $self->{callbacks} || [] } ],
        outputs   => { %{ $self->{outputs}   || {} } },
    );

    return bless \%clone, ref $self;
}

sub _add_output {
    my $self  = shift;
    my $class = shift;

    my $full_class
        = substr( $class, 0, 1 ) eq '+'
        ? substr( $class, 1 )
        : "Log::Dispatch::$class";

    use_package_optimistically($full_class);

    $self->add( $full_class->new(@_) );
}

sub add {
    my $self   = shift;
    my $object = shift;

    # Once 5.6 is more established start using the warnings module.
    if ( exists $self->{outputs}{ $object->name } && $^W ) {
        Carp::carp(
            "Log::Dispatch::* object ", $object->name,
            " already exists."
        );
    }

    $self->{outputs}{ $object->name } = $object;
}

sub remove {
    my $self = shift;
    my $name = shift;

    return delete $self->{outputs}{$name};
}

sub outputs {
    my $self = shift;

    return values %{ $self->{outputs} };
}

sub callbacks {
    my $self = shift;

    return @{ $self->{callbacks} };
}

sub log {
    my $self = shift;
    my %p    = @_;

    return unless $self->would_log( $p{level} );

    $self->_log_to_outputs( $self->_prepare_message(%p) );
}

sub _prepare_message {
    my $self = shift;
    my %p    = @_;

    $p{message} = $p{message}->()
        if ref $p{message} eq 'CODE';

    $p{message} = $self->_apply_callbacks(%p)
        if $self->{callbacks};

    return %p;
}

sub _log_to_outputs {
    my $self = shift;
    my %p    = @_;

    foreach ( keys %{ $self->{outputs} } ) {
        $p{name} = $_;
        $self->_log_to(%p);
    }
}

sub log_and_die {
    my $self = shift;

    my %p = $self->_prepare_message(@_);

    $self->_log_to_outputs(%p) if $self->would_log( $p{level} );

    $self->_die_with_message(%p);
}

sub log_and_croak {
    my $self = shift;

    $self->log_and_die( @_, carp_level => 3 );
}

sub _die_with_message {
    my $self = shift;
    my %p    = @_;

    my $msg = $p{message};

    local $Carp::CarpLevel = ( $Carp::CarpLevel || 0 ) + $p{carp_level}
        if exists $p{carp_level};

    Carp::croak($msg);
}

sub log_to {
    my $self = shift;
    my %p    = @_;

    $p{message} = $self->_apply_callbacks(%p)
        if $self->{callbacks};

    $self->_log_to(%p);
}

sub _log_to {
    my $self = shift;
    my %p    = @_;
    my $name = $p{name};

    if ( exists $self->{outputs}{$name} ) {
        $self->{outputs}{$name}->log(@_);
    }
    elsif ($^W) {
        Carp::carp(
            "Log::Dispatch::* object named '$name' not in dispatcher\n");
    }
}

sub output {
    my $self = shift;
    my $name = shift;

    return unless exists $self->{outputs}{$name};

    return $self->{outputs}{$name};
}

sub level_is_valid {
    shift;
    my $level = shift
        or Carp::croak('Logging level was not provided');

    return $LEVELS{$level};
}

sub would_log {
    my $self  = shift;
    my $level = shift;

    return 0 unless $self->level_is_valid($level);

    foreach ( values %{ $self->{outputs} } ) {
        return 1 if $_->_should_log($level);
    }

    return 0;
}

sub is_debug     { $_[0]->would_log('debug') }
sub is_info      { $_[0]->would_log('info') }
sub is_notice    { $_[0]->would_log('notice') }
sub is_warning   { $_[0]->would_log('warning') }
sub is_warn      { $_[0]->would_log('warn') }
sub is_error     { $_[0]->would_log('error') }
sub is_err       { $_[0]->would_log('err') }
sub is_critical  { $_[0]->would_log('critical') }
sub is_crit      { $_[0]->would_log('crit') }
sub is_alert     { $_[0]->would_log('alert') }
sub is_emerg     { $_[0]->would_log('emerg') }
sub is_emergency { $_[0]->would_log('emergency') }

1;

# ABSTRACT: Dispatches messages to one or more outputs

__END__

#line 756
