#!/usr/bin/perl
#line 2 "Log/Log4perl/Layout/PatternLayout/Multiline.pm"

package Log::Log4perl::Layout::PatternLayout::Multiline;
use base qw(Log::Log4perl::Layout::PatternLayout);

###########################################
sub render {
###########################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    my @messages = split /\r?\n/, $message;

    $caller_level = 0 unless defined $caller_level;

    my $result = '';

    for my $msg ( @messages ) {
        $result .= $self->SUPER::render(
            $msg, $category, $priority, $caller_level + 1
        );
    }
    return $result;
}

1;

__END__



#line 94
