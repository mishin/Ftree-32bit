#line 1 "Log/Log4perl/Config/Watch.pm"
package Log::Log4perl::Config::Watch;

use constant _INTERNAL_DEBUG => 0;

our $NEXT_CHECK_TIME;
our $SIGNAL_CAUGHT;

our $L4P_TEST_CHANGE_DETECTED;
our $L4P_TEST_CHANGE_CHECKED;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = { file            => "",
                 check_interval  => 30,
                 l4p_internal    => 0,
                 signal          => undef,
                 %options,
                 _last_checked_at => 0,
                 _last_timestamp  => 0,
               };

    bless $self, $class;

    if($self->{signal}) {
            # We're in signal mode, set up the handler
        print "Setting up signal handler for '$self->{signal}'\n" if
            _INTERNAL_DEBUG;

        # save old signal handlers; they belong to other appenders or
        # possibly something else in the consuming application
        my $old_sig_handler = $SIG{$self->{signal}};
        $SIG{$self->{signal}} = sub { 
            print "Caught $self->{signal} signal\n" if _INTERNAL_DEBUG;
            $self->force_next_check();
            $old_sig_handler->(@_) if $old_sig_handler and ref $old_sig_handler eq 'CODE';
        };
            # Reset the marker. The handler is going to modify it.
        $self->{signal_caught} = 0;
        $SIGNAL_CAUGHT = 0 if $self->{l4p_internal};
    } else {
            # Just called to initialize
        $self->change_detected(undef, 1);
        $self->file_has_moved(undef, 1);
    }

    return $self;
}

###########################################
sub force_next_check {
###########################################
    my($self) = @_;

    $self->{signal_caught}   = 1;
    $self->{next_check_time} = 0;

    if( $self->{l4p_internal} ) {
        $SIGNAL_CAUGHT = 1;
        $NEXT_CHECK_TIME = 0;
    }
}

###########################################
sub force_next_check_reset {
###########################################
    my($self) = @_;

    $self->{signal_caught} = 0;
    $SIGNAL_CAUGHT = 0 if $self->{l4p_internal};
}

###########################################
sub file {
###########################################
    my($self) = @_;

    return $self->{file};
}

###########################################
sub signal {
###########################################
    my($self) = @_;

    return $self->{signal};
}

###########################################
sub check_interval {
###########################################
    my($self) = @_;

    return $self->{check_interval};
}

###########################################
sub file_has_moved {
###########################################
    my($self, $time, $force) = @_;

    my $task = sub {
        my @stat = stat($self->{file});

        my $has_moved = 0;

        if(! $stat[0]) {
            # The file's gone, obviously it got moved or deleted.
            print "File is gone\n" if _INTERNAL_DEBUG;
            return 1;
        }

        my $current_inode = "$stat[0]:$stat[1]";
        print "Current inode: $current_inode\n" if _INTERNAL_DEBUG;

        if(exists $self->{_file_inode} and 
            $self->{_file_inode} ne $current_inode) {
            print "Inode changed from $self->{_file_inode} to ",
                  "$current_inode\n" if _INTERNAL_DEBUG;
            $has_moved = 1;
        }

        $self->{_file_inode} = $current_inode;
        return $has_moved;
    };

    return $self->check($time, $task, $force);
}

###########################################
sub change_detected {
###########################################
    my($self, $time, $force) = @_;

    my $task = sub {
        my @stat = stat($self->{file});
        my $new_timestamp = $stat[9];

        $L4P_TEST_CHANGE_CHECKED = 1;

        if(! defined $new_timestamp) {
            if($self->{l4p_internal}) {
                # The file is gone? Let it slide, we don't want L4p to re-read
                # the config now, it's gonna die.
                return undef;
            }
            $L4P_TEST_CHANGE_DETECTED = 1;
            return 1;
        }

        if($new_timestamp > $self->{_last_timestamp}) {
            $self->{_last_timestamp} = $new_timestamp;
            print "Change detected (file=$self->{file} store=$new_timestamp)\n"
                  if _INTERNAL_DEBUG;
            $L4P_TEST_CHANGE_DETECTED = 1;
            return 1; # Has changed
        }
           
        print "$self->{file} unchanged (file=$new_timestamp ",
              "stored=$self->{_last_timestamp})!\n" if _INTERNAL_DEBUG;
        return "";  # Hasn't changed
    };

    return $self->check($time, $task, $force);
}

###########################################
sub check {
###########################################
    my($self, $time, $task, $force) = @_;

    $time = time() unless defined $time;

    if( $self->{signal_caught} or $SIGNAL_CAUGHT ) {
       $force = 1;
       $self->force_next_check_reset();
       print "Caught signal, forcing check\n" if _INTERNAL_DEBUG;

    }

    print "Soft check (file=$self->{file} time=$time)\n" if _INTERNAL_DEBUG;

        # Do we need to check?
    if(!$force and
       $self->{_last_checked_at} + 
       $self->{check_interval} > $time) {
        print "No need to check\n" if _INTERNAL_DEBUG;
        return ""; # don't need to check, return false
    }
       
    $self->{_last_checked_at} = $time;

    # Set global var for optimizations in case we just have one watcher
    # (like in Log::Log4perl)
    $self->{next_check_time} = $time + $self->{check_interval};
    $NEXT_CHECK_TIME = $self->{next_check_time} if $self->{l4p_internal};

    print "Hard check (file=$self->{file} time=$time)\n" if _INTERNAL_DEBUG;
    return $task->($time);
}

1;

__END__



#line 354
