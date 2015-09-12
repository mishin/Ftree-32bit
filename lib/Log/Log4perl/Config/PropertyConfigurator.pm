#line 1 "Log/Log4perl/Config/PropertyConfigurator.pm"
package Log::Log4perl::Config::PropertyConfigurator;
use Log::Log4perl::Config::BaseConfigurator;

use warnings;
use strict;

our @ISA = qw(Log::Log4perl::Config::BaseConfigurator);

our %NOT_A_MULT_VALUE = map { $_ => 1 }
    qw(conversionpattern);

#poor man's export
*eval_if_perl = \&Log::Log4perl::Config::eval_if_perl;
*compile_if_perl = \&Log::Log4perl::Config::compile_if_perl;
*unlog4j      = \&Log::Log4perl::Config::unlog4j;

use constant _INTERNAL_DEBUG => 0;

our $COMMENT_REGEX = qr/[#;!]/;

################################################
sub parse {
################################################
    my($self, $newtext) = @_;

    $self->text($newtext) if defined $newtext;

    my $text = $self->{text};

    die "Config parser has nothing to parse" unless defined $text;

    my $data = {};
    my %var_subst = ();

    while (@$text) {
        local $_ = shift @$text;
        s/^\s*$COMMENT_REGEX.*//;
        next unless /\S/;
    
        my @parts = ();

        while (/(.+?)\\\s*$/) {
            my $prev = $1;
            my $next = shift(@$text);
            $next =~ s/^ +//g;  #leading spaces
            $next =~ s/^$COMMENT_REGEX.*//;
            $_ = $prev. $next;
            chomp;
        }

        if(my($key, $val) = /(\S+?)\s*=\s*(.*)/) {

            my $key_org = $key;

            $val =~ s/\s+$//;

                # Everything could potentially be a variable assignment
            $var_subst{$key} = $val;

                # Substitute any variables
            $val =~ s/\$\{(.*?)\}/
                      Log::Log4perl::Config::var_subst($1, \%var_subst)/gex;

            $key = unlog4j($key);

            my $how_deep = 0;
            my $ptr = $data;
            for my $part (split /\.|::/, $key) {
                push @parts, $part;
                $ptr->{$part} = {} unless exists $ptr->{$part};
                $ptr = $ptr->{$part};
                ++$how_deep;
            }

            #here's where we deal with turning multiple values like this:
            # log4j.appender.jabbender.to = him@a.jabber.server
            # log4j.appender.jabbender.to = her@a.jabber.server
            #into an arrayref like this:
            #to => { value => 
            #       ["him\@a.jabber.server", "her\@a.jabber.server"] },
            # 
            # This only is allowed for properties of appenders
            # not listed in %NOT_A_MULT_VALUE (see top of file).
            if (exists $ptr->{value} && 
                $how_deep > 2 &&
                defined $parts[0] && lc($parts[0]) eq "appender" && 
                defined $parts[2] && ! exists $NOT_A_MULT_VALUE{lc($parts[2])}
               ) {
                if (ref ($ptr->{value}) ne 'ARRAY') {
                    my $temp = $ptr->{value};
                    $ptr->{value} = [];
                    push (@{$ptr->{value}}, $temp);
                }
                push (@{$ptr->{value}}, $val);
            }else{
                if(defined $ptr->{value}) {
                    if(! $Log::Log4perl::Logger::NO_STRICT) {
                        die "$key_org redefined";
                    }
                }
                $ptr->{value} = $val;
            }
        }
    }
    $self->{data} = $data;
    return $data;
}

################################################
sub value {
################################################
  my($self, $path) = @_;

  $path = unlog4j($path);

  my @p = split /::/, $path;

  my $found = 0;
  my $r = $self->{data};

  while (my $n = shift @p) {
      if (exists $r->{$n}) {
          $r = $r->{$n};
          $found = 1;
      } else {
          $found = 0;
      }
  }

  if($found and exists $r->{value}) {
      return $r->{value};
  } else {
      return undef;
  }
}

1;

__END__



#line 221
