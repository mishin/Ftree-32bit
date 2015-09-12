#line 1 "List/MoreUtils.pm"
package List::MoreUtils;

use 5.006;
use strict;
use warnings;

BEGIN
{
    our $VERSION = '0.413';
}

use Exporter::Tiny qw();
use List::MoreUtils::XS qw();    # try loading XS

my @junctions = qw(any all none notall);
my @v0_22     = qw(
  true false
  firstidx lastidx
  insert_after insert_after_string
  apply indexes
  after after_incl before before_incl
  firstval lastval
  each_array each_arrayref
  pairwise natatime
  mesh uniq
  minmax part
);
my @v0_24  = qw(bsearch);
my @v0_33  = qw(sort_by nsort_by);
my @v0_400 = qw(one any_u all_u none_u notall_u one_u
  firstres onlyidx onlyval onlyres lastres
  singleton bsearchidx
);

my @all_functions = ( @junctions, @v0_22, @v0_24, @v0_33, @v0_400 );

my %alias_list = (
    v0_22 => {
        first_index => "firstidx",
        last_index  => "lastidx",
        first_value => "firstval",
        last_value  => "lastval",
        zip         => "mesh",
    },
    v0_33 => {
        distinct => "uniq",
    },
    v0_400 => {
        first_result  => "firstres",
        only_index    => "onlyidx",
        only_value    => "onlyval",
        only_result   => "onlyres",
        last_result   => "lastres",
        bsearch_index => "bsearchidx",
    },
);

our @ISA         = qw(Exporter::Tiny);
our @EXPORT_OK   = ( @all_functions, map { keys %$_ } values %alias_list );
our %EXPORT_TAGS = (
    all         => \@EXPORT_OK,
    'like_0.22' => [
        any_u    => { -as => 'any' },
        all_u    => { -as => 'all' },
        none_u   => { -as => 'none' },
        notall_u => { -as => 'notall' },
        @v0_22,
        keys %{ $alias_list{v0_22} },
    ],
    'like_0.24' => [
        any_u    => { -as => 'any' },
        all_u    => { -as => 'all' },
        notall_u => { -as => 'notall' },
        'none',
        @v0_22,
        @v0_24,
        keys %{ $alias_list{v0_22} },
    ],
    'like_0.33' => [
        @junctions,
        @v0_22,
        # v0_24 functions were omitted
        @v0_33,
        keys %{ $alias_list{v0_22} },
        keys %{ $alias_list{v0_33} },
    ],
);

for my $set ( values %alias_list )
{
    for my $alias ( keys %$set )
    {
        no strict qw(refs);
        *$alias = __PACKAGE__->can( $set->{$alias} );
    }
}

#line 959

1;
