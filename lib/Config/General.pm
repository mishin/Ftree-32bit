#line 1 "Config/General.pm"
#
# Config::General.pm - Generic Config Module
#
# Purpose: Provide a convenient way for loading
#          config values from a given file and
#          return it as hash structure
#
# Copyright (c) 2000-2015 Thomas Linden <tlinden |AT| cpan.org>.
# All Rights Reserved. Std. disclaimer applies.
# Artistic License, same as perl itself. Have fun.
#
# namespace
package Config::General;

use strict;
use warnings;
use English '-no_match_vars';

use IO::File;
use FileHandle;
use File::Spec::Functions qw(splitpath file_name_is_absolute catfile catpath);
use File::Glob qw/:glob/;


# on debian with perl > 5.8.4 croak() doesn't work anymore without this.
# There is some require statement which dies 'cause it can't find Carp::Heavy,
# I really don't understand, what the hell they made, but the debian perl
# installation is definitely bullshit, damn!
use Carp::Heavy;


use Carp;
use Exporter;

$Config::General::VERSION = "2.58";

use vars  qw(@ISA @EXPORT_OK);
use base qw(Exporter);
@EXPORT_OK = qw(ParseConfig SaveConfig SaveConfigString);

sub new {
  #
  # create new Config::General object
  #
  my($this, @param ) = @_;
  my $class = ref($this) || $this;

  # define default options
  my $self = {
	      # sha256 of current date
	      # hopefully this lowers the probability that
	      # this matches any configuration key or value out there
	      # bugfix for rt.40925
	      EOFseparator          => 'ad7d7b87f5b81d2a0d5cb75294afeb91aa4801b1f8e8532dc1b633c0e1d47037',
	      SlashIsDirectory      => 0,
	      AllowMultiOptions     => 1,
	      MergeDuplicateOptions => 0,
	      MergeDuplicateBlocks  => 0,
	      LowerCaseNames        => 0,
	      ApacheCompatible      => 0,
	      UseApacheInclude      => 0,
	      IncludeRelative       => 0,
	      IncludeDirectories    => 0,
	      IncludeGlob           => 0,
              IncludeAgain          => 0,
	      AutoLaunder           => 0,
	      AutoTrue              => 0,
	      AutoTrueFlags         => {
					true  => '^(on|yes|true|1)$',
					false => '^(off|no|false|0)$',
				       },
	      DefaultConfig         => {},
	      String                => '',
	      level                 => 1,
	      InterPolateVars       => 0,
	      InterPolateEnv        => 0,
	      ExtendedAccess        => 0,
	      SplitPolicy           => 'guess', # also possible: whitespace, equalsign and custom
	      SplitDelimiter        => 0,       # must be set by the user if SplitPolicy is 'custom'
	      StoreDelimiter        => 0,       # will be set by me unless user uses 'custom' policy
	      CComments             => 1,       # by default turned on
	      BackslashEscape       => 0,       # deprecated
	      StrictObjects         => 1,       # be strict on non-existent keys in OOP mode
	      StrictVars            => 1,       # be strict on undefined variables in Interpolate mode
	      Tie                   => q(),      # could be set to a perl module for tie'ing new hashes
	      parsed                => 0,       # internal state stuff for variable interpolation
	      files                 => {},      # which files we have read, if any
	      UTF8                  => 0,
	      SaveSorted            => 0,
              ForceArray            => 0,       # force single value array if value enclosed in []
              AllowSingleQuoteInterpolation => 0,
              NoEscape              => 0,
              NormalizeBlock        => 0,
              NormalizeOption       => 0,
              NormalizeValue        => 0,
              Plug                  => {}
	     };

  # create the class instance
  bless $self, $class;

  if ($#param >= 1) {
    # use of the new hash interface!
    $self->_prepare(@param);
  }
  elsif ($#param == 0) {
    # use of the old style
    $self->{ConfigFile} = $param[0];
    if (ref($self->{ConfigFile}) eq 'HASH') {
      $self->{ConfigHash} = delete $self->{ConfigFile};
    }
  }
  else {
    # this happens if $#param == -1,1 thus no param was given to new!
    $self->{config} = $self->_hashref();
    $self->{parsed} = 1;
  }

  # find split policy to use for option/value separation
  $self->_splitpolicy();

  # bless into variable interpolation module if necessary
  $self->_blessvars();

  # process as usual
  if (!$self->{parsed}) {
    $self->_process();
  }

  if ($self->{InterPolateVars}) {
    $self->{config} = $self->_clean_stack($self->{config});
  }

  # bless into OOP namespace if required
  $self->_blessoop();

  return $self;
}



sub _process {
  #
  # call _read() and _parse() on the given config
  my($self) = @_;

  if ($self->{DefaultConfig} && $self->{InterPolateVars}) {
    $self->{DefaultConfig} = $self->_interpolate_hash($self->{DefaultConfig}); # FIXME: _hashref() ?
  }
  if (exists $self->{StringContent}) {
    # consider the supplied string as config file
    $self->_read($self->{StringContent}, 'SCALAR');
    $self->{config} = $self->_parse($self->{DefaultConfig}, $self->{content});
  }
  elsif (exists $self->{ConfigHash}) {
    if (ref($self->{ConfigHash}) eq 'HASH') {
      # initialize with given hash
      $self->{config} = $self->{ConfigHash};
      $self->{parsed} = 1;
    }
    else {
      croak "Config::General: Parameter -ConfigHash must be a hash reference!\n";
    }
  }
  elsif (ref($self->{ConfigFile}) eq 'GLOB' || ref($self->{ConfigFile}) eq 'FileHandle') {
    # use the file the glob points to
    $self->_read($self->{ConfigFile});
    $self->{config} = $self->_parse($self->{DefaultConfig}, $self->{content});
  }
  else {
    if ($self->{ConfigFile}) {
      # open the file and read the contents in
      $self->{configfile} = $self->{ConfigFile};
      if ( file_name_is_absolute($self->{ConfigFile}) ) {
	# look if this is an absolute path and save the basename if it is absolute
	my ($volume, $path, undef) = splitpath($self->{ConfigFile});
	$path =~ s#/$##; # remove eventually existing trailing slash
	if (! $self->{ConfigPath}) {
	  $self->{ConfigPath} = [];
	}
	unshift @{$self->{ConfigPath}}, catpath($volume, $path, q());
      }
      $self->_open($self->{configfile});
      # now, we parse immediately, getall simply returns the whole hash
      $self->{config} = $self->_hashref();
      $self->{config} = $self->_parse($self->{DefaultConfig}, $self->{content});
    }
    else {
      # hm, no valid config file given, so try it as an empty object
      $self->{config} = $self->_hashref();
      $self->{parsed} = 1;
    }
  }
}


