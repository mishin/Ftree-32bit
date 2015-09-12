#line 1 "Log/Log4perl/Appender/Socket.pm"
##################################################
package Log::Log4perl::Appender::Socket;
##################################################
our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;

use IO::Socket::INET;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name            => "unknown name",
        silent_recovery => 0,
        no_warning      => 0,
        PeerAddr        => "localhost",
        Proto           => 'tcp',
        Timeout         => 5,
        @options,
    };

    bless $self, $class;

    unless ($self->{defer_connection}){
        unless($self->connect(@options)) {
            if($self->{silent_recovery}) {
                if( ! $self->{no_warning}) {
                    warn "Connect to $self->{PeerAddr}:$self->{PeerPort} failed: $!";
                }
               return $self;
            }
            die "Connect to $self->{PeerAddr}:$self->{PeerPort} failed: $!";
        }

        $self->{socket}->autoflush(1); 
        #autoflush has been the default behavior since 1997
    }

    return $self;
}
    
##################################################
sub connect {
##################################################
    my($self, @options) = @_;

    $self->{socket} = IO::Socket::INET->new(@options);

    return $self->{socket};
}

##################################################
sub log {
##################################################
    my($self, %params) = @_;


    {
            # If we were never able to establish
            # a connection, try to establish one 
            # here. If it fails, return.
        if(($self->{silent_recovery} or $self->{defer_connection}) and 
           !defined $self->{socket}) {
            if(! $self->connect(%$self)) {
                return undef;
            }
        }
  
            # Try to send the message across
        eval { $self->{socket}->send($params{message}); 
             };

        if($@) {
            warn "Send to " . ref($self) . " failed ($@), retrying once...";
            if($self->connect(%$self)) {
                redo;
            }
            if($self->{silent_recovery}) {
                return undef;
            }
            warn "Reconnect to $self->{PeerAddr}:$self->{PeerPort} " .
                 "failed: $!";
            return undef;
        }
    };

    return 1;
}

##################################################
sub DESTROY {
##################################################
    my($self) = @_;

    undef $self->{socket};
}

1;

__END__



#line 227
