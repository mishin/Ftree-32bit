#line 1 "Log/Log4perl/Appender/TestBuffer.pm"
package Log::Log4perl::Appender::TestBuffer;
our @ISA = qw(Log::Log4perl::Appender);

##################################################
# Log dispatcher writing to a string buffer
# For testing.
# This is like having a Log::Log4perl::Appender::TestBuffer
##################################################

our %POPULATION       = ();
our $LOG_PRIORITY     = 0;
our $DESTROY_MESSAGES = "";

##################################################
sub new {
##################################################
    my $proto  = shift;
    my $class  = ref $proto || $proto;
    my %params = @_;

    my $self = {
        name      => "unknown name",
        %params,
    };

    bless $self, $class;

    $self->{stderr} = exists $params{stderr} ? $params{stderr} : 1;
    $self->{buffer} = "";

    $POPULATION{$self->{name}} = $self;

    return $self;
}

##################################################
sub log {   
##################################################
    my $self = shift;
    my %params = @_;

    if( !defined $params{level} ) {
        die "No level defined in log() call of " . __PACKAGE__;
    }
    $self->{buffer} .= "[$params{level}]: " if $LOG_PRIORITY;
    $self->{buffer} .= $params{message};
}

###########################################
sub clear {
###########################################
    my($self) = @_;

    $self->{buffer} = "";
}

##################################################
sub buffer {   
##################################################
    my($self, $new) = @_;

    if(defined $new) {
        $self->{buffer} = $new;
    }

    return $self->{buffer};
}

##################################################
sub reset {   
##################################################
    my($self) = @_;

    %POPULATION = ();
    $self->{buffer} = "";
}

##################################################
sub DESTROY {   
##################################################
    my($self) = @_;

    $DESTROY_MESSAGES .= __PACKAGE__ . " destroyed";

    #this delete() along with &reset() above was causing
    #Attempt to free unreferenced scalar at 
    #blib/lib/Log/Log4perl/TestBuffer.pm line 69.
    #delete $POPULATION{$self->name};
}

##################################################
sub by_name {   
##################################################
    my($self, $name) = @_;

    # Return a TestBuffer by appender name. This is useful if
    # test buffers are created behind our back (e.g. via the
    # Log4perl config file) and later on we want to 
    # retrieve an instance to query its content.

    die "No name given"  unless defined $name;

    return $POPULATION{$name};

}

1;

__END__



#line 190