sub _blessoop {
  #
  # bless into ::Extended if necessary
  my($self) = @_;
  if ($self->{ExtendedAccess}) {
    # we are blessing here again, to get into the ::Extended namespace
    # for inheriting the methods available over there, which we doesn't have.
    bless $self, 'Config::General::Extended';
    eval {
      require Config::General::Extended;
    };
    if ($EVAL_ERROR) {
      croak "Config::General: " . $EVAL_ERROR;
    }
  }
#  return $self;
}

sub _blessvars {
  #
  # bless into ::Interpolated if necessary
  my($self) = @_;
  if ($self->{InterPolateVars} || $self->{InterPolateEnv}) {
    # InterPolateEnv implies InterPolateVars
    $self->{InterPolateVars} = 1;

    # we are blessing here again, to get into the ::InterPolated namespace
    # for inheriting the methods available overthere, which we doesn't have here.
    bless $self, 'Config::General::Interpolated';
    eval {
      require Config::General::Interpolated;
    };
    if ($EVAL_ERROR) {
      croak "Config::General: " . $EVAL_ERROR;
    }
    # pre-compile the variable regexp
    $self->{regex} = $self->_set_regex();
  }
#  return $self;
}


sub _splitpolicy {
  #
  # find out what split policy to use
  my($self) = @_;
  if ($self->{SplitPolicy} ne 'guess') {
    if ($self->{SplitPolicy} eq 'whitespace') {
      $self->{SplitDelimiter} = '\s+';
      if (!$self->{StoreDelimiter}) {
	$self->{StoreDelimiter} = q(   );
      }
    }
    elsif ($self->{SplitPolicy} eq 'equalsign') {
      $self->{SplitDelimiter} = '\s*=\s*';
      if (!$self->{StoreDelimiter}) {
	$self->{StoreDelimiter} = ' = ';
      }
    }
    elsif ($self->{SplitPolicy} eq 'custom') {
      if (! $self->{SplitDelimiter} ) {
	croak "Config::General: SplitPolicy set to 'custom' but no SplitDelimiter set.\n";
      }
    }
    else {
      croak "Config::General: Unsupported SplitPolicy: $self->{SplitPolicy}.\n";
    }
  }
  else {
    if (!$self->{StoreDelimiter}) {
      $self->{StoreDelimiter} = q(   );
    }
  }
}

sub _prepare {
  #
  # prepare the class parameters, mangle them, if there
  # are options to reset or to override, do it here.
  my ($self, %conf) = @_;

  # save the parameter list for ::Extended's new() calls
  $self->{Params} = \%conf;

  # be backwards compatible
  if (exists $conf{-file}) {
    $self->{ConfigFile} = delete $conf{-file};
  }
  if (exists $conf{-hash}) {
    $self->{ConfigHash} = delete $conf{-hash};
  }

  # store input, file, handle, or array
  if (exists $conf{-ConfigFile}) {
    $self->{ConfigFile} = delete $conf{-ConfigFile};
  }
  if (exists $conf{-ConfigHash}) {
    $self->{ConfigHash} = delete $conf{-ConfigHash};
  }

  # store search path for relative configs, if any
  if (exists $conf{-ConfigPath}) {
    my $configpath = delete $conf{-ConfigPath};
    $self->{ConfigPath} = ref $configpath eq 'ARRAY' ? $configpath : [$configpath];
  }

  # handle options which contains values we need (strings, hashrefs or the like)
  if (exists $conf{-String} ) {
    #if (ref(\$conf{-String}) eq 'SCALAR') {
    if (not ref $conf{-String}) {
      if ( $conf{-String}) {
	$self->{StringContent} = $conf{-String};
      }
      delete $conf{-String};
    }
    # re-implement arrayref support, removed after 2.22 as _read were
    # re-organized
    # fixed bug#33385
    elsif(ref($conf{-String}) eq 'ARRAY') {
      $self->{StringContent} = join "\n", @{$conf{-String}};
    }
    else {
      croak "Config::General: Parameter -String must be a SCALAR or ARRAYREF!\n";
    }
    delete $conf{-String};
  }
  if (exists $conf{-Tie}) {
    if ($conf{-Tie}) {
      $self->{Tie} = delete $conf{-Tie};
      $self->{DefaultConfig} = $self->_hashref();
    }
  }

  if (exists $conf{-FlagBits}) {
    if ($conf{-FlagBits} && ref($conf{-FlagBits}) eq 'HASH') {
      $self->{FlagBits} = 1;
      $self->{FlagBitsFlags} = $conf{-FlagBits};
    }
    delete $conf{-FlagBits};
  }

  if (exists $conf{-DefaultConfig}) {
    if ($conf{-DefaultConfig} && ref($conf{-DefaultConfig}) eq 'HASH') {
      $self->{DefaultConfig} = $conf{-DefaultConfig};
    }
    elsif ($conf{-DefaultConfig} && ref($conf{-DefaultConfig}) eq q()) {
      $self->_read($conf{-DefaultConfig}, 'SCALAR');
      $self->{DefaultConfig} = $self->_parse($self->_hashref(), $self->{content});
      $self->{content} = ();
    }
    delete $conf{-DefaultConfig};
  }

  # handle options which may either be true or false
  # allowing "human" logic about what is true and what is not
  foreach my $entry (keys %conf) {
    my $key = $entry;
    $key =~ s/^\-//;
    if (! exists $self->{$key}) {
      croak "Config::General: Unknown parameter: $entry => \"$conf{$entry}\" (key: <$key>)\n";
    }
    if ($conf{$entry} =~ /$self->{AutoTrueFlags}->{true}/io) {
      $self->{$key} = 1;
    }
    elsif ($conf{$entry} =~ /$self->{AutoTrueFlags}->{false}/io) {
      $self->{$key} = 0;
    }
    else {
      # keep it untouched
      $self->{$key} = $conf{$entry};
    }
  }

  if ($self->{MergeDuplicateOptions}) {
    # override if not set by user
    if (! exists $conf{-AllowMultiOptions}) {
      $self->{AllowMultiOptions} = 0;
    }
  }

  if ($self->{ApacheCompatible}) {
    # turn on all apache compatibility options which has
    # been incorporated during the years...
    $self->{UseApacheInclude}   = 1;
    $self->{IncludeRelative}    = 1;
    $self->{IncludeDirectories} = 1;
    $self->{IncludeGlob}        = 1;
    $self->{SlashIsDirectory}   = 1;
    $self->{SplitPolicy}        = 'whitespace';
    $self->{CComments}          = 0;
  }
}

