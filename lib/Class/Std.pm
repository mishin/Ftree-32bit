#line 1 "Class/Std.pm"
package Class::Std;

our $VERSION = '0.013';
use strict;
use warnings;
use Carp;
use Scalar::Util;

use overload;

BEGIN { *ID = \&Scalar::Util::refaddr; }

my (%attribute, %cumulative, %anticumulative, %restricted, %private, %overload);

my @exported_subs = qw(
    new
    DESTROY
    AUTOLOAD
    _DUMP
);

my @exported_extension_subs = qw(
    MODIFY_HASH_ATTRIBUTES
    MODIFY_CODE_ATTRIBUTES
);

sub import {
    my $caller = caller;

    no strict 'refs';
    *{ $caller . '::ident'   } = \&Scalar::Util::refaddr;
    for my $sub ( @exported_subs ) {
        *{ $caller . '::' . $sub } = \&{$sub};
    }
    for my $sub ( @exported_extension_subs ) {
        my $target = $caller . '::' . $sub;
        my $real_sub = *{ $target }{CODE} || sub { return @_[2..$#_] };
        no warnings 'redefine';
        *{ $target } = sub {
            my ($package, $referent, @unhandled) = @_;
            for my $handler ($sub, $real_sub) {
                next if !@unhandled;
                @unhandled = $handler->($package, $referent, @unhandled);
            }
            return @unhandled;
        };
    }
}

sub _find_sub {
    my ($package, $sub_ref) = @_;
    no strict 'refs';
    for my $name (keys %{$package.'::'}) {
        my $candidate = *{$package.'::'.$name}{CODE};
        return $name if $candidate && $candidate == $sub_ref;
    }
    croak q{Can't make anonymous subroutine cumulative};
}

sub _raw_str {
    my ($pat) = @_;
    return qr{ ('$pat') | ("$pat")
             | qq? (?:
                     /($pat)/ | \{($pat)\} | \(($pat)\) | \[($pat)\] | <($pat)>
                   )
             }xms;
}

sub _str {
    my ($pat) = @_;
    return qr{ '($pat)' | "($pat)"
             | qq? (?:
                     /($pat)/ | \{($pat)\} | \(($pat)\) | \[($pat)\] | <($pat)>
                   )
             }xms;
}

sub _extractor_for_pair_named {
    my ($key, $raw) = @_;

    $key = qr{\Q$key\E};
    my $str_key = _str($key);

    my $LDAB = "(?:\x{AB})";
    my $RDAB = "(?:\x{BB})";

    my $STR = $raw ? _raw_str( qr{.*?} ) : _str( qr{.*?} );
    my $NUM = qr{ ( [-+]? (?:\d+\.?\d*|\.\d+) (?:[eE]\d+)? ) }xms;

    my $matcher = qr{ :$key<  \s* ([^>]*) \s* >
                    | :$key$LDAB  \s* ([^$RDAB]*) \s* $RDAB
                    | :$key\( \s*  (?:$STR | $NUM )   \s* \)
                    | (?: $key | $str_key ) \s* => \s* (?: $STR | $NUM )
                    }xms;

    return sub { return $_[0] =~ $matcher ? $+ : undef };
}

BEGIN {
    *_extract_default  = _extractor_for_pair_named('default','raw');
    *_extract_init_arg = _extractor_for_pair_named('init_arg');
    *_extract_get      = _extractor_for_pair_named('get');
    *_extract_set      = _extractor_for_pair_named('set');
    *_extract_name     = _extractor_for_pair_named('name');
}

sub MODIFY_HASH_ATTRIBUTES {
    my ($package, $referent, @attrs) = @_;
    for my $attr (@attrs) {
        next if $attr !~ m/\A ATTRS? \s* (?: \( (.*) \) )? \z/xms;
        my ($default, $init_arg, $getter, $setter, $name);
        if (my $config = $1) {
            $default  = _extract_default($config);
            $name     = _extract_name($config);
            $init_arg = _extract_init_arg($config) || $name;

            if ($getter = _extract_get($config) || $name) {
                no strict 'refs';
                *{$package.'::get_'.$getter} = sub {
                    return $referent->{ID($_[0])};
                }
            }
            if ($setter = _extract_set($config) || $name) {
                no strict 'refs';
                *{$package.'::set_'.$setter} = sub {
                    croak "Missing new value in call to 'set_$setter' method"
                        unless @_ == 2;
                    my ($self, $new_val) = @_;
                    my $old_val = $referent->{ID($self)};
                    $referent->{ID($self)} = $new_val;
                    return $old_val;
                }
            }
        }
        undef $attr;
        push @{$attribute{$package}}, {
            ref      => $referent,
            default  => $default,
            init_arg => $init_arg,
            name     => $name || $init_arg || $getter || $setter || '????',
        };
    }
    return grep {defined} @attrs;
}

sub _DUMP {
    my ($self) = @_;
    my $id = ID($self);

    my %dump;
    for my $package (keys %attribute) { 
        my $attr_list_ref = $attribute{$package};
        for my $attr_ref ( @{$attr_list_ref} ) {
            next if !exists $attr_ref->{ref}{$id};
            $dump{$package}{$attr_ref->{name}} = $attr_ref->{ref}{$id};
        }
    }

    require Data::Dumper;
    my $dump = Data::Dumper::Dumper(\%dump);
    $dump =~ s/^.{8}//gxms;
    return $dump;
}

my $STD_OVERLOADER
    = q{ package %%s;
         use overload (
            q{%s} => sub { $_[0]->%%s($_[0]->ident()) },
            fallback => 1
         );
       };

my %OVERLOADER_FOR = (
    STRINGIFY => sprintf( $STD_OVERLOADER, q{""}   ),
    NUMERIFY  => sprintf( $STD_OVERLOADER, q{0+}   ),
    BOOLIFY   => sprintf( $STD_OVERLOADER, q{bool} ),
    SCALARIFY => sprintf( $STD_OVERLOADER, q{${}}  ),
    ARRAYIFY  => sprintf( $STD_OVERLOADER, q{@{}}  ),
    HASHIFY   => sprintf( $STD_OVERLOADER, q{%%{}} ),  # %% to survive sprintf
    GLOBIFY   => sprintf( $STD_OVERLOADER, q{*{}}  ),
    CODIFY    => sprintf( $STD_OVERLOADER, q{&{}}  ),
);

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $referent, @attrs) = @_;
    for my $attr (@attrs) {
        if ($attr eq 'CUMULATIVE') {
            push @{$cumulative{$package}}, $referent;
        }
        elsif ($attr =~ m/\A CUMULATIVE \s* [(] \s* BASE \s* FIRST \s* [)] \z/xms) {
            push @{$anticumulative{$package}}, $referent;
        }
        elsif ($attr =~ m/\A RESTRICTED \z/xms) {
            push @{$restricted{$package}}, $referent;
        }
        elsif ($attr =~ m/\A PRIVATE \z/xms) {
            push @{$private{$package}}, $referent;
        }
        elsif (exists $OVERLOADER_FOR{$attr}) {
            push @{$overload{$package}}, [$referent, $attr];
        }
        undef $attr;
    }
    return grep {defined} @attrs;
}

my %_hierarchy_of;

sub _hierarchy_of {
    my ($class) = @_;

    return @{$_hierarchy_of{$class}} if exists $_hierarchy_of{$class};

    no strict 'refs';

    my @hierarchy = $class;
    my @parents   = @{$class.'::ISA'};

    while (defined (my $parent = shift @parents)) {
        push @hierarchy, $parent;
        push @parents, @{$parent.'::ISA'};
    }

    my %seen;
    return @{$_hierarchy_of{$class}}
        = sort { $a->isa($b) ? -1
               : $b->isa($a) ? +1
               :                0
               } grep !$seen{$_}++, @hierarchy;
}

my %_reverse_hierarchy_of;

sub _reverse_hierarchy_of {
    my ($class) = @_;

    return @{$_reverse_hierarchy_of{$class}}
        if exists $_reverse_hierarchy_of{$class};

    no strict 'refs';

    my @hierarchy = $class;
    my @parents   = reverse @{$class.'::ISA'};

    while (defined (my $parent = shift @parents)) {
        push @hierarchy, $parent;
        push @parents, reverse @{$parent.'::ISA'};
    }

    my %seen;
    return @{$_reverse_hierarchy_of{$class}}
        = reverse sort { $a->isa($b) ? -1
                       : $b->isa($a) ? +1
                       :                0
                       } grep !$seen{$_}++, @hierarchy;
}

{
    no warnings qw( void );
    CHECK { initialize() }
}

sub initialize {
    # Short-circuit if nothing to do...
    return if keys(%restricted) + keys(%private)
            + keys(%cumulative) + keys(%anticumulative)
            + keys(%overload)
                == 0;

    my (%cumulative_named, %anticumulative_named);

    # Implement restricted methods (only callable within hierarchy)...
    for my $package (keys %restricted) {
        for my $sub_ref (@{$restricted{$package}}) {
            my $name = _find_sub($package, $sub_ref);
            no warnings 'redefine';
            no strict 'refs';
            my $sub_name = $package.'::'.$name;
            my $original = *{$sub_name}{CODE}
                or croak "Restricted method ${package}::$name() declared ",
                         'but not defined';
            *{$sub_name} = sub {
                my $caller;
                my $level = 0;
                while ($caller = caller($level++)) {
                     last if $caller !~ /^(?: Class::Std | attributes )$/xms;
                }
                goto &{$original} if !$caller || $caller->isa($package)
                                              || $package->isa($caller);
                croak "Can't call restricted method $sub_name() from class $caller";
            }
        }
    }

    # Implement private methods (only callable from class itself)...
    for my $package (keys %private) {
        for my $sub_ref (@{$private{$package}}) {
            my $name = _find_sub($package, $sub_ref);
            no warnings 'redefine';
            no strict 'refs';
            my $sub_name = $package.'::'.$name;
            my $original = *{$sub_name}{CODE}
                or croak "Private method ${package}::$name() declared ",
                         'but not defined';
            *{$sub_name} = sub {
                my $caller = caller;
                goto &{$original} if $caller eq $package;
                croak "Can't call private method $sub_name() from class $caller";
            }
        }
    }

    for my $package (keys %cumulative) {
        for my $sub_ref (@{$cumulative{$package}}) {
            my $name = _find_sub($package, $sub_ref);
            $cumulative_named{$name}{$package} = $sub_ref;
            no warnings 'redefine';
            no strict 'refs';
            *{$package.'::'.$name} = sub {
                my @args = @_;
                my $class = ref($_[0]) || $_[0];
                my $list_context = wantarray; 
                my (@results, @classes);
                for my $parent (_hierarchy_of($class)) {
                    my $sub_ref = $cumulative_named{$name}{$parent} or next;
                    ${$parent.'::AUTOLOAD'} = our $AUTOLOAD if $name eq 'AUTOLOAD';
                    if (!defined $list_context) {
                        $sub_ref->(@args);
                        next;
                    }
                    push @classes, $parent;
                    if ($list_context) {
                        push @results, $sub_ref->(@args);
                    }
                    else {
                        push @results, scalar $sub_ref->(@args);
                    }
                }
                return if !defined $list_context;
                return @results if $list_context;
                return Class::Std::SCR->new({
                    values  => \@results,
                    classes => \@classes,
                });
            };
        }
    }

    for my $package (keys %anticumulative) {
        for my $sub_ref (@{$anticumulative{$package}}) {
            my $name = _find_sub($package, $sub_ref);
            if ($cumulative_named{$name}) {
                for my $other_package (keys %{$cumulative_named{$name}}) {
                    next unless $other_package->isa($package)
                             || $package->isa($other_package);
                    print STDERR
                        "Conflicting definitions for cumulative method",
                        " '$name'\n",
                        "(specified as :CUMULATIVE in class '$other_package'\n",
                        " but declared :CUMULATIVE(BASE FIRST) in class ",
                        " '$package')\n";
                    exit(1);
                }
            }
            $anticumulative_named{$name}{$package} = $sub_ref;
            no warnings 'redefine';
            no strict 'refs';
            *{$package.'::'.$name} = sub {
                my $class = ref($_[0]) || $_[0];
                my $list_context = wantarray; 
                my (@results, @classes);
                for my $parent (_reverse_hierarchy_of($class)) {
                    my $sub_ref = $anticumulative_named{$name}{$parent} or next;
                    if (!defined $list_context) {
                        &{$sub_ref};
                        next;
                    }
                    push @classes, $parent;
                    if ($list_context) {
                        push @results, &{$sub_ref};
                    }
                    else {
                        push @results, scalar &{$sub_ref};
                    }
                }
                return if !defined $list_context;
                return @results if $list_context;
                return Class::Std::SCR->new({
                    values  => \@results,
                    classes => \@classes,
                });
            };
        }
    }

    for my $package (keys %overload) {
        foreach my $operation (@{ $overload{$package} }) {
            my ($referent, $attr) = @$operation;
            local $^W;
            my $method = _find_sub($package, $referent);
            eval sprintf $OVERLOADER_FOR{$attr}, $package, $method;
            die "Internal error: $@" if $@;
        }
    }

    # Remove initialization data to prevent re-initializations...
    %restricted     = ();
    %private        = ();
    %cumulative     = ();
    %anticumulative = ();
    %overload       = ();
}

sub new {
    my ($class, $arg_ref) = @_;

    Class::Std::initialize();   # Ensure run-time (and mod_perl) setup is done

    no strict 'refs';
    croak "Can't find class $class" if ! keys %{$class.'::'};

    croak "Argument to $class->new() must be hash reference"
        if @_ > 1 && ref $arg_ref ne 'HASH';

    my $new_obj = bless \my($anon_scalar), $class;
    my $new_obj_id = ID($new_obj);
    my (@missing_inits, @suss_keys);

    $arg_ref ||= {};
    my %arg_set;
    BUILD: for my $base_class (_reverse_hierarchy_of($class)) {
        my $arg_set = $arg_set{$base_class}
            = { %{$arg_ref}, %{$arg_ref->{$base_class}||{}} };

        # Apply BUILD() methods...
        {
            no warnings 'once';
            if (my $build_ref = *{$base_class.'::BUILD'}{CODE}) {
                $build_ref->($new_obj, $new_obj_id, $arg_set);
            }
        }

        # Apply init_arg and default for attributes still undefined...
        INITIALIZATION:
        for my $attr_ref ( @{$attribute{$base_class}} ) {
            next INITIALIZATION if defined $attr_ref->{ref}{$new_obj_id};

            # Get arg from initializer list...
            if (defined $attr_ref->{init_arg}
                && exists $arg_set->{$attr_ref->{init_arg}}) {
                $attr_ref->{ref}{$new_obj_id} = $arg_set->{$attr_ref->{init_arg}};

                next INITIALIZATION;
            }
            elsif (defined $attr_ref->{default}) {
                # Or use default value specified...
                $attr_ref->{ref}{$new_obj_id} = eval $attr_ref->{default};

                if ($@) {
                    $attr_ref->{ref}{$new_obj_id} = $attr_ref->{default};
                }

                next INITIALIZATION;
            }

            if (defined $attr_ref->{init_arg}) {
                # Record missing init_arg...
                push @missing_inits, 
                     "Missing initializer label for $base_class: "
                     . "'$attr_ref->{init_arg}'.\n";
                push @suss_keys, keys %{$arg_set};
            }
        }
    }

    croak @missing_inits, _mislabelled(@suss_keys),
          'Fatal error in constructor call'
                if @missing_inits;

    # START methods run after all BUILD methods complete...
    for my $base_class (_reverse_hierarchy_of($class)) {
        my $arg_set = $arg_set{$base_class};

        # Apply START() methods...
        {
            no warnings 'once';
            if (my $init_ref = *{$base_class.'::START'}{CODE}) {
                $init_ref->($new_obj, $new_obj_id, $arg_set);
            }
        }
    }

    return $new_obj;
}

sub uniq (@) {
    my %seen;
    return grep { $seen{$_}++ } @_;
}


sub _mislabelled {
    my (@names) = map { qq{'$_'} } uniq @_;

    return q{} if @names == 0;

    my $arglist
        = @names == 1 ? $names[0]
        : @names == 2 ? join q{ or }, @names
        :               join(q{, }, @names[0..$#names-1]) . ", or $names[-1]"
        ;
    return "(Did you mislabel one of the args you passed: $arglist?)\n";
}

sub DESTROY {
    my ($self) = @_;
    my $id = ID($self);
    push @_, $id;

    for my $base_class (_hierarchy_of(ref $_[0])) {
        no strict 'refs';
        if (my $demolish_ref = *{$base_class.'::DEMOLISH'}{CODE}) {
            &{$demolish_ref};
        }

        for my $attr_ref ( @{$attribute{$base_class}} ) {
            delete $attr_ref->{ref}{$id};
        }
    }
}

sub AUTOLOAD {
    my ($invocant) = @_;
    my $invocant_class = ref $invocant || $invocant;
    my ($package_name, $method_name) = our $AUTOLOAD =~ m/ (.*) :: (.*) /xms;

    my $ident = ID($invocant);
    if (!defined $ident) { $ident = $invocant }

    for my $parent_class ( _hierarchy_of($invocant_class) ) {
        no strict 'refs';
        if (my $automethod_ref = *{$parent_class.'::AUTOMETHOD'}{CODE}) {
            local $CALLER::_ = $_;
            local $_ = $method_name;
            if (my $method_impl
                    = $automethod_ref->($invocant, $ident, @_[1..$#_])) {
                goto &$method_impl;
            }
        }
    }

    my $type = ref $invocant ? 'object' : 'class';
    croak qq{Can't locate $type method "$method_name" via package "$package_name"};
}

{
    my $real_can = \&UNIVERSAL::can;
    no warnings 'redefine', 'once';
    *UNIVERSAL::can = sub {
        my ($invocant, $method_name) = @_;

        if ( defined $invocant ) {
            if (my $sub_ref = $real_can->(@_)) {
                return $sub_ref;
            }

            for my $parent_class ( _hierarchy_of(ref $invocant || $invocant) ) {
                no strict 'refs';
                if (my $automethod_ref = *{$parent_class.'::AUTOMETHOD'}{CODE}) {
                    local $CALLER::_ = $_;
                    local $_ = $method_name;
                    if (my $method_impl = $automethod_ref->(@_)) {
                        return sub { my $inv = shift; $inv->$method_name(@_) }
                    }
                }
            }
        }

        return;
    };
}

package Class::Std::SCR;
use base qw( Class::Std );

our $VERSION = '0.013';

BEGIN { *ID = \&Scalar::Util::refaddr; }

my %values_of  : ATTR( :init_arg<values> );
my %classes_of : ATTR( :init_arg<classes> );

sub new {
    my ($class, $opt_ref) = @_;
    my $new_obj = bless \do{my $scalar}, $class;
    my $new_obj_id = ID($new_obj);
    $values_of{$new_obj_id}  = $opt_ref->{values};
    $classes_of{$new_obj_id} = $opt_ref->{classes};
    return $new_obj;
}

use overload (
    q{""}  => sub { return join q{}, grep { defined $_ } @{$values_of{ID($_[0])}}; },
    q{0+}  => sub { return scalar @{$values_of{ID($_[0])}};    },
    q{@{}} => sub { return $values_of{ID($_[0])};              },
    q{%{}} => sub {
        my ($self) = @_;
        my %hash;
        @hash{@{$classes_of{ID($self)}}} = @{$values_of{ID($self)}};
        return \%hash;
    },
    fallback => 1,
);

1; # Magic true value required at end of module
__END__



#line 2318
