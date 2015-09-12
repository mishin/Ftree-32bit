#line 1 "LWP/MemberMixin.pm"
package LWP::MemberMixin;

sub _elem
{
    my $self = shift;
    my $elem = shift;
    my $old = $self->{$elem};
    $self->{$elem} = shift if @_;
    return $old;
}

1;

__END__

#line 45