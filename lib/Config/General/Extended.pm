#line 1 "Config/General/Extended.pm"
#
# Config::General::Extended - special Class based on Config::General
#
# Copyright (c) 2000-2014 Thomas Linden <tlinden |AT| cpan.org>.
# All Rights Reserved. Std. disclaimer applies.
# Artistic License, same as perl itself. Have fun.
#

# namespace
package Config::General::Extended;

# yes we need the hash support of new() in 1.18 or higher!
use Config::General 1.18;

use FileHandle;
use Carp;
use Exporter ();
use vars qw(@ISA @EXPORT);

# inherit new() and so on from Config::General
@ISA = qw(Config::General Exporter);

use strict;


$Config::General::Extended::VERSION = "2.07";


sub new {
  croak "Deprecated method Config::General::Extended::new() called.\n"
       ."Use Config::General::new() instead and set the -ExtendedAccess flag.\n";
}


sub getbypath {
  my ($this, $path) = @_;
  my $xconfig = $this->{config};
  $path =~ s#^/##;
  $path =~ s#/$##;
  my @pathlist = split /\//, $path;
  my $index;
  foreach my $element (@pathlist) {
    if($element =~ /^([^\[]*)\[(\d+)\]$/) {
      $element = $1;
      $index   = $2;
    }
    else {
      $index = undef;
    }

    if(ref($xconfig) eq "ARRAY") {
      return {};
    }
    elsif (! exists $xconfig->{$element}) {
      return {};
    }

    if(ref($xconfig->{$element}) eq "ARRAY") {
      if(! defined($index) ) {
        #croak "$element is an array but you didn't specify an index to access it!\n";
        $xconfig = $xconfig->{$element};
      }
      else {
        if(exists $xconfig->{$element}->[$index]) {
          $xconfig = $xconfig->{$element}->[$index];
        }
        else {
          croak "$element doesn't have an element with index $index!\n";
        }
      }
    }
    else {
      $xconfig = $xconfig->{$element};
    }
  }

  return $xconfig;
}

sub obj {
  #
  # returns a config object from a given key
  # or from the current config hash if the $key does not exist
  # or an empty object if the content of $key is empty.
  #
  my($this, $key) = @_;

  # just create the empty object, just in case
  my $empty = $this->SUPER::new( -ExtendedAccess => 1, -ConfigHash => {}, %{$this->{Params}} );

  if (exists $this->{config}->{$key}) {
    if (!$this->{config}->{$key}) {
      # be cool, create an empty object!
      return $empty
    }
    elsif (ref($this->{config}->{$key}) eq "ARRAY") {
      my @objlist;
      foreach my $element (@{$this->{config}->{$key}}) {
	if (ref($element) eq "HASH") {
	  push @objlist,
	    $this->SUPER::new( -ExtendedAccess => 1,
			       -ConfigHash     => $element,
			       %{$this->{Params}} );
	}
	else {
	  if ($this->{StrictObjects}) {
	    croak "element in list \"$key\" does not point to a hash reference!\n";
	  }
	  # else: skip this element
	}
      }
      return \@objlist;
    }
    elsif (ref($this->{config}->{$key}) eq "HASH") {
      return $this->SUPER::new( -ExtendedAccess => 1,
				-ConfigHash => $this->{config}->{$key}, %{$this->{Params}} );
    }
    else {
      # nothing supported
      if ($this->{StrictObjects}) {
	croak "key \"$key\" does not point to a hash reference!\n";
      }
      else {
	# be cool, create an empty object!
	return $empty;
      }
    }
  }
  else {
    # even return an empty object if $key does not exist
    return $empty;
  }
}


sub value {
  #
  # returns a value of the config hash from a given key
  # this can be a hashref or a scalar
  #
  my($this, $key, $value) = @_;
  if (defined $value) {
    $this->{config}->{$key} = $value;
  }
  else {
    if (exists $this->{config}->{$key}) {
      return $this->{config}->{$key};
    }
    else {
      if ($this->{StrictObjects}) {
	croak "Key \"$key\" does not exist within current object\n";
      }
      else {
	return "";
      }
    }
  }
}


sub hash {
  #
  # returns a value of the config hash from a given key
  # as hash
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    return %{$this->{config}->{$key}};
  }
  else {
    if ($this->{StrictObjects}) {
      croak "Key \"$key\" does not exist within current object\n";
    }
    else {
      return ();
    }
  }
}


sub array {
  #
  # returns a value of the config hash from a given key
  # as array
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    return @{$this->{config}->{$key}};
  }
  if ($this->{StrictObjects}) {
      croak "Key \"$key\" does not exist within current object\n";
    }
  else {
    return ();
  }
}



sub is_hash {
  #
  # return true if the given key contains a hashref
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    if (ref($this->{config}->{$key}) eq "HASH") {
      return 1;
    }
    else {
      return;
    }
  }
  else {
    return;
  }
}



sub is_array {
  #
  # return true if the given key contains an arrayref
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    if (ref($this->{config}->{$key}) eq "ARRAY") {
      return 1;
    }
    else {
      return;
    }
  }
  else {
    return;
  }
}


sub is_scalar {
  #
  # returns true if the given key contains a scalar(or number)
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key} && !ref($this->{config}->{$key})) {
    return 1;
  }
  return;
}



sub exists {
  #
  # returns true if the key exists
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    return 1;
  }
  else {
    return;
  }
}


sub keys {
  #
  # returns all keys under in the hash of the specified key, if
  # it contains keys (so it must be a hash!)
  #
  my($this, $key) = @_;
  if (!$key) {
    if (ref($this->{config}) eq "HASH") {
      return map { $_ } keys %{$this->{config}};
    }
    else {
      return ();
    }
  }
  elsif (exists $this->{config}->{$key} && ref($this->{config}->{$key}) eq "HASH") {
    return map { $_ } keys %{$this->{config}->{$key}};
  }
  else {
    return ();
  }
}


sub delete {
  #
  # delete the given key from the config, if any
  # and return what is deleted (just as 'delete $hash{key}' does)
  #
  my($this, $key) = @_;
  if (exists $this->{config}->{$key}) {
    return delete $this->{config}->{$key};
  }
  else {
    return undef;
  }
}




sub configfile {
  #
  # sets or returns the config filename
  #
  my($this,$file) = @_;
  if ($file) {
    $this->{configfile} = $file;
  }
  return $this->{configfile};
}

sub find {
  my $this = shift;
  my $key = shift;
  return undef unless $this->exists($key);
  if (@_) {
    return $this->obj($key)->find(@_);
  }
  else {
    return $this->obj($key);
  }
}

sub AUTOLOAD {
  #
  # returns the representing value, if it is a scalar.
  #
  my($this, $value) = @_;
  my $key = $Config::General::Extended::AUTOLOAD;  # get to know how we were called
  $key =~ s/.*:://; # remove package name!

  if (defined $value) {
    # just set $key to $value!
    $this->{config}->{$key} = $value;
  }
  elsif (exists $this->{config}->{$key}) {
    if ($this->is_hash($key)) {
      croak "Key \"$key\" points to a hash and cannot be automatically accessed\n";
    }
    elsif ($this->is_array($key)) {
      croak "Key \"$key\" points to an array and cannot be automatically accessed\n";
    }
    else {
      return $this->{config}->{$key};
    }
  }
  else {
    if ($this->{StrictObjects}) {
      croak "Key \"$key\" does not exist within current object\n";
    }
    else {
      # be cool
      return undef; # bugfix rt.cpan.org#42331
    }
  }
}

sub DESTROY {
  my $this = shift;
  $this = ();
}

# keep this one
1;





#line 663

