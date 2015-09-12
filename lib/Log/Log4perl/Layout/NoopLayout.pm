#line 1 "Log/Log4perl/Layout/NoopLayout.pm"
##################################################
package Log::Log4perl::Layout::NoopLayout;
##################################################


##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;

    return $self;
}

##################################################
sub render {
##################################################
    #my($self, $message, $category, $priority, $caller_level) = @_;
    return $_[1];;
}

1;

__END__



#line 82
