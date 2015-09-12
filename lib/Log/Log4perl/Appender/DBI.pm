#line 1 "Log/Log4perl/Appender/DBI.pm"
package Log::Log4perl::Appender::DBI;

our @ISA = qw(Log::Log4perl::Appender);

use Carp;

use strict;
use DBI;

sub new {
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    $self->_init(%p);

    my %defaults = (
        reconnect_attempts => 1,
        reconnect_sleep    => 0,
    );

    for (keys %defaults) {
        if(exists $p{$_}) {
            $self->{$_} = $p{$_};
        } else {
            $self->{$_} = $defaults{$_};
        }
    }

    #e.g.
    #log4j.appender.DBAppndr.params.1 = %p    
    #log4j.appender.DBAppndr.params.2 = %5.5m
    foreach my $pnum (keys %{$p{params}}){
        $self->{bind_value_layouts}{$pnum} = 
                Log::Log4perl::Layout::PatternLayout->new({
                   ConversionPattern  => {value  => $p{params}->{$pnum}},
                   undef_column_value => undef,
                });
    }
    #'bind_value_layouts' now contains a PatternLayout
    #for each parameter heading for the Sql engine

    $self->{SQL} = $p{sql}; #save for error msg later on

    $self->{MAX_COL_SIZE} = $p{max_col_size};

    $self->{BUFFERSIZE} = $p{bufferSize} || 1; 

    if ($p{usePreparedStmt}) {
        $self->{sth} = $self->create_statement($p{sql});
        $self->{usePreparedStmt} = 1;
    }else{
        $self->{layout} = Log::Log4perl::Layout::PatternLayout->new({
            ConversionPattern  => {value  => $p{sql}},
            undef_column_value => undef,
        });
    }

    if ($self->{usePreparedStmt} &&  $self->{bufferSize}){
        warn "Log4perl: you've defined both usePreparedStmt and bufferSize \n".
        "in your appender '$p{name}'--\n".
        "I'm going to ignore bufferSize and just use a prepared stmt\n";
    }

    return $self;
}


sub _init {
    my $self = shift;
    my %params = @_;

    if ($params{dbh}) {
        $self->{dbh} = $params{dbh};
    } else {
        $self->{connect} = sub {
            DBI->connect(@params{qw(datasource username password)},
                         {PrintError => 0, $params{attrs} ? %{$params{attrs}} : ()})
                            or croak "Log4perl: $DBI::errstr";
        };
        $self->{dbh} = $self->{connect}->();
        $self->{_mine} = 1;
    }
}

sub create_statement {
    my ($self, $stmt) = @_;

    $stmt || croak "Log4perl: sql not set in Log4perl::Appender::DBI";

    return $self->{dbh}->prepare($stmt) || croak "Log4perl: DBI->prepare failed $DBI::errstr\n$stmt";

}


sub log {
    my $self = shift;
    my %p = @_;

    #%p is
    #    { name    => $appender_name,
    #      level   => loglevel
    #      message => $message,
    #      log4p_category => $category,
    #      log4p_level  => $level,);
    #    },

        #getting log4j behavior with no specified ConversionPattern
    chomp $p{message} unless ref $p{message}; 

        
    my $qmarks = $self->calculate_bind_values(\%p);


    if ($self->{usePreparedStmt}) {

        $self->query_execute($self->{sth}, @$qmarks);

    }else{

        #first expand any %x's in the statement
        my $stmt = $self->{layout}->render(
                        $p{message},
                        $p{log4p_category},
                        $p{log4p_level},
                        5 + $Log::Log4perl::caller_depth,  
                        );

        push @{$self->{BUFFER}}, $stmt, $qmarks;

        $self->check_buffer();
    }
}

