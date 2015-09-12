#line 1 "DBI/Const/GetInfoType.pm"
# $Id: GetInfoType.pm 8696 2007-01-24 23:12:38Z Tim $
#
# Copyright (c) 2002  Tim Bunce  Ireland
#
# Constant data describing info type codes for the DBI getinfo function.
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

package DBI::Const::GetInfoType;

use strict;

use Exporter ();

use vars qw(@ISA @EXPORT @EXPORT_OK %GetInfoType);

@ISA = qw(Exporter);
@EXPORT = qw(%GetInfoType);

my
$VERSION = "2.008697";

#line 43

use DBI::Const::GetInfo::ANSI ();	# liable to change
use DBI::Const::GetInfo::ODBC ();	# liable to change

%GetInfoType =
(
  %DBI::Const::GetInfo::ANSI::InfoTypes	# liable to change
, %DBI::Const::GetInfo::ODBC::InfoTypes	# liable to change
);

1;
