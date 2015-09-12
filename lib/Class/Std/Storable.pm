#line 1 "Class/Std/Storable.pm"
package Class::Std::Storable;

use version; $VERSION = qv('0.0.1');
use strict;
use warnings;
use Class::Std; #get subs from parent to export
use Carp;

#hold attributes by package
my %attributes_of;

my @exported_subs = qw(
    new
    ident
    DESTROY
    MODIFY_HASH_ATTRIBUTES
    MODIFY_CODE_ATTRIBUTES
    AUTOLOAD
    _DUMP
    STORABLE_freeze
    STORABLE_thaw
);

sub import {
    no strict 'refs';
    for my $sub ( @exported_subs ) {
        *{ caller() . '::' . $sub } = \&{$sub};
    }
}

#NOTE: this subroutine should override the one that's imported
#by the "use Class::Std" above.
{
    my $old_sub = \&Class::Std::MODIFY_HASH_ATTRIBUTES;
    my %positional_arg_of;
    my $new_sub = sub {
        my ($package, $referent, @attrs) = @_;
        my @return_attrs = $old_sub->(@_);

        for my $attr (@attrs) {
            next if $attr !~ m/\A ATTRS? \s* (?:[(] (.*) [)] )? \z/xms;
            my $name;
            #we have a backup if no name is given for the attribute.
            $positional_arg_of{$package} ||= "__Positional_0001";
            #but we would prefer to know the argument as the class does.
            if (my $config = $1) {
                $name = Class::Std::_extract_init_arg($config)
                    || Class::Std::_extract_get($config)
                    || Class::Std::_extract_set($config);
            }
            $name ||= $positional_arg_of{$package}++;
            push @{$attributes_of{$package}}, {
                ref      => $referent,
                name     => $name,
            };
        }
        return @return_attrs;
    };

    no warnings; #or this complains about redefining sub
    *MODIFY_HASH_ATTRIBUTES = $new_sub;
};

sub STORABLE_freeze {
    #croak "must be called from Storable" unless caller eq 'Storable';
    #unfortunately, Storable never appears on the call stack.
    my($self, $cloning) = @_;
    $self->STORABLE_freeze_pre($cloning)
        if UNIVERSAL::can($self, "STORABLE_freeze_pre");
    my $id = ident($self);
    require Storable;
    my $serialized = Storable::freeze( \ (my $anon_scalar) );

    my %frozen_attr; #to be constructed
    my @package_list = ref $self;
    my %package_seen = ( ref($self) => 1 ); #ignore diamond/looped base classes :-)
    PACKAGE:
    while( my $package = shift @package_list) {
        #make sure we add any base classes to the list of
        #packages to examine for attributes.
        { no strict 'refs';
            for my $base_class ( @{"${package}::ISA"} ) {
                push @package_list, $base_class
                    if !$package_seen{$base_class}++;
            }
        }
        #examine attributes from known packages only
        my $attr_list_ref = $attributes_of{$package} or next PACKAGE;

        #look for any attributes of this object for this package
        ATTR:
        for my $attr_ref ( @{$attr_list_ref} ) {
            #nothing to do if attr not set for this object
            next ATTR if !exists $attr_ref->{ref}{$id};
            #save the attr by name into the package hash
            $frozen_attr{$package}{ $attr_ref->{name} }
                = $attr_ref->{ref}{$id};
        }
    }

    $self->STORABLE_freeze_post($cloning, \%frozen_attr)
        if UNIVERSAL::can($self, "STORABLE_freeze_post");
    return ($serialized, \%frozen_attr );
}

sub STORABLE_thaw {
    #croak "must be called from Storable" unless caller eq 'Storable';
    #unfortunately, Storable never appears on the call stack.
    my($self, $cloning, $serialized, $frozen_attr_ref) = @_;
    #we can ignore $serialized, as we know it's an anon_scalar.
    $self->STORABLE_thaw_pre($cloning, $frozen_attr_ref)
        if UNIVERSAL::can($self, "STORABLE_thaw_pre");
    my $id = ident($self);
    PACKAGE:
    while( my ($package, $pkg_attr_ref) = each %$frozen_attr_ref ) {
        croak "unknown base class '$package' seen while thawing ".ref($self)
            if ! UNIVERSAL::isa($self, $package);
        my $attr_list_ref = $attributes_of{$package};
        ATTR:
        for my $attr_ref ( @{$attr_list_ref} ) { #for known attrs...
            #nothing to do if frozen attr doesn't exist
            next ATTR if !exists $pkg_attr_ref->{ $attr_ref->{name} };
            #block attempts to meddle with existing objects
            croak "trying to modify existing attributes for $package"
                if exists $attr_ref->{ref}{$id};
            #ok, set the attribute
            $attr_ref->{ref}{$id}
                = delete $pkg_attr_ref->{ $attr_ref->{name} };
        }
        if( my @extra_keys = keys %$pkg_attr_ref ) {
            #this is probably serious enough to throw an exception.
            #however, TODO: it would be nice if the class could somehow
            #indicate to ignore this problem.
            croak "unknown attribute(s) seen while thawing"
                ." class $package: " . join(q{, }, @extra_keys);
        }
    }
    $self->STORABLE_thaw_post($cloning)
        if UNIVERSAL::can($self, "STORABLE_thaw_post");
}

1; # Magic true value required at end of module
__END__

#line 405