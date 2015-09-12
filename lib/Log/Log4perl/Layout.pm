#line 1 "Log/Log4perl/Layout.pm"
package Log::Log4perl::Layout;


use Log::Log4perl::Layout::SimpleLayout;
use Log::Log4perl::Layout::PatternLayout;
use Log::Log4perl::Layout::PatternLayout::Multiline;


####################################################
sub appender_name {
####################################################
    my ($self, $arg) = @_;

    if ($arg) {
        die "setting appender_name unimplemented until it makes sense";
    }
    return $self->{appender_name};
}


##################################################
sub define {
##################################################
    ;  #subclasses may implement
}


##################################################
sub render {
##################################################
    die "subclass must implement render";
}

1;

__END__



#line 93
