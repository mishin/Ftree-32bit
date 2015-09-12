#line 1 "Log/Log4perl/Appender/String.pm"
package Log::Log4perl::Appender::String;
our @ISA = qw(Log::Log4perl::Appender);

##################################################
# Log dispatcher writing to a string buffer
##################################################

##################################################
sub new {
##################################################
    my $proto  = shift;
    my $class  = ref $proto || $proto;
    my %params = @_;

    my $self = {
        name      => "unknown name",
        string    => "",
        %params,
    };

    bless $self, $class;
}

##################################################
sub log {   
##################################################
    my $self = shift;
    my %params = @_;

    $self->{string} .= $params{message};
}

##################################################
sub string {   
##################################################
    my($self, $new) = @_;

    if(defined $new) {
        $self->{string} = $new;
    }

    return $self->{string};
}

1;

__END__



#line 111
