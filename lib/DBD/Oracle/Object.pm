#line 1 "DBD/Oracle/Object.pm"
package DBD::Oracle::Object;
$DBD::Oracle::Object::VERSION = '1.74';
BEGIN {
  $DBD::Oracle::Object::AUTHORITY = 'cpan:PYTHIAN';
}
# ABSTRACT: Wrapper for Oracle objects

use strict;
use warnings;

sub type_name {  shift->{type_name}  }

sub attributes {  @{shift->{attributes}}  }

sub attr_hash {
	my $self = shift;
	return $self->{attr_hash} ||= { $self->attributes };
}

sub attr {
	my $self = shift;
	if (@_) {
		my $key = shift;
		return $self->attr_hash->{$key};
	}
	return $self->attr_hash;
}

1;

__END__

#line 75
