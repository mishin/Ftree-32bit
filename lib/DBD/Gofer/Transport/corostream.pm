#line 1 "DBD/Gofer/Transport/corostream.pm"
package DBD::Gofer::Transport::corostream;

use strict;
use warnings;

use Carp;

use Coro::Select; #  a slow but coro-aware replacement for CORE::select (global effect!)

use Coro;
use Coro::Handle;

use base qw(DBD::Gofer::Transport::stream);

# XXX ensure DBI_PUREPERL for parent doesn't pass to child
sub start_pipe_command {
    local $ENV{DBI_PUREPERL} = $ENV{DBI_PUREPERL_COROCHILD}; # typically undef
    my $connection = shift->SUPER::start_pipe_command(@_);
    return $connection;
}



1;

__END__

#line 145