sub getall {
  #
  # just return the whole config hash
  #
  my($this) = @_;
  return (exists $this->{config} ? %{$this->{config}} : () );
}


sub files {
  #
  # return a list of files opened so far
  #
  my($this) = @_;
  return (exists $this->{files} ? keys %{$this->{files}} : () );
}


sub _open {
  #
  # open the config file, or expand a directory or glob
  #
  my($this, $basefile, $basepath) = @_;
  my $cont;

  ($cont, $basefile, $basepath) = $this->_hook('pre_open', $basefile, $basepath);
  return if(!$cont);

  my($fh, $configfile);

  if($basepath) {
    # if this doesn't work we can still try later the global config path to use
    $configfile = catfile($basepath, $basefile);
  }
  else {
    $configfile = $basefile;
  }

  if ($this->{IncludeGlob} and $configfile =~ /[*?\[\{\\]/) {
    # Something like: *.conf (or maybe dir/*.conf) was included; expand it and
    # pass each expansion through this method again.
    my @include = grep { -f $_ } bsd_glob($configfile, GLOB_BRACE | GLOB_QUOTE);

    # applied patch by AlexK fixing rt.cpan.org#41030
    if ( !@include && defined $this->{ConfigPath} ) {
    	foreach my $dir (@{$this->{ConfigPath}}) {
		my ($volume, $path, undef) = splitpath($basefile);
		if ( -d catfile( $dir, $path )  ) {
	    		push @include, grep { -f $_ } bsd_glob(catfile($dir, $basefile), GLOB_BRACE | GLOB_QUOTE);
			last;
		}
    	}
    }

    if (@include == 1) {
      $configfile = $include[0];
    }
    else {
      # Multiple results or no expansion results (which is fine,
      # include foo/* shouldn't fail if there isn't anything matching)
      # rt.cpan.org#79869: local $this->{IncludeGlob};
      for (@include) {
	$this->_open($_);
      }
      return;
    }
  }

  if (!-e $configfile) {
    my $found;
    if (defined $this->{ConfigPath}) {
      # try to find the file within ConfigPath
      foreach my $dir (@{$this->{ConfigPath}}) {
	if( -e catfile($dir, $basefile) ) {
	  $configfile = catfile($dir, $basefile);
	  $found = 1;
	  last; # found it
	}
      }
    }
    if (!$found) {
      my $path_message = defined $this->{ConfigPath} ? q( within ConfigPath: ) . join(q(.), @{$this->{ConfigPath}}) : q();
      croak qq{Config::General The file "$basefile" does not exist$path_message!};
    }
  }

  local ($RS) = $RS;
  if (! $RS) {
    carp(q(\$RS (INPUT_RECORD_SEPARATOR) is undefined.  Guessing you want a line feed character));
    $RS = "\n";
  }

  if (-d $configfile and $this->{IncludeDirectories}) {
    # A directory was included; include all the files inside that directory in ASCII order
    local *INCLUDEDIR;
    opendir INCLUDEDIR, $configfile or croak "Config::General: Could not open directory $configfile!($!)\n";
    my @files = sort grep { -f catfile($configfile, $_) } catfile($configfile, $_), readdir INCLUDEDIR;
    closedir INCLUDEDIR;
    local $this->{CurrentConfigFilePath} = $configfile;
    for (@files) {
      my $file = catfile($configfile, $_);
      if (! exists $this->{files}->{$file} or $this->{IncludeAgain} ) {
        # support re-read if used urged us to do so, otherwise ignore the file
	if ($this->{UTF8}) {
	  $fh = IO::File->new;
	  open( $fh, "<:utf8", $file)
	    or croak "Config::General: Could not open $file in UTF8 mode!($!)\n";
	}
	else {
	  $fh = IO::File->new( $file, 'r') or croak "Config::General: Could not open $file!($!)\n";
	}
	$this->{files}->{"$file"} = 1;
	$this->_read($fh);
      }
      else {
        warn "File $file already loaded.  Use -IncludeAgain to load it again.\n";
      }
    }
  }
  elsif (-d $configfile) {
    croak "Config::General: config file argument is a directory, expecting a file!\n";
  }
  elsif (-e _) {
    if (exists $this->{files}->{$configfile} and not $this->{IncludeAgain}) {
      # do not read the same file twice, just return
      warn "File $configfile already loaded.  Use -IncludeAgain to load it again.\n";
      return;
    }
    else {
      if ($this->{UTF8}) {
	$fh = IO::File->new;
	open( $fh, "<:utf8", $configfile)
	  or croak "Config::General: Could not open $configfile in UTF8 mode!($!)\n";
      }
      else {
	$fh = IO::File->new( "$configfile", 'r')
	  or croak "Config::General: Could not open $configfile!($!)\n";
      }

      $this->{files}->{$configfile}    = 1;

      my ($volume, $path, undef)           = splitpath($configfile);
      local $this->{CurrentConfigFilePath} = catpath($volume, $path, q());

      $this->_read($fh);
    }
  }
  return;
}


sub _read {
  #
  # store the config contents in @content
  # and prepare it somewhat for easier parsing later
  # (comments, continuing lines, and stuff)
  #
  my($this, $fh, $flag) = @_;


  my(@stuff, @content, $c_comment, $longline, $hier, $hierend, @hierdoc);
  local $_ = q();

  if ($flag && $flag eq 'SCALAR') {
    if (ref($fh) eq 'ARRAY') {
      @stuff = @{$fh};
    }
    else {
      @stuff = split /\n/, $fh;
    }
  }
  else {
    @stuff = <$fh>;
  }

  my $cont;
  ($cont, $fh, @stuff) = $this->_hook('pre_read', $fh, @stuff);
  return if(!$cont);

  foreach (@stuff) {
    if ($this->{AutoLaunder}) {
      if (m/^(.*)$/) {
	$_ = $1;
      }
    }

    chomp;


    if ($hier) {
      # inside here-doc, only look for $hierend marker
      if (/^(\s*)\Q$hierend\E\s*$/) {
	my $indent = $1;                 # preserve indentation
	$hier .= ' ' . $this->{EOFseparator}; # bugfix of rt.40925
	                                 # _parse will also preserver indentation
	if ($indent) {
	  foreach (@hierdoc) {
	    s/^$indent//;                # i.e. the end was: "    EOF" then we remove "    " from every here-doc line
	    $hier .= $_ . "\n";          # and store it in $hier
	  }
	}
	else {
	  $hier .= join "\n", @hierdoc;  # there was no indentation of the end-string, so join it 1:1
	}
	push @{$this->{content}}, $hier; # push it onto the content stack
	@hierdoc = ();
	undef $hier;
	undef $hierend;
      }
      else {
	# everything else onto the stack
	push @hierdoc, $_;
      }
      next;
    }

    if ($this->{CComments}) {
      # look for C-Style comments, if activated
      if (/(\s*\/\*.*\*\/\s*)/) {
       # single c-comment on one line
       s/\s*\/\*.*\*\/\s*//;
      }
      elsif (/^\s*\/\*/) {
       # the beginning of a C-comment ("/*"), from now on ignore everything.
       if (/\*\/\s*$/) {
         # C-comment end is already there, so just ignore this line!
         $c_comment = 0;
       }
       else {
         $c_comment = 1;
       }
      }
      elsif (/\*\//) {
       if (!$c_comment) {
         warn "invalid syntax: found end of C-comment without previous start!\n";
       }
       $c_comment = 0;    # the current C-comment ends here, go on
       s/^.*\*\///;       # if there is still stuff, it will be read
      }
      next if($c_comment); # ignore EVERYTHING from now on, IF it IS a C-Comment
    }

    # Remove comments and empty lines
    s/(?<!\\)#.*$//; # .+ => .* bugfix rt.cpan.org#44600
    next if /^\s*#/;
    #next if /^\s*$/;


    # look for multiline option, indicated by a trailing backslash
    if (/(?<!\\)\\$/) {
      chop; # remove trailing backslash
      s/^\s*//;
      $longline .= $_;
      next;
    }

    # transform explicit-empty blocks to conforming blocks
    # rt.cpan.org#80006 added \s* before $/
    if (!$this->{ApacheCompatible} && /\s*<([^\/]+?.*?)\/>\s*$/) {
      my $block = $1;
      if ($block !~ /\"/) {
	if ($block !~ /\s[^\s]/) {
	  # fix of bug 7957, add quotation to pure slash at the
	  # end of a block so that it will be considered as directory
	  # unless the block is already quoted or contains whitespaces
	  # and no quotes.
	  if ($this->{SlashIsDirectory}) {
	    push @{$this->{content}}, '<' . $block . '"/">';
	    next;
	  }
	}
      }
      my $orig  = $_;
      $orig     =~ s/\/>$/>/;
      $block    =~ s/\s\s*.*$//;
      push @{$this->{content}}, $orig, "</${block}>";
      next;
    }


    # look for here-doc identifier
    if ($this->{SplitPolicy} eq 'guess') {
      if (/^\s*([^=]+?)\s*=\s*<<\s*(.+?)\s*$/) {
	# try equal sign (fix bug rt#36607)
	$hier    = $1;  # the actual here-doc variable name
	$hierend = $2;  # the here-doc identifier, i.e. "EOF"
	next;
      }
      elsif (/^\s*(\S+?)\s+<<\s*(.+?)\s*$/) {
	# try whitespace
	$hier    = $1;  # the actual here-doc variable name
	$hierend = $2;  # the here-doc identifier, i.e. "EOF"
	next;
      }
    }
    else {
      # no guess, use one of the configured strict split policies
      if (/^\s*(.+?)($this->{SplitDelimiter})<<\s*(.+?)\s*$/) {
	$hier    = $1;  # the actual here-doc variable name
	$hierend = $3;  # the here-doc identifier, i.e. "EOF"
	next;
      }
    }



    ###
    ### any "normal" config lines from now on
    ###

    if ($longline) {
      # previous stuff was a longline and this is the last line of the longline
      s/^\s*//;
      $longline .= $_;
      push @{$this->{content}}, $longline;    # push it onto the content stack
      undef $longline;
      next;
    }
    else {
      # ignore empty lines
      next if /^\s*$/;

      # look for include statement(s)
      my $incl_file;
      my $path = '';
      if ( $this->{IncludeRelative} and defined $this->{CurrentConfigFilePath}) {
      	$path = $this->{CurrentConfigFilePath};
      }
      elsif (defined $this->{ConfigPath}) {
	# fetch pathname of base config file, assuming the 1st one is the path of it
	$path = $this->{ConfigPath}->[0];
      }

      # bugfix rt.cpan.org#38635: support quoted filenames
      if ($this->{UseApacheInclude}) {
         if (/^\s*include\s*(["'])(.*?)(?<!\\)\1$/i) {
           $incl_file = $2;
         }
         elsif (/^\s*include\s+(.+?)\s*$/i) {
           $incl_file = $1;
         }
      }
      else {
	if (/^\s*<<include\s+(["'])(.+?)>>\\s*$/i) {
	  $incl_file = $2;
	}
        elsif (/^\s*<<include\s+(.+?)>>\s*$/i) {
          $incl_file = $1;
        }
      }

      if ($incl_file) {
	if ( $this->{IncludeRelative} && $path && !file_name_is_absolute($incl_file) ) {
	  # include the file from within location of $this->{configfile}
	  $this->_open( $incl_file, $path );
	}
	else {
	  # include the file from within pwd, or absolute
	  $this->_open($incl_file);
	}
      }
      else {
	# standard entry, (option = value)
	push @{$this->{content}}, $_;
      }

    }

  }

  ($cont, $this->{content}) = $this->_hook('post_read', $this->{content});
  return 1;
}





sub _parse {
  #
  # parse the contents of the file
  #
  my($this, $config, $content) = @_;
  my(@newcontent, $block, $blockname, $chunk,$block_level);
  local $_;

  foreach (@{$content}) {                                  # loop over content stack
    chomp;
    $chunk++;
    $_ =~ s/^\s+//;                                        # strip spaces @ end and begin
    $_ =~ s/\s+$//;

    #
    # build option value assignment, split current input
    # using whitespace, equal sign or optionally here-doc
    # separator EOFseparator
    my ($option,$value);
    if (/$this->{EOFseparator}/) {
      ($option,$value) = split /\s*$this->{EOFseparator}\s*/, $_, 2;   # separated by heredoc-finding in _open()
    }
    else {
      if ($this->{SplitPolicy} eq 'guess') {
	# again the old regex. use equalsign SplitPolicy to get the
	# 2.00 behavior. the new regexes were too odd.
	($option,$value) = split /\s*=\s*|\s+/, $_, 2;
      }
      else {
	# no guess, use one of the configured strict split policies
	($option,$value) = split /$this->{SplitDelimiter}/, $_, 2;
      }
    }

    if($this->{NormalizeOption}) {
      $option = $this->{NormalizeOption}($option);
    }

    if ($value && $value =~ /^"/ && $value =~ /"$/) {
      $value =~ s/^"//;                                    # remove leading and trailing "
      $value =~ s/"$//;
    }
    if (! defined $block) {                                # not inside a block @ the moment
      if (/^<([^\/]+?.*?)>$/) {                            # look if it is a block
	$block = $1;                                       # store block name
	if ($block =~ /^"([^"]+)"$/) {
	  # quoted block, unquote it and do not split
	  $block =~ s/"//g;
	}
	else {
	  # If it is a named block store the name separately; allow the block and name to each be quoted
	  if ($block =~ /^(?:"([^"]+)"|(\S+))(?:\s+(?:"([^"]+)"|(.*)))?$/) {
	    $block = $1 || $2;
	    $blockname = $3 || $4;
	  }
	}
        if($this->{NormalizeBlock}) {
          $block = $this->{NormalizeBlock}($block);
	  if (defined $blockname) {
            $blockname = $this->{NormalizeBlock}($blockname);
            if($blockname eq "") {
              # if, after normalization no blockname is left, remove it
              $blockname = undef;
            }
	  }
        }
	if ($this->{InterPolateVars}) {
	  # interpolate block(name), add "<" and ">" to the key, because
	  # it is sure that such keys does not exist otherwise.
	  $block     = $this->_interpolate($config, "<$block>", $block);
	  if (defined $blockname) {
	    $blockname = $this->_interpolate($config, "<$blockname>", "$blockname");
	  }
	}
	if ($this->{LowerCaseNames}) {
	  $block = lc $block;    # only for blocks lc(), if configured via new()
	}
	$this->{level} += 1;
	undef @newcontent;
	next;
      }
      elsif (/^<\/(.+?)>$/) { # it is an end block, but we don't have a matching block!
	croak "Config::General: EndBlock \"<\/$1>\" has no StartBlock statement (level: $this->{level}, chunk $chunk)!\n";
      }
      else {                                               # insert key/value pair into actual node
	if ($this->{LowerCaseNames}) {
	  $option = lc $option;
	}

	if (exists $config->{$option}) {
	  if ($this->{MergeDuplicateOptions}) {
	    $config->{$option} = $this->_parse_value($config, $option, $value);

	    # bugfix rt.cpan.org#33216
	    if ($this->{InterPolateVars}) {
	      # save pair on local stack
	      $config->{__stack}->{$option} = $config->{$option};
	    }
	  }
	  else {
	    if (! $this->{AllowMultiOptions} ) {
	      # no, duplicates not allowed
	      croak "Config::General: Option \"$option\" occurs more than once (level: $this->{level}, chunk $chunk)!\n";
	    }
	    else {
	      # yes, duplicates allowed
	      if (ref($config->{$option}) ne 'ARRAY') {      # convert scalar to array
		my $savevalue = $config->{$option};
		delete $config->{$option};
		push @{$config->{$option}}, $savevalue;
	      }
	      eval {
		# check if arrays are supported by the underlying hash
		my $i = scalar @{$config->{$option}};
	      };
	      if ($EVAL_ERROR) {
		$config->{$option} = $this->_parse_value($config, $option, $value);
	      }
	      else {
		# it's already an array, just push
		push @{$config->{$option}}, $this->_parse_value($config, $option, $value);
	      }
	    }
	  }
	}
	else {
          if($this->{ForceArray} && defined $value && $value =~ /^\[\s*(.+?)\s*\]$/) {
            # force single value array entry
            push @{$config->{$option}}, $this->_parse_value($config, $option, $1);
          }
          else {
	    # standard config option, insert key/value pair into node
	    $config->{$option} = $this->_parse_value($config, $option, $value);

	    if ($this->{InterPolateVars}) {
	      # save pair on local stack
	      $config->{__stack}->{$option} = $config->{$option};
	    }
          }
	}
      }
    }
    elsif (/^<([^\/]+?.*?)>$/) {    # found a start block inside a block, don't forget it
      $block_level++;               # $block_level indicates wether we are still inside a node
      push @newcontent, $_;         # push onto new content stack for later recursive call of _parse()
    }
    elsif (/^<\/(.+?)>$/) {
      if ($block_level) {           # this endblock is not the one we are searching for, decrement and push
	$block_level--;             # if it is 0, then the endblock was the one we searched for, see below
	push @newcontent, $_;       # push onto new content stack
      }
      else {                        # calling myself recursively, end of $block reached, $block_level is 0
	if (defined $blockname) {
	  # a named block, make it a hashref inside a hash within the current node

	  if (! exists $config->{$block}) {
	    # Make sure that the hash is not created implicitly
	    $config->{$block} = $this->_hashref();

	    if ($this->{InterPolateVars}) {
	      # inherit current __stack to new block
	      $config->{$block}->{__stack} = $this->_copy($config->{__stack});
	    }
	  }

	  if (ref($config->{$block}) eq '') {
	    croak "Config::General: Block <$block> already exists as scalar entry!\n";
	  }
	  elsif (ref($config->{$block}) eq 'ARRAY') {
	    croak "Config::General: Cannot append named block <$block $blockname> to array of scalars!\n"
	         ."Block <$block> or scalar '$block' occurs more than once.\n"
	         ."Turn on -MergeDuplicateBlocks or make sure <$block> occurs only once in the config.\n";
	  }
	  elsif (exists $config->{$block}->{$blockname}) {
	    # the named block already exists, make it an array
	    if ($this->{MergeDuplicateBlocks}) {
	      # just merge the new block with the same name as an existing one into
              # this one.
	      $config->{$block}->{$blockname} = $this->_parse($config->{$block}->{$blockname}, \@newcontent);
	    }
	    else {
	      if (! $this->{AllowMultiOptions}) {
		croak "Config::General: Named block \"<$block $blockname>\" occurs more than once (level: $this->{level}, chunk $chunk)!\n";
	      }
	      else {                                       # preserve existing data
		my $savevalue = $config->{$block}->{$blockname};
		delete $config->{$block}->{$blockname};
		my @ar;
		if (ref $savevalue eq 'ARRAY') {
		  push @ar, @{$savevalue};                   # preserve array if any
		}
		else {
		  push @ar, $savevalue;
		}
		push @ar, $this->_parse( $this->_hashref(), \@newcontent);  # append it
		$config->{$block}->{$blockname} = \@ar;
	      }
	    }
	  }
	  else {
	    # the first occurrence of this particular named block
	    my $tmphash = $this->_hashref();

	    if ($this->{InterPolateVars}) {
	      # inherit current __stack to new block
	      $tmphash->{__stack} = $this->_copy($config->{__stack});
	    }

	    $config->{$block}->{$blockname} = $this->_parse($tmphash, \@newcontent);
	  }
	}
	else {
	  # standard block
	  if (exists $config->{$block}) {
	    if (ref($config->{$block}) eq '') {
	      croak "Config::General: Cannot create hashref from <$block> because there is\n"
		   ."already a scalar option '$block' with value '$config->{$block}'\n";
	    }

	    # the block already exists, make it an array
	    if ($this->{MergeDuplicateBlocks}) {
	      # just merge the new block with the same name as an existing one into
              # this one.
	      $config->{$block} = $this->_parse($config->{$block}, \@newcontent);
            }
            else {
	      if (! $this->{AllowMultiOptions}) {
	        croak "Config::General: Block \"<$block>\" occurs more than once (level: $this->{level}, chunk $chunk)!\n";
	      }
	      else {
		my $savevalue = $config->{$block};
		delete $config->{$block};
		my @ar;
		if (ref $savevalue eq "ARRAY") {
		  push @ar, @{$savevalue};
		}
		else {
		  push @ar, $savevalue;
		}

		# fixes rt#31529
		my $tmphash = $this->_hashref();
		if ($this->{InterPolateVars}) {
		  # inherit current __stack to new block
		  $tmphash->{__stack} = $this->_copy($config->{__stack});
		}

		push @ar, $this->_parse( $tmphash, \@newcontent);

		$config->{$block} = \@ar;
	      }
	    }
	  }
	  else {
	    # the first occurrence of this particular block
	    my $tmphash = $this->_hashref();

	    if ($this->{InterPolateVars}) {
	      # inherit current __stack to new block
	      $tmphash->{__stack} = $this->_copy($config->{__stack});
	    }

	    $config->{$block} = $this->_parse($tmphash, \@newcontent);
	  }
	}
	undef $blockname;
	undef $block;
	$this->{level} -= 1;
	next;
      }
    }
    else { # inside $block, just push onto new content stack
      push @newcontent, $_;
    }
  }
  if ($block) {
    # $block is still defined, which means, that it had
    # no matching endblock!
    croak "Config::General: Block \"<$block>\" has no EndBlock statement (level: $this->{level}, chunk $chunk)!\n";
  }
  return $config;
}


sub _copy {
  #
  # copy the contents of one hash into another
  # to circumvent invalid references
  # fixes rt.cpan.org bug #35122
  my($this, $source) = @_;
  my %hash = ();
  while (my ($key, $value) = each %{$source}) {
    $hash{$key} = $value;
  }
  return \%hash;
}


sub _parse_value {
  #
  # parse the value if value parsing is turned on
  # by either -AutoTrue and/or -FlagBits
  # otherwise just return the given value unchanged
  #
  my($this, $config, $option, $value) =@_;

  my $cont;
  ($cont, $option, $value) = $this->_hook('pre_parse_value', $option, $value);
  return $value if(!$cont);

  # avoid "Use of uninitialized value"
  if (! defined $value) {
    # patch fix rt#54583
    # Return an input undefined value without trying transformations
    return $value;
  }

  if($this->{NormalizeValue}) {
    $value = $this->{NormalizeValue}($value);
  }

  if ($this->{InterPolateVars}) {
    $value = $this->_interpolate($config, $option, $value);
  }

  # make true/false values to 1 or 0 (-AutoTrue)
  if ($this->{AutoTrue}) {
    if ($value =~ /$this->{AutoTrueFlags}->{true}/io) {
      $value = 1;
    }
    elsif ($value =~ /$this->{AutoTrueFlags}->{false}/io) {
      $value = 0;
    }
  }

  # assign predefined flags or undef for every flag | flag ... (-FlagBits)
  if ($this->{FlagBits}) {
    if (exists $this->{FlagBitsFlags}->{$option}) {
      my %__flags = map { $_ => 1 } split /\s*\|\s*/, $value;
      foreach my $flag (keys %{$this->{FlagBitsFlags}->{$option}}) {
	if (exists $__flags{$flag}) {
	  $__flags{$flag} = $this->{FlagBitsFlags}->{$option}->{$flag};
	}
	else {
	  $__flags{$flag} = undef;
	}
      }
      $value = \%__flags;
    }
  }

  if (!$this->{NoEscape}) {
    # are there any escaped characters left? put them out as is
    $value =~ s/\\([\$\\\"#])/$1/g;
  }

  ($cont, $option, $value) = $this->_hook('post_parse_value', $option, $value);
  
  return $value;
}



sub _hook {
  my ($this, $hook, @arguments) = @_;
  if(exists $this->{Plug}->{$hook}) {
    my $sub = $this->{Plug}->{$hook};
    my @hooked = &$sub(@arguments);
    return @hooked;
  }
  return (1, @arguments);
}








sub NoMultiOptions {
  #
  # turn AllowMultiOptions off, still exists for backward compatibility.
  # Since we do parsing from within new(), we must
  # call it again if one turns NoMultiOptions on!
  #
  croak q(Config::General: The NoMultiOptions() method is deprecated. Set 'AllowMultiOptions' to 'no' instead!);
}


sub save {
  #
  # this is the old version of save() whose API interface
  # has been changed. I'm very sorry 'bout this.
  #
  # I'll try to figure out, if it has been called correctly
  # and if yes, feed the call to Save(), otherwise croak.
  #
  my($this, $one, @two) = @_;

  if ( (@two && $one) && ( (scalar @two) % 2 == 0) ) {
    # @two seems to be a hash
    my %h = @two;
    $this->save_file($one, \%h);
  }
  else {
    croak q(Config::General: The save() method is deprecated. Use the new save_file() method instead!);
  }
  return;
}


sub save_file {
  #
  # save the config back to disk
  #
  my($this, $file, $config) = @_;
  my $fh;
  my $config_string;

  if (!$file) {
    croak "Config::General: Filename is required!";
  }
  else {
    if ($this->{UTF8}) {
      $fh = IO::File->new;
      open($fh, ">:utf8", $file)
	or croak "Config::General: Could not open $file in UTF8 mode!($!)\n";
    }
    else {
      $fh = IO::File->new( "$file", 'w')
	or croak "Config::General: Could not open $file!($!)\n";
    }
    if (!$config) {
      if (exists $this->{config}) {
	$config_string = $this->_store(0, $this->{config});
      }
      else {
	croak "Config::General: No config hash supplied which could be saved to disk!\n";
      }
    }
    else {
      $config_string = $this->_store(0, $config);
    }

    if ($config_string) {
      print {$fh} $config_string;
    }
    else {
      # empty config for whatever reason, I don't care
      print {$fh} q();
    }

    close $fh;
  }
  return;
}



sub save_string {
  #
  # return the saved config as a string
  #
  my($this, $config) = @_;

  if (!$config || ref($config) ne 'HASH') {
    if (exists $this->{config}) {
      return $this->_store(0, $this->{config});
    }
    else {
      croak "Config::General: No config hash supplied which could be saved to disk!\n";
    }
  }
  else {
    return $this->_store(0, $config);
  }
  return;
}



sub _store {
  #
  # internal sub for saving a block
  #
  my($this, $level, $config) = @_;
  local $_;
  my $indent = q(    ) x $level;

  my $config_string = q();

  foreach my $entry ( $this->{SaveSorted} ? sort keys %$config : keys %$config ) {
    # fix rt#104548
    if ($entry =~ /[<>\n\r]/) {
      croak "Config::General: current key contains invalid characters: $entry!\n";
    }

    if (ref($config->{$entry}) eq 'ARRAY') {
      if( $this->{ForceArray} && scalar @{$config->{$entry}} == 1 && ! ref($config->{$entry}->[0]) ) {
        # a single value array forced to stay as array
        $config_string .= $this->_write_scalar($level, $entry, '[' . $config->{$entry}->[0] . ']');
      }
      else {
        foreach my $line ( $this->{SaveSorted} ? sort @{$config->{$entry}} : @{$config->{$entry}} ) {
          if (ref($line) eq 'HASH') {
            $config_string .= $this->_write_hash($level, $entry, $line);
          }
          else {
            $config_string .= $this->_write_scalar($level, $entry, $line);
          }
        }
      }
    }
    elsif (ref($config->{$entry}) eq 'HASH') {
      $config_string .= $this->_write_hash($level, $entry, $config->{$entry});
    }
    else {
      $config_string .= $this->_write_scalar($level, $entry, $config->{$entry});
    }
  }

  return $config_string;
}


sub _write_scalar {
  #
  # internal sub, which writes a scalar
  # it returns it, in fact
  #
  my($this, $level, $entry, $line) = @_;

  my $indent = q(    ) x $level;

  my $config_string;

  # patch fix rt#54583
  if ( ! defined $line ) {
    $config_string .= $indent . $entry . "\n";
  }
  elsif ($line =~ /\n/ || $line =~ /\\$/) {
    # it is a here doc
    my $delimiter;
    my $tmplimiter = 'EOF';
    while (!$delimiter) {
      # create a unique here-doc identifier
      if ($line =~ /$tmplimiter/s) {
	$tmplimiter .= '%';
      }
      else {
	$delimiter = $tmplimiter;
      }
    }
    my @lines = split /\n/, $line;
    $config_string .= $indent . $entry . $this->{StoreDelimiter} . "<<$delimiter\n";
    foreach (@lines) {
      $config_string .= $indent . $_ . "\n";
    }
    $config_string .= $indent . "$delimiter\n";
  }
  else {
    # a simple stupid scalar entry

    if (!$this->{NoEscape}) {
      # re-escape contained $ or # or \ chars
      $line =~ s/([#\$\\\"])/\\$1/g;
    }

    # bugfix rt.cpan.org#42287
    if ($line =~ /^\s/ or $line =~ /\s$/) {
      # need to quote it
      $line = "\"$line\"";
    }
    $config_string .= $indent . $entry . $this->{StoreDelimiter} . $line . "\n";
  }

  return $config_string;
}

sub _write_hash {
  #
  # internal sub, which writes a hash (block)
  # it returns it, in fact
  #
  my($this, $level, $entry, $line) = @_;

  my $indent = q(    ) x $level;
  my $config_string;

  if ($entry =~ /\s/) {
    # quote the entry if it contains whitespaces
    $entry = q(") . $entry . q(");
  }

  # check if the next level key points to a hash and is the only one
  # in this case put out a named block
  # fixes rt.77667
  my $num = scalar keys %{$line};
  if($num == 1) {
    my $key = (keys %{$line})[0];
    if(ref($line->{$key}) eq 'HASH') {
      $config_string .= $indent . qq(<$entry $key>\n);
      $config_string .= $this->_store($level + 1, $line->{$key});
      $config_string .= $indent . qq(</) . $entry . ">\n";
      return $config_string;
    }
  }
 
  $config_string .= $indent . q(<) . $entry . ">\n";
  $config_string .= $this->_store($level + 1, $line);
  $config_string .= $indent . q(</) . $entry . ">\n";

  return $config_string
}


sub _hashref {
  #
  # return a probably tied new empty hash ref
  #
  my($this) = @_;
  if ($this->{Tie}) {
    eval {
      eval qq{require $this->{Tie}};
    };
    if ($EVAL_ERROR) {
      croak q(Config::General: Could not create a tied hash of type: ) . $this->{Tie} . q(: ) . $EVAL_ERROR;
    }
    my %hash;
    tie %hash, $this->{Tie};
    return \%hash;
  }
  else {
    return {};
  }
}



#
# Procedural interface
#
sub ParseConfig {
  #
  # @_ may contain everything which is allowed for new()
  #
  return (new Config::General(@_))->getall();
}

sub SaveConfig {
  #
  # 2 parameters are required, filename and hash ref
  #
  my ($file, $hash) = @_;

  if (!$file || !$hash) {
    croak q{Config::General::SaveConfig(): filename and hash argument required.};
  }
  else {
    if (ref($hash) ne 'HASH') {
      croak q(Config::General::SaveConfig() The second parameter must be a reference to a hash!);
    }
    else {
      (new Config::General(-ConfigHash => $hash))->save_file($file);
    }
  }
  return;
}

sub SaveConfigString {
  #
  # same as SaveConfig, but return the config,
  # instead of saving it
  #
  my ($hash) = @_;

  if (!$hash) {
    croak q{Config::General::SaveConfigString(): Hash argument required.};
  }
  else {
    if (ref($hash) ne 'HASH') {
      croak q(Config::General::SaveConfigString() The parameter must be a reference to a hash!);
    }
    else {
      return (new Config::General(-ConfigHash => $hash))->save_string();
    }
  }
  return;
}



# keep this one
1;
__END__





#line 2759

