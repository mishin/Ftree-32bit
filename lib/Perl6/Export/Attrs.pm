#line 1 "Perl6/Export/Attrs.pm"
 package Perl6::Export::Attrs;

use version; $VERSION = qv('0.0.3');

use warnings;
use strict;
use Carp;
use Attribute::Handlers;

sub import {
    my $caller = caller;
    no strict 'refs';
    *{$caller.'::import'} = \&_generic_import;
    *{$caller.'::MODIFY_CODE_ATTRIBUTES'} = \&_generic_MCA;
    return;
}

my %tagsets_for;
my %is_exported_from;
my %named_tagsets_for;

my $IDENT = '[^\W\d]\w*';

sub _generic_MCA {
    my ($package, $referent, @attrs) = @_;

    ATTR:
    for my $attr (@attrs) {

        ($attr||=q{}) =~ s/\A Export (?: \( (.*) \) )? \z/$1||q{}/exms
            or next ATTR;

        my @tagsets = grep {length $_} split m/ \s+,?\s* | ,\s* /xms, $attr;

        my (undef, $file, $line) = caller();
        $file =~ s{.*/}{}xms;

        if (my @bad_tags = grep {!m/\A :$IDENT \z/xms} @tagsets) {
            die 'Bad tagset',
                (@bad_tags==1?' ':'s '),
                "in :Export attribute at '$file' line $line: [@bad_tags]\n";
        }

        my $tagsets = $tagsets_for{$package} ||= {};

        for my $tagset (@tagsets) {
            push @{ $tagsets->{$tagset} }, $referent;
        }
        push @{ $tagsets->{':ALL'} }, $referent;

        $is_exported_from{$package}{$referent} = 1;

        undef $attr
    }

    return grep {defined $_} @attrs;
}

sub _invert_tagset {
    my ($package, $tagset) = @_;
    my %inverted_tagset;

    for my $tag (keys %{$tagset}) {
        for my $sub_ref (@{$tagset->{$tag}}) {
            my $sym = Attribute::Handlers::findsym($package, $sub_ref, 'CODE')
                or die "Internal error: missing symbol for $sub_ref";
            $inverted_tagset{$tag}{*{$sym}{NAME}} = $sub_ref;;
        }
    }

    return \%inverted_tagset;
}

# Reusable import() subroutine for all packages...
sub _generic_import {
    my $package = shift;

    my $tagset
        = $named_tagsets_for{$package}
        ||= _invert_tagset($package, $tagsets_for{$package});

    my $is_exported = $is_exported_from{$package};

    my $errors;

    my %request;
    my @pass_on_list;
    my $subs_ref;

    REQUEST:
    for my $request (@_) {
        if (my ($sub_name) = $request =~ m/\A &? ($IDENT) (?:\(\))? \z/xms) {
            next REQUEST if exists $request{$sub_name};
            no strict 'refs';
            no warnings 'once';
            if (my $sub_ref = *{$package.'::'.$sub_name}{CODE}) {
                if ($is_exported->{$sub_ref}) {
                    $request{$sub_name} = $sub_ref;
                    next REQUEST;
                }
            }
        }
        elsif ($request =~ m/\A :$IDENT \z/xms
               and $subs_ref = $tagset->{$request}) {
            @request{keys %{$subs_ref}} = values %{$subs_ref};
            next REQUEST;
        }
        $errors .= " $request";
        push @pass_on_list, $request;
    }

    # Report unexportable requests...
    my $real_import = do{
        no strict 'refs';
        no warnings 'once';
        *{$package.'::IMPORT'}{CODE};
    };
    croak "$package does not export:$errors\nuse $package failed"
        if $errors && !$real_import;

    if (!@_) {
        %request = %{$tagset->{':DEFAULT'}||={}}
    }

    my $mandatory = $tagset->{':MANDATORY'} ||= {};
    @request{ keys %{$mandatory} } = values %{$mandatory};

    my $caller = caller;
    for my $sub_name (keys %request) {
        no strict 'refs';
        *{$caller.'::'.$sub_name} = $request{$sub_name};
    }

    goto &{$real_import} if $real_import;
    return;
}

1; # Magic true value required at end of module
__END__

#line 332