sub query_execute {
    my($self, $sth, @qmarks) = @_;

    my $errstr = "[no error]";

    for my $attempt (0..$self->{reconnect_attempts}) {
        #warn "Exe: @qmarks"; # TODO
        if(! $sth->execute(@qmarks)) {

                  # save errstr because ping() would override it [RT 56145]
                $errstr = $self->{dbh}->errstr();

                # Exe failed -- was it because we lost the DB
                # connection?
                if($self->{dbh}->ping()) {
                    # No, the connection is ok, we failed because there's
                    # something wrong with the execute(): Bad SQL or 
                    # missing parameters or some such). Abort.
                    croak "Log4perl: DBI appender error: '$errstr'";
                }

                if($attempt == $self->{reconnect_attempts}) {
                    croak "Log4perl: DBI appender failed to " .
                          ($self->{reconnect_attempts} == 1 ? "" : "re") .
                          "connect " .
                          "to database after " .
                          "$self->{reconnect_attempts} attempt" .
                          ($self->{reconnect_attempts} == 1 ? "" : "s") .
                          " (last error error was [$errstr]";
                }
            if(! $self->{dbh}->ping()) {
                # Ping failed, try to reconnect
                if($attempt) {
                    #warn "Sleeping"; # TODO
                    sleep($self->{reconnect_sleep}) if $self->{reconnect_sleep};
                }

                eval {
                    #warn "Reconnecting to DB"; # TODO
                    $self->{dbh} = $self->{connect}->();
                };
            }

            if ($self->{usePreparedStmt}) {
                $sth = $self->create_statement($self->{SQL});
                $self->{sth} = $sth if $self->{sth};
            } else {
                #warn "Pending stmt: $self->{pending_stmt}"; #TODO
                $sth = $self->create_statement($self->{pending_stmt});
            }

            next;
        }
        return 1;
    }
    croak "Log4perl: DBI->execute failed $errstr, \n".
          "on $self->{SQL}\n @qmarks";
}

sub calculate_bind_values {
    my ($self, $p) = @_;

    my @qmarks;
    my $user_ph_idx = 0;

    my $i=0;
    
    if ($self->{bind_value_layouts}) {

        my $prev_pnum = 0;
        my $max_pnum = 0;
    
        my @pnums = sort {$a <=> $b} keys %{$self->{bind_value_layouts}};
        $max_pnum = $pnums[-1];
        
        #Walk through the integers for each possible bind value.
        #If it doesn't have a layout assigned from the config file
        #then shift it off the array from the $log call
        #This needs to be reworked now that we always get an arrayref? --kg 1/2003
        foreach my $pnum (1..$max_pnum){
            my $msg;
    
                #we've got a bind_value_layout to fill the spot
            if ($self->{bind_value_layouts}{$pnum}){
               $msg = $self->{bind_value_layouts}{$pnum}->render(
                        $p->{message},
                        $p->{log4p_category},
                        $p->{log4p_level},
                        5 + $Log::Log4perl::caller_depth,  
                    );

               #we don't have a bind_value_layout, so get
               #a message bit
            }elsif (ref $p->{message} eq 'ARRAY' && @{$p->{message}}){
                #$msg = shift @{$p->{message}};
                $msg = $p->{message}->[$i++];

               #here handle cases where we ran out of message bits
               #before we ran out of bind_value_layouts, just keep going
            }elsif (ref $p->{message} eq 'ARRAY'){
                $msg = undef;
                $p->{message} = undef;

               #here handle cases where we didn't get an arrayref
               #log the message in the first placeholder and nothing in the rest
            }elsif (! ref $p->{message} ){
                $msg = $p->{message};
                $p->{message} = undef;

            }

            if ($self->{MAX_COL_SIZE} &&
                length($msg) > $self->{MAX_COL_SIZE}){
                substr($msg, $self->{MAX_COL_SIZE}) = '';
            }
            push @qmarks, $msg;
        }
    }

    #handle leftovers
    if (ref $p->{message} eq 'ARRAY' && @{$p->{message}} ) {
        #push @qmarks, @{$p->{message}};
        push @qmarks, @{$p->{message}}[$i..@{$p->{message}}-1];

    }

    return \@qmarks;
}


sub check_buffer {
    my $self = shift;

    return unless ($self->{BUFFER} && ref $self->{BUFFER} eq 'ARRAY');

    if (scalar @{$self->{BUFFER}} >= $self->{BUFFERSIZE} * 2) {

        my ($sth, $stmt, $prev_stmt);

        $prev_stmt = ""; # Init to avoid warning (ms 5/10/03)

        while (@{$self->{BUFFER}}) {
            my ($stmt, $qmarks) = splice (@{$self->{BUFFER}},0,2);

            $self->{pending_stmt} = $stmt;

                #reuse the sth if the stmt doesn't change
            if ($stmt ne $prev_stmt) {
                $sth->finish if $sth;
                $sth = $self->create_statement($stmt);
            }

            $self->query_execute($sth, @$qmarks);

            $prev_stmt = $stmt;

        }

        $sth->finish;

        my $dbh = $self->{dbh};

        if ($dbh && ! $dbh->{AutoCommit}) {
            $dbh->commit;
        }
    }
}

sub DESTROY {
    my $self = shift;

    $self->{BUFFERSIZE} = 1;

    $self->check_buffer();

    if ($self->{_mine} && $self->{dbh}) {
        $self->{dbh}->disconnect;
    }
}


1;

__END__



#line 644
