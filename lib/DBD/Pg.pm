#line 1 "DBD/Pg.pm"
#  -*-cperl-*-
#
#  Copyright (c) 2002-2013 Greg Sabino Mullane and others: see the Changes file
#  Portions Copyright (c) 2002 Jeffrey W. Baker
#  Portions Copyright (c) 1997-2001 Edmund Mergl
#  Portions Copyright (c) 1994-1997 Tim Bunce
#
#  You may distribute under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file.


use strict;
use warnings;
use 5.008001;

{
	package DBD::Pg;

	use version; our $VERSION = qv('3.2.1');

	use DBI ();
	use DynaLoader ();
	use Exporter ();
	use vars qw(@ISA %EXPORT_TAGS $err $errstr $sqlstate $drh $dbh $DBDPG_DEFAULT @EXPORT);
	@ISA = qw(DynaLoader Exporter);


	%EXPORT_TAGS =
		(
		 async => [qw(PG_ASYNC PG_OLDQUERY_CANCEL PG_OLDQUERY_WAIT)],
		 pg_types => [qw(
			PG_ABSTIME PG_ABSTIMEARRAY PG_ACLITEM PG_ACLITEMARRAY PG_ANY
			PG_ANYARRAY PG_ANYELEMENT PG_ANYENUM PG_ANYNONARRAY PG_ANYRANGE
			PG_BIT PG_BITARRAY PG_BOOL PG_BOOLARRAY PG_BOX
			PG_BOXARRAY PG_BPCHAR PG_BPCHARARRAY PG_BYTEA PG_BYTEAARRAY
			PG_CHAR PG_CHARARRAY PG_CID PG_CIDARRAY PG_CIDR
			PG_CIDRARRAY PG_CIRCLE PG_CIRCLEARRAY PG_CSTRING PG_CSTRINGARRAY
			PG_DATE PG_DATEARRAY PG_DATERANGE PG_DATERANGEARRAY PG_EVENT_TRIGGER
			PG_FDW_HANDLER PG_FLOAT4 PG_FLOAT4ARRAY PG_FLOAT8 PG_FLOAT8ARRAY
			PG_GTSVECTOR PG_GTSVECTORARRAY PG_INET PG_INETARRAY PG_INT2
			PG_INT2ARRAY PG_INT2VECTOR PG_INT2VECTORARRAY PG_INT4 PG_INT4ARRAY
			PG_INT4RANGE PG_INT4RANGEARRAY PG_INT8 PG_INT8ARRAY PG_INT8RANGE
			PG_INT8RANGEARRAY PG_INTERNAL PG_INTERVAL PG_INTERVALARRAY PG_JSON
			PG_JSONARRAY PG_JSONB PG_JSONBARRAY PG_LANGUAGE_HANDLER PG_LINE
			PG_LINEARRAY PG_LSEG PG_LSEGARRAY PG_MACADDR PG_MACADDRARRAY
			PG_MONEY PG_MONEYARRAY PG_NAME PG_NAMEARRAY PG_NUMERIC
			PG_NUMERICARRAY PG_NUMRANGE PG_NUMRANGEARRAY PG_OID PG_OIDARRAY
			PG_OIDVECTOR PG_OIDVECTORARRAY PG_OPAQUE PG_PATH PG_PATHARRAY
			PG_PG_ATTRIBUTE PG_PG_CLASS PG_PG_LSN PG_PG_LSNARRAY PG_PG_NODE_TREE
			PG_PG_PROC PG_PG_TYPE PG_POINT PG_POINTARRAY PG_POLYGON
			PG_POLYGONARRAY PG_RECORD PG_RECORDARRAY PG_REFCURSOR PG_REFCURSORARRAY
			PG_REGCLASS PG_REGCLASSARRAY PG_REGCONFIG PG_REGCONFIGARRAY PG_REGDICTIONARY
			PG_REGDICTIONARYARRAY PG_REGOPER PG_REGOPERARRAY PG_REGOPERATOR PG_REGOPERATORARRAY
			PG_REGPROC PG_REGPROCARRAY PG_REGPROCEDURE PG_REGPROCEDUREARRAY PG_REGTYPE
			PG_REGTYPEARRAY PG_RELTIME PG_RELTIMEARRAY PG_SMGR PG_TEXT
			PG_TEXTARRAY PG_TID PG_TIDARRAY PG_TIME PG_TIMEARRAY
			PG_TIMESTAMP PG_TIMESTAMPARRAY PG_TIMESTAMPTZ PG_TIMESTAMPTZARRAY PG_TIMETZ
			PG_TIMETZARRAY PG_TINTERVAL PG_TINTERVALARRAY PG_TRIGGER PG_TSQUERY
			PG_TSQUERYARRAY PG_TSRANGE PG_TSRANGEARRAY PG_TSTZRANGE PG_TSTZRANGEARRAY
			PG_TSVECTOR PG_TSVECTORARRAY PG_TXID_SNAPSHOT PG_TXID_SNAPSHOTARRAY PG_UNKNOWN
			PG_UUID PG_UUIDARRAY PG_VARBIT PG_VARBITARRAY PG_VARCHAR
			PG_VARCHARARRAY PG_VOID PG_XID PG_XIDARRAY PG_XML
			PG_XMLARRAY
		)]
	);

	{
		package DBD::Pg::DefaultValue;
		sub new { my $self = {}; return bless $self, shift; }
	}
	$DBDPG_DEFAULT = DBD::Pg::DefaultValue->new();
	Exporter::export_ok_tags('pg_types', 'async');
	@EXPORT = qw($DBDPG_DEFAULT PG_ASYNC PG_OLDQUERY_CANCEL PG_OLDQUERY_WAIT PG_BYTEA);

	require_version DBI 1.614;

	bootstrap DBD::Pg $VERSION;

	$err = 0;       # holds error code for DBI::err
	$errstr = '';   # holds error string for DBI::errstr
	$sqlstate = ''; # holds five character SQLSTATE code
	$drh = undef;   # holds driver handle once initialized

	## These two methods are here to allow calling before connect()
	sub parse_trace_flag {
		my ($class, $flag) = @_;
		return (0x7FFFFF00 - 0x08000000) if $flag eq 'DBD'; ## all but the prefix
		return 0x01000000 if $flag eq 'pglibpq';
		return 0x02000000 if $flag eq 'pgstart';
		return 0x04000000 if $flag eq 'pgend';
		return 0x08000000 if $flag eq 'pgprefix';
		return 0x10000000 if $flag eq 'pglogin';
		return 0x20000000 if $flag eq 'pgquote';
		return DBI::parse_trace_flag($class, $flag);
	}
	sub parse_trace_flags {
		my ($class, $flags) = @_;
		return DBI::parse_trace_flags($class, $flags);
	}

	sub CLONE {
		$drh = undef;
		return;
	}

	## Deprecated
	sub _pg_use_catalog { ## no critic (ProhibitUnusedPrivateSubroutines)
		return 'pg_catalog.';
	}

	my $methods_are_installed = 0;
	sub driver {
		return $drh if defined $drh;
		my($class, $attr) = @_;

		$class .= '::dr';

		$drh = DBI::_new_drh($class, {
			'Name'        => 'Pg',
			'Version'     => $VERSION,
			'Err'         => \$DBD::Pg::err,
			'Errstr'      => \$DBD::Pg::errstr,
			'State'       => \$DBD::Pg::sqlstate,
			'Attribution' => "DBD::Pg $VERSION by Greg Sabino Mullane and others",
		});

		if (!$methods_are_installed) {
			DBD::Pg::db->install_method('pg_cancel');
			DBD::Pg::db->install_method('pg_endcopy');
			DBD::Pg::db->install_method('pg_getline');
			DBD::Pg::db->install_method('pg_getcopydata');
			DBD::Pg::db->install_method('pg_getcopydata_async');
			DBD::Pg::db->install_method('pg_notifies');
			DBD::Pg::db->install_method('pg_putcopydata');
			DBD::Pg::db->install_method('pg_putcopyend');
			DBD::Pg::db->install_method('pg_ping');
			DBD::Pg::db->install_method('pg_putline');
			DBD::Pg::db->install_method('pg_ready');
			DBD::Pg::db->install_method('pg_release');
			DBD::Pg::db->install_method('pg_result'); ## NOT duplicated below!
			DBD::Pg::db->install_method('pg_rollback_to');
			DBD::Pg::db->install_method('pg_savepoint');
			DBD::Pg::db->install_method('pg_server_trace');
			DBD::Pg::db->install_method('pg_server_untrace');
			DBD::Pg::db->install_method('pg_type_info');

			DBD::Pg::st->install_method('pg_cancel');
			DBD::Pg::st->install_method('pg_result');
			DBD::Pg::st->install_method('pg_ready');

			DBD::Pg::db->install_method('pg_lo_creat');
			DBD::Pg::db->install_method('pg_lo_open');
			DBD::Pg::db->install_method('pg_lo_write');
			DBD::Pg::db->install_method('pg_lo_read');
			DBD::Pg::db->install_method('pg_lo_lseek');
			DBD::Pg::db->install_method('pg_lo_tell');
			DBD::Pg::db->install_method('pg_lo_truncate');
			DBD::Pg::db->install_method('pg_lo_close');
			DBD::Pg::db->install_method('pg_lo_unlink');
			DBD::Pg::db->install_method('pg_lo_import');
			DBD::Pg::db->install_method('pg_lo_import_with_oid');
			DBD::Pg::db->install_method('pg_lo_export');

			$methods_are_installed++;
		}

		return $drh;

	} ## end of driver


	1;

} ## end of package DBD::Pg


{
	package DBD::Pg::dr;

	use strict;

	## Returns an array of formatted database names from the pg_database table
	sub data_sources {

		my $drh = shift;
		my $attr = shift || '';
		## Future: connect to "postgres" when the minimum version we support is 8.0
		my $connstring = 'dbname=template1';
		if ($ENV{DBI_DSN}) {
			($connstring = $ENV{DBI_DSN}) =~ s/dbi:Pg://i;
		}
		if (length $attr) {
			$connstring .= ";$attr";
		}

		my $dbh = DBD::Pg::dr::connect($drh, $connstring) or return;
		$dbh->{AutoCommit}=1;
		my $SQL = 'SELECT pg_catalog.quote_ident(datname) FROM pg_catalog.pg_database ORDER BY 1';
		my $sth = $dbh->prepare($SQL);
		$sth->execute() or die $DBI::errstr;
		$attr and $attr = ";$attr";
		my @sources = map { "dbi:Pg:dbname=$_->[0]$attr" } @{$sth->fetchall_arrayref()};
		$dbh->disconnect;
		return @sources;
	}


	sub connect { ## no critic (ProhibitBuiltinHomonyms)
		my ($drh, $dbname, $user, $pass, $attr) = @_;

		## Allow "db" and "database" as synonyms for "dbname"
		$dbname =~ s/\b(?:db|database)\s*=/dbname=/;

		my $name = $dbname;
		if ($dbname =~ m{dbname\s*=\s*[\"\']([^\"\']+)}) {
			$name = "'$1'";
			$dbname =~ s/\"/\'/g;
		}
		elsif ($dbname =~ m{dbname\s*=\s*([^;]+)}) {
			$name = $1;
		}

 		$user = defined($user) ? $user : defined $ENV{DBI_USER} ? $ENV{DBI_USER} : '';
		$pass = defined($pass) ? $pass : defined $ENV{DBI_PASS} ? $ENV{DBI_PASS} : '';

		my ($dbh) = DBI::_new_dbh($drh, {
			'Name'         => $dbname,
			'Username'     => $user,
			'CURRENT_USER' => $user,
		 });

		# Connect to the database..
		DBD::Pg::db::_login($dbh, $dbname, $user, $pass, $attr) or return undef;

		my $version = $dbh->{pg_server_version};
		$dbh->{private_dbdpg}{version} = $version;

		if ($attr) {
			if ($attr->{dbd_verbose}) {
				$dbh->trace('DBD');
			}
		}

		return $dbh;
	}

	sub private_attribute_info {
		return {
		};
	}

} ## end of package DBD::Pg::dr


{
	package DBD::Pg::db;

	use DBI qw(:sql_types);

	use strict;

	sub parse_trace_flag {
		my ($h, $flag) = @_;
		return DBD::Pg->parse_trace_flag($flag);
	}

	sub prepare {
		my($dbh, $statement, @attribs) = @_;

		return undef if ! defined $statement;

		# Create a 'blank' statement handle:
		my $sth = DBI::_new_sth($dbh, {
			'Statement' => $statement,
		});

		DBD::Pg::st::_prepare($sth, $statement, @attribs) || 0;

		return $sth;
	}

	sub last_insert_id {

		my ($dbh, $catalog, $schema, $table, $col, $attr) = @_;

		## Our ultimate goal is to get a sequence
		my ($sth, $count, $SQL, $sequence);

		## Cache all of our table lookups? Default is yes
		my $cache = 1;

		## Catalog and col are not used
		$schema = '' if ! defined $schema;
		$table = '' if ! defined $table;
		my $cachename = "lii$table$schema";

		if (defined $attr and length $attr) {
			## If not a hash, assume it is a sequence name
			if (! ref $attr) {
				$attr = {sequence => $attr};
			}
			elsif (ref $attr ne 'HASH') {
				$dbh->set_err(1, 'last_insert_id must be passed a hashref as the final argument');
				return undef;
			}
			## Named sequence overrides any table or schema settings
			if (exists $attr->{sequence} and length $attr->{sequence}) {
				$sequence = $attr->{sequence};
			}
			if (exists $attr->{pg_cache}) {
				$cache = $attr->{pg_cache};
			}
		}

		if (! defined $sequence and exists $dbh->{private_dbdpg}{$cachename} and $cache) {
			$sequence = $dbh->{private_dbdpg}{$cachename};
		}
		elsif (! defined $sequence) {
			## At this point, we must have a valid table name
			if (! length $table) {
				$dbh->set_err(1, 'last_insert_id needs at least a sequence or table name');
				return undef;
			}
			my @args = ($table);
			## Make sure the table in question exists and grab its oid
			my ($schemajoin,$schemawhere) = ('','');
			if (length $schema) {
				$schemajoin = "\n JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)";
				$schemawhere = "\n AND n.nspname = ?";
				push @args, $schema;
			}
			$SQL = "SELECT c.oid FROM pg_catalog.pg_class c $schemajoin\n WHERE relname = ?$schemawhere";
			if (! length $schema) {
				$SQL .= ' AND pg_catalog.pg_table_is_visible(c.oid)';
			}
			$sth = $dbh->prepare_cached($SQL);
			$count = $sth->execute(@args);
			if (!defined $count or $count eq '0E0') {
				$sth->finish();
				my $message = qq{Could not find the table "$table"};
				length $schema and $message .= qq{ in the schema "$schema"};
				$dbh->set_err(1, $message);
				return undef;
			}
			my $oid = $sth->fetchall_arrayref()->[0][0];
			$oid =~ /(\d+)/ or die qq{OID was not numeric?!?\n};
			$oid = $1;
			## This table has a primary key. Is there a sequence associated with it via a unique, indexed column?
			$SQL = "SELECT a.attname, i.indisprimary, pg_catalog.pg_get_expr(adbin,adrelid)\n".
				"FROM pg_catalog.pg_index i, pg_catalog.pg_attribute a, pg_catalog.pg_attrdef d\n ".
				"WHERE i.indrelid = $oid AND d.adrelid=a.attrelid AND d.adnum=a.attnum\n".
				"  AND a.attrelid = $oid AND i.indisunique IS TRUE\n".
				"  AND a.atthasdef IS TRUE AND i.indkey[0]=a.attnum\n".
				q{ AND d.adsrc ~ '^nextval'};
			$sth = $dbh->prepare($SQL);
			$count = $sth->execute();
			if (!defined $count or $count eq '0E0') {
				$sth->finish();
				$dbh->set_err(1, qq{No suitable column found for last_insert_id of table "$table"});
				return undef;
			}
			my $info = $sth->fetchall_arrayref();

			## We have at least one with a default value. See if we can determine sequences
			my @def;
			for (@$info) {
				next unless $_->[2] =~ /^nextval\(+'([^']+)'::/o;
				push @$_, $1;
				push @def, $_;
			}
			if (!@def) {
				$dbh->set_err(1, qq{No suitable column found for last_insert_id of table "$table"\n});
			}
			## Tiebreaker goes to the primary keys
			if (@def > 1) {
				my @pri = grep { $_->[1] } @def;
				if (1 != @pri) {
					$dbh->set_err(1, qq{No suitable column found for last_insert_id of table "$table"\n});
				}
				@def = @pri;
			}
			$sequence = $def[0]->[3];
			## Cache this information for subsequent calls
			$dbh->{private_dbdpg}{$cachename} = $sequence;
		}

		$sth = $dbh->prepare_cached('SELECT currval(?)');
		$count = $sth->execute($sequence);
		return undef if ! defined $count;
		return $sth->fetchall_arrayref()->[0][0];

	} ## end of last_insert_id

	sub ping {
		my $dbh = shift;
		local $SIG{__WARN__} = sub { } if $dbh->FETCH('PrintError');
		my $ret = DBD::Pg::db::_ping($dbh);
		return $ret < 1 ? 0 : $ret;
	}

	sub pg_ping {
		my $dbh = shift;
		local $SIG{__WARN__} = sub { } if $dbh->FETCH('PrintError');
		return DBD::Pg::db::_ping($dbh);
	}

	sub pg_type_info {
		my($dbh,$pg_type) = @_;
		local $SIG{__WARN__} = sub { } if $dbh->FETCH('PrintError');
		my $ret = DBD::Pg::db::_pg_type_info($pg_type);
		return $ret;
	}

	# Column expected in statement handle returned.
	# table_cat, table_schem, table_name, column_name, data_type, type_name,
 	# column_size, buffer_length, DECIMAL_DIGITS, NUM_PREC_RADIX, NULLABLE,
	# REMARKS, COLUMN_DEF, SQL_DATA_TYPE, SQL_DATETIME_SUB, CHAR_OCTET_LENGTH,
	# ORDINAL_POSITION, IS_NULLABLE
	# The result set is ordered by TABLE_SCHEM, TABLE_NAME and ORDINAL_POSITION.

	sub column_info {
		my $dbh = shift;
		my ($catalog, $schema, $table, $column) = @_;

		my @search;
		## If the schema or table has an underscore or a %, use a LIKE comparison
		if (defined $schema and length $schema) {
			push @search, 'n.nspname ' . ($schema =~ /[_%]/ ? 'LIKE ' : '= ') .
				$dbh->quote($schema);
		}
		if (defined $table and length $table) {
			push @search, 'c.relname ' . ($table =~ /[_%]/ ? 'LIKE ' : '= ') .
				$dbh->quote($table);
		}
		if (defined $column and length $column) {
			push @search, 'a.attname ' . ($column =~ /[_%]/ ? 'LIKE ' : '= ') .
				$dbh->quote($column);
		}

		my $whereclause = join "\n\t\t\t\tAND ", '', @search;

		my $schemajoin = 'JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)';

		my $remarks = 'pg_catalog.col_description(a.attrelid, a.attnum)';

		my $column_def = $dbh->{private_dbdpg}{version} >= 80000
			? 'pg_catalog.pg_get_expr(af.adbin, af.adrelid)'
			: 'af.adsrc';

		my $col_info_sql = qq!
            SELECT
                NULL::text AS "TABLE_CAT"
                , quote_ident(n.nspname) AS "TABLE_SCHEM"
                , quote_ident(c.relname) AS "TABLE_NAME"
                , quote_ident(a.attname) AS "COLUMN_NAME"
                , a.atttypid AS "DATA_TYPE"
                , pg_catalog.format_type(a.atttypid, NULL) AS "TYPE_NAME"
                , a.attlen AS "COLUMN_SIZE"
                , NULL::text AS "BUFFER_LENGTH"
                , NULL::text AS "DECIMAL_DIGITS"
                , NULL::text AS "NUM_PREC_RADIX"
                , CASE a.attnotnull WHEN 't' THEN 0 ELSE 1 END AS "NULLABLE"
                , $remarks AS "REMARKS"
                , $column_def AS "COLUMN_DEF"
                , NULL::text AS "SQL_DATA_TYPE"
                , NULL::text AS "SQL_DATETIME_SUB"
                , NULL::text AS "CHAR_OCTET_LENGTH"
                , a.attnum AS "ORDINAL_POSITION"
                , CASE a.attnotnull WHEN 't' THEN 'NO' ELSE 'YES' END AS "IS_NULLABLE"
                , pg_catalog.format_type(a.atttypid, a.atttypmod) AS "pg_type"
                , '?' AS "pg_constraint"
                , n.nspname AS "pg_schema"
                , c.relname AS "pg_table"
                , a.attname AS "pg_column"
                , a.attrelid AS "pg_attrelid"
                , a.attnum AS "pg_attnum"
                , a.atttypmod AS "pg_atttypmod"
                , t.typtype AS "_pg_type_typtype"
                , t.oid AS "_pg_type_oid"
            FROM
                pg_catalog.pg_type t
                JOIN pg_catalog.pg_attribute a ON (t.oid = a.atttypid)
                JOIN pg_catalog.pg_class c ON (a.attrelid = c.oid)
                LEFT JOIN pg_catalog.pg_attrdef af ON (a.attnum = af.adnum AND a.attrelid = af.adrelid)
                $schemajoin
            WHERE
                a.attnum >= 0
                AND c.relkind IN ('r','v')
                $whereclause
            ORDER BY "TABLE_SCHEM", "TABLE_NAME", "ORDINAL_POSITION"
            !;

		my $data = $dbh->selectall_arrayref($col_info_sql) or return undef;

		# To turn the data back into a statement handle, we need 
		# to fetch the data as an array of arrays, and also have a
		# a matching array of all the column names
		my %col_map = (qw/
			TABLE_CAT             0
			TABLE_SCHEM           1
			TABLE_NAME            2
			COLUMN_NAME           3
			DATA_TYPE             4
			TYPE_NAME             5
			COLUMN_SIZE           6
			BUFFER_LENGTH         7
			DECIMAL_DIGITS        8
			NUM_PREC_RADIX        9
			NULLABLE             10
			REMARKS              11
			COLUMN_DEF           12
			SQL_DATA_TYPE        13
			SQL_DATETIME_SUB     14
			CHAR_OCTET_LENGTH    15
			ORDINAL_POSITION     16
			IS_NULLABLE          17
			pg_type              18
			pg_constraint        19
			pg_schema            20
			pg_table             21
			pg_column            22
			pg_enum_values       23
			/);

		for my $row (@$data) {
			my $typoid = pop @$row;
			my $typtype = pop @$row;
			my $typmod = pop @$row;
			my $attnum = pop @$row;
			my $aid = pop @$row;

			$row->[$col_map{COLUMN_SIZE}] =
 				_calc_col_size($typmod,$row->[$col_map{COLUMN_SIZE}]);

			# Replace the Pg type with the SQL_ type
			$row->[$col_map{DATA_TYPE}] = DBD::Pg::db::pg_type_info($dbh,$row->[$col_map{DATA_TYPE}]);

			# Add pg_constraint
			my $SQL = q{SELECT consrc FROM pg_catalog.pg_constraint WHERE contype = 'c' AND }.
				qq{conrelid = $aid AND conkey = '{$attnum}'};
			my $info = $dbh->selectall_arrayref($SQL);
			if (@$info) {
				$row->[19] = $info->[0][0];
			}
			else {
				$row->[19] = undef;
			}

			if ( $typtype eq 'e' ) {
				$SQL = "SELECT enumlabel FROM pg_catalog.pg_enum WHERE enumtypid = $typoid ORDER BY oid";
				$row->[23] = $dbh->selectcol_arrayref($SQL);
			}
			else {
				$row->[23] = undef;
			}
		}

		# Since we've processed the data in Perl, we have to jump through a hoop
		# To turn it back into a statement handle
		#
		return _prepare_from_data
			(
			 'column_info',
			 $data,
			 [ sort { $col_map{$a} <=> $col_map{$b} } keys %col_map],
			 );
	}

	sub _prepare_from_data {
		my ($statement, $data, $names, %attr) = @_;
		my $sponge = DBI->connect('dbi:Sponge:', '', '', { RaiseError => 1 });
		my $sth = $sponge->prepare($statement, { rows=>$data, NAME=>$names, %attr });
		return $sth;
	}

	sub statistics_info {

		my $dbh = shift;
		my ($catalog, $schema, $table, $unique_only, $quick, $attr) = @_;

		## Catalog is ignored, but table is mandatory
		return undef unless defined $table and length $table;

		my $schema_where = '';
		my @exe_args = ($table);

		my $input_schema = (defined $schema and length $schema) ? 1 : 0;

		if ($input_schema) {
			$schema_where = 'AND n.nspname = ? AND n.oid = d.relnamespace';
			push(@exe_args, $schema);
		}
		else {
			$schema_where = 'AND n.oid = d.relnamespace';
		}

		my $table_stats_sql = qq{
            SELECT d.relpages, d.reltuples, n.nspname
            FROM   pg_catalog.pg_class d, pg_catalog.pg_namespace n
            WHERE  d.relname = ? $schema_where
        };

		my $colnames_sql = qq{
            SELECT
                a.attnum, a.attname
            FROM
                pg_catalog.pg_attribute a, pg_catalog.pg_class d, pg_catalog.pg_namespace n
            WHERE
                a.attrelid = d.oid AND d.relname = ? $schema_where
        };

		my $stats_sql = qq{
            SELECT
                c.relname, i.indkey, i.indisunique, i.indisclustered, a.amname,
                n.nspname, c.relpages, c.reltuples, i.indexprs, i.indnatts, i.indexrelid,
                pg_get_expr(i.indpred,i.indrelid) as predicate,
                pg_get_expr(i.indexprs,i.indrelid, true) AS indexdef
            FROM
                pg_catalog.pg_index i, pg_catalog.pg_class c,
                pg_catalog.pg_class d, pg_catalog.pg_am a,
                pg_catalog.pg_namespace n
            WHERE
                d.relname = ? $schema_where AND d.oid = i.indrelid
                AND i.indexrelid = c.oid AND c.relam = a.oid
            ORDER BY
                i.indisunique desc, a.amname, c.relname
        };

		my $indexdef_sql = qq{
            SELECT
                pg_get_indexdef(indexrelid,x,true)
            FROM
              pg_index
            JOIN generate_series(1,?) s(x) ON indexrelid = ?
        };

		my @output_rows;

		# Table-level stats
		if (!$unique_only) {
			my $table_stats_sth = $dbh->prepare($table_stats_sql);
			$table_stats_sth->execute(@exe_args) or return undef;
			my $tst = $table_stats_sth->fetchrow_hashref or return undef;
			push(@output_rows, [
				undef,            # TABLE_CAT
				$tst->{nspname},  # TABLE_SCHEM
				$table,           # TABLE_NAME
				undef,            # NON_UNIQUE
				undef,            # INDEX_QUALIFIER
				undef,            # INDEX_NAME
				'table',          # TYPE
				undef,            # ORDINAL_POSITION
				undef,            # COLUMN_NAME
				undef,            # ASC_OR_DESC
				$tst->{reltuples},# CARDINALITY
				$tst->{relpages}, # PAGES
				undef,            # FILTER_CONDITION
                undef,            # pg_expression
			]);
		}

		# Fetch the column names for later use
		my $colnames_sth = $dbh->prepare($colnames_sql);
		$colnames_sth->execute(@exe_args) or return undef;
		my $colnames = $colnames_sth->fetchall_hashref('attnum');

		# Fetch the individual parts of the index
		my $sth_indexdef = $dbh->prepare($indexdef_sql);

		# Fetch the index definitions
		my $sth = $dbh->prepare($stats_sql);
		$sth->execute(@exe_args) or return undef;

		STAT_ROW:
		while (my $row = $sth->fetchrow_hashref) {

			next if $unique_only and !$row->{indisunique};

			my $indtype = $row->{indisclustered}
				? 'clustered'
				: ( $row->{amname} eq 'btree' )
					? 'btree'
					: ($row->{amname} eq 'hash' )
						? 'hashed' : 'other';

			my $nonunique = $row->{indisunique} ? 0 : 1;

			my @index_row = (
				undef,             # TABLE_CAT         0
				$row->{nspname},   # TABLE_SCHEM       1
				$table,            # TABLE_NAME        2
				$nonunique,        # NON_UNIQUE        3
				undef,             # INDEX_QUALIFIER   4
				$row->{relname},   # INDEX_NAME        5
				$indtype,          # TYPE              6
				undef,             # ORDINAL_POSITION  7
				undef,             # COLUMN_NAME       8
				'A',               # ASC_OR_DESC       9
				$row->{reltuples}, # CARDINALITY      10
				$row->{relpages},  # PAGES            11
				$row->{predicate}, # FILTER_CONDITION 12
                undef,             # pg_expression    13
			);

			## Grab expression information
			$sth_indexdef->execute($row->{indnatts}, $row->{indexrelid});
			my $expression = $sth_indexdef->fetchall_arrayref();

			my $col_nums = $row->{indkey};
			$col_nums =~ s/^\s+//;
			my @col_nums = split(/\s+/, $col_nums);

			my $ord_pos = 1;
			for my $col_num (@col_nums) {
				my @copy = @index_row;
				$copy[7] = $ord_pos; # ORDINAL_POSITION
				$copy[8] = $colnames->{$col_num}->{attname}; # COLUMN_NAME
				$copy[13] = $expression->[$ord_pos-1][0];
				push(@output_rows, \@copy);
				$ord_pos++;
			}
		}

		my @output_colnames = qw/ TABLE_CAT TABLE_SCHEM TABLE_NAME NON_UNIQUE INDEX_QUALIFIER
					INDEX_NAME TYPE ORDINAL_POSITION COLUMN_NAME ASC_OR_DESC
					CARDINALITY PAGES FILTER_CONDITION pg_expression /;

		return _prepare_from_data('statistics_info', \@output_rows, \@output_colnames);
	}

	sub primary_key_info {

		my $dbh = shift;
		my ($catalog, $schema, $table, $attr) = @_;

		## Catalog is ignored, but table is mandatory
		return undef unless defined $table and length $table;

		my $whereclause = 'AND c.relname = ' . $dbh->quote($table);

		if (defined $schema and length $schema) {
			$whereclause .= "\n\t\t\tAND n.nspname = " . $dbh->quote($schema);
		}

		my $TSJOIN = 'pg_catalog.pg_tablespace t ON (t.oid = c.reltablespace)';
		if ($dbh->{private_dbdpg}{version} < 80000) {
			$TSJOIN = '(SELECT 0 AS oid, 0 AS spcname, 0 AS spclocation LIMIT 0) AS t ON (t.oid=1)';
		}

		my $pri_key_sql = qq{
            SELECT
                  c.oid
                , quote_ident(n.nspname)
                , quote_ident(c.relname)
                , quote_ident(c2.relname)
                , i.indkey, quote_ident(t.spcname), quote_ident(t.spclocation)
                , n.nspname, c.relname, c2.relname
            FROM
                pg_catalog.pg_class c
                JOIN pg_catalog.pg_index i ON (i.indrelid = c.oid)
                JOIN pg_catalog.pg_class c2 ON (c2.oid = i.indexrelid)
                LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)
                LEFT JOIN $TSJOIN
            WHERE
                i.indisprimary IS TRUE
            $whereclause
        };

		if ($dbh->{private_dbdpg}{version} >= 90200) {
			$pri_key_sql =~ s/t.spclocation/pg_tablespace_location(t.oid)/;
		}

		my $sth = $dbh->prepare($pri_key_sql) or return undef;
		$sth->execute();
		my $info = $sth->fetchall_arrayref()->[0];
		return undef if ! defined $info;

		# Get the attribute information
		my $indkey = join ',', split /\s+/, $info->[4];
		my $sql = qq{
            SELECT a.attnum, pg_catalog.quote_ident(a.attname) AS colname,
                pg_catalog.quote_ident(t.typname) AS typename
            FROM pg_catalog.pg_attribute a, pg_catalog.pg_type t
            WHERE a.attrelid = '$info->[0]'
            AND a.atttypid = t.oid
            AND attnum IN ($indkey);
        };
		$sth = $dbh->prepare($sql) or return undef;
		$sth->execute();
		my $attribs = $sth->fetchall_hashref('attnum');

		my $pkinfo = [];

		## Normal way: complete "row" per column in the primary key
		if (!exists $attr->{'pg_onerow'}) {
			my $x=0;
			my @key_seq = split/\s+/, $info->[4];
			for (@key_seq) {
				# TABLE_CAT
				$pkinfo->[$x][0] = undef;
				# SCHEMA_NAME
				$pkinfo->[$x][1] = $info->[1];
				# TABLE_NAME
				$pkinfo->[$x][2] = $info->[2];
				# COLUMN_NAME
				$pkinfo->[$x][3] = $attribs->{$_}{colname};
				# KEY_SEQ
				$pkinfo->[$x][4] = $_;
				# PK_NAME
				$pkinfo->[$x][5] = $info->[3];
				# DATA_TYPE
				$pkinfo->[$x][6] = $attribs->{$_}{typename};
				$pkinfo->[$x][7] = $info->[5];
				$pkinfo->[$x][8] = $info->[6];
				$pkinfo->[$x][9] = $info->[7];
				$pkinfo->[$x][10] = $info->[8];
				$pkinfo->[$x][11] = $info->[9];
				$x++;
			}
		}
		else { ## Nicer way: return only one row

			# TABLE_CAT
			$info->[0] = undef;
			# TABLESPACES
			$info->[7] = $info->[5];
			$info->[8] = $info->[6];
			# Unquoted names
			$info->[9] = $info->[7];
			$info->[10] = $info->[8];
			$info->[11] = $info->[9];
			# PK_NAME
			$info->[5] = $info->[3];
			# COLUMN_NAME
			$info->[3] = 2==$attr->{'pg_onerow'} ?
				[ map { $attribs->{$_}{colname} } split /\s+/, $info->[4] ] :
					join ', ', map { $attribs->{$_}{colname} } split /\s+/, $info->[4];
			# DATA_TYPE
			$info->[6] = 2==$attr->{'pg_onerow'} ?
				[ map { $attribs->{$_}{typename} } split /\s+/, $info->[4] ] :
					join ', ', map { $attribs->{$_}{typename} } split /\s+/, $info->[4];
			# KEY_SEQ
			$info->[4] = 2==$attr->{'pg_onerow'} ?
				[ split /\s+/, $info->[4] ] :
					join ', ', split /\s+/, $info->[4];

			$pkinfo = [$info];
		}

		my @cols = (qw(TABLE_CAT TABLE_SCHEM TABLE_NAME COLUMN_NAME
									 KEY_SEQ PK_NAME DATA_TYPE));
		push @cols, 'pg_tablespace_name', 'pg_tablespace_location';
		push @cols, 'pg_schema', 'pg_table', 'pg_column';

		return _prepare_from_data('primary_key_info', $pkinfo, \@cols);

	}

	sub primary_key {
		my $sth = primary_key_info(@_[0..3], {pg_onerow => 2});
		return defined $sth ? @{$sth->fetchall_arrayref()->[0][3]} : ();
	}


	sub foreign_key_info {

		my $dbh = shift;

		## PK: catalog, schema, table, FK: catalog, schema, table, attr

		my $oldname = $dbh->{FetchHashKeyName};

		local $dbh->{FetchHashKeyName} = 'NAME_lc';

		## Each of these may be undef or empty
		my $pschema = $_[1] || '';
		my $ptable = $_[2] || '';
		my $fschema = $_[4] || '';
		my $ftable = $_[5] || '';
		my $args = $_[6];

		## No way to currently specify it, but we are ready when there is
		my $odbc = 0;

		## Must have at least one named table
		return undef if !$ptable and !$ftable;

		## If only the primary table is given, we return only those columns
		## that are used as foreign keys, even if that means that we return
		## unique keys but not primary one. We also return all the foreign
		## tables/columns that are referencing them, of course.

		## The first step is to find the oid of each specific table in the args:
		## Return undef if no matching relation found
		my %oid;
		for ([$ptable, $pschema, 'P'], [$ftable, $fschema, 'F']) {
			if (length $_->[0]) {
				my $SQL = "SELECT c.oid AS schema FROM pg_catalog.pg_class c, pg_catalog.pg_namespace n\n".
					'WHERE c.relnamespace = n.oid AND c.relname = ' . $dbh->quote($_->[0]);
				if (length $_->[1]) {
					$SQL .= ' AND n.nspname = ' . $dbh->quote($_->[1]);
				}
				else {
					$SQL .= ' AND pg_catalog.pg_table_is_visible(c.oid)'
				}
				my $info = $dbh->selectall_arrayref($SQL);
				return undef if ! @$info;
				$oid{$_->[2]} = $info->[0][0];
			}
		}

		## We now need information about each constraint we care about.
		## Foreign table: only 'f' / Primary table: only 'p' or 'u'
		my $WHERE = $odbc ? q{((contype = 'p'} : q{((contype IN ('p','u')};
		if (length $ptable) {
			$WHERE .= " AND conrelid=$oid{'P'}::oid";
		}
		else {
			$WHERE .= " AND conrelid IN (SELECT DISTINCT confrelid FROM pg_catalog.pg_constraint WHERE conrelid=$oid{'F'}::oid)";
			if (length $pschema) {
				$WHERE .= ' AND n2.nspname = ' . $dbh->quote($pschema);
			}
		}

		$WHERE .= ")\n \t\t\t\tOR \n \t\t\t\t(contype = 'f'";
		if (length $ftable) {
			$WHERE .= " AND conrelid=$oid{'F'}::oid";
			if (length $ptable) {
				$WHERE .= " AND confrelid=$oid{'P'}::oid";
			}
		}
		else {
			$WHERE .= " AND confrelid = $oid{'P'}::oid";
			if (length $fschema) {
				$WHERE .= ' AND n2.nspname = ' . $dbh->quote($fschema);
			}
		}
		$WHERE .= '))';

		## Grab everything except specific column names:
		my $fk_sql = qq{
        SELECT conrelid, confrelid, contype, conkey, confkey,
            pg_catalog.quote_ident(c.relname) AS t_name, pg_catalog.quote_ident(n2.nspname) AS t_schema,
            pg_catalog.quote_ident(n.nspname) AS c_schema, pg_catalog.quote_ident(conname) AS c_name,
            CASE
                WHEN confupdtype = 'c' THEN 0
                WHEN confupdtype = 'r' THEN 1
                WHEN confupdtype = 'n' THEN 2
                WHEN confupdtype = 'a' THEN 3
                WHEN confupdtype = 'd' THEN 4
                ELSE -1
            END AS update,
            CASE
                WHEN confdeltype = 'c' THEN 0
                WHEN confdeltype = 'r' THEN 1
                WHEN confdeltype = 'n' THEN 2
                WHEN confdeltype = 'a' THEN 3
                WHEN confdeltype = 'd' THEN 4
                ELSE -1
            END AS delete,
            CASE
                WHEN condeferrable = 'f' THEN 7
                WHEN condeferred = 't' THEN 6
                WHEN condeferred = 'f' THEN 5
                ELSE -1
            END AS defer
            FROM pg_catalog.pg_constraint k, pg_catalog.pg_class c, pg_catalog.pg_namespace n, pg_catalog.pg_namespace n2
            WHERE $WHERE
                AND k.connamespace = n.oid
                AND k.conrelid = c.oid
                AND c.relnamespace = n2.oid
                ORDER BY conrelid ASC
                };

		my $sth = $dbh->prepare($fk_sql);
		$sth->execute();

		## We have to make sure expand_array is on for the items below to work
		my $oldexpand = $dbh->FETCH('pg_expand_array');
		$oldexpand or $dbh->STORE('pg_expand_array', 1);

		my $info = $sth->fetchall_arrayref({});
		$oldexpand or $dbh->STORE('pg_expand_array', 0);
		return undef if ! defined $info or ! @$info;

		## Return undef if just ptable given but no fk found
		return undef if ! length $ftable and ! grep { $_->{'contype'} eq 'f'} @$info;

		## Figure out which columns we need information about
		my %colnum;
		for my $row (@$info) {
			for (@{$row->{'conkey'}}) {
				$colnum{$row->{'conrelid'}}{$_}++;
			}
			if ($row->{'contype'} eq 'f') {
				for (@{$row->{'confkey'}}) {
					$colnum{$row->{'confrelid'}}{$_}++;
				}
			}
		}
		## Get the information about the columns computed above
		my $SQL = qq{
            SELECT a.attrelid, a.attnum, pg_catalog.quote_ident(a.attname) AS colname, 
                pg_catalog.quote_ident(t.typname) AS typename
            FROM pg_catalog.pg_attribute a, pg_catalog.pg_type t
            WHERE a.atttypid = t.oid
            AND (\n};

		$SQL .= join "\n\t\t\t\tOR\n" => map {
			my $cols = join ',' => keys %{$colnum{$_}};
			"\t\t\t\t( a.attrelid = '$_' AND a.attnum IN ($cols) )"
		} sort keys %colnum;

		$sth = $dbh->prepare(qq{$SQL )});
		$sth->execute();
		my $attribs = $sth->fetchall_arrayref({});

		## Make a lookup hash
		my %attinfo;
		for (@$attribs) {
			$attinfo{"$_->{'attrelid'}"}{"$_->{'attnum'}"} = $_;
		}

		## This is an array in case we have identical oid/column combos. Lowest oid wins
		my %ukey;
		for my $c (grep { $_->{'contype'} ne 'f' } @$info) {
			## Munge multi-column keys into sequential order
			my $multi = join ' ' => sort @{$c->{'conkey'}};
			push @{$ukey{$c->{'conrelid'}}{$multi}}, $c;
		}

		## Finally, return as a SQL/CLI structure:
		my $fkinfo = [];
		my $x=0;
		for my $t (sort { $a->{'c_name'} cmp $b->{'c_name'} } grep { $_->{'contype'} eq 'f' } @$info) {
			## We need to find which constraint row (if any) matches our confrelid-confkey combo
			## by checking out ukey hash. We sort for proper matching of { 1 2 } vs. { 2 1 }
			## No match means we have a pure index constraint
			my $u;
			my $multi = join ' ' => sort @{$t->{'confkey'}};
			if (exists $ukey{$t->{'confrelid'}}{$multi}) {
				$u = $ukey{$t->{'confrelid'}}{$multi}->[0];
			}
			else {
				## Mark this as an index so we can fudge things later on
				$multi = 'index';
				## Grab the first one found, modify later on as needed
				$u = ((values %{$ukey{$t->{'confrelid'}}})[0]||[])->[0];
				## Bail in case there was no match
				next if ! ref $u;
			}

			## ODBC is primary keys only
			next if $odbc and ($u->{'contype'} ne 'p' or $multi eq 'index');

			my $conkey = $t->{'conkey'};
			my $confkey = $t->{'confkey'};
			for (my $y=0; $conkey->[$y]; $y++) {
				# UK_TABLE_CAT
				$fkinfo->[$x][0] = undef;
				# UK_TABLE_SCHEM
				$fkinfo->[$x][1] = $u->{'t_schema'};
				# UK_TABLE_NAME
				$fkinfo->[$x][2] = $u->{'t_name'};
				# UK_COLUMN_NAME
				$fkinfo->[$x][3] = $attinfo{$t->{'confrelid'}}{$confkey->[$y]}{'colname'};
				# FK_TABLE_CAT
				$fkinfo->[$x][4] = undef;
				# FK_TABLE_SCHEM
				$fkinfo->[$x][5] = $t->{'t_schema'};
				# FK_TABLE_NAME
				$fkinfo->[$x][6] = $t->{'t_name'};
				# FK_COLUMN_NAME
				$fkinfo->[$x][7] = $attinfo{$t->{'conrelid'}}{$conkey->[$y]}{'colname'};
				# ORDINAL_POSITION
				$fkinfo->[$x][8] = $y+1;
				# UPDATE_RULE
				$fkinfo->[$x][9] = "$t->{'update'}";
				# DELETE_RULE
				$fkinfo->[$x][10] = "$t->{'delete'}";
				# FK_NAME
				$fkinfo->[$x][11] = $t->{'c_name'};
				# UK_NAME (may be undef if an index with no named constraint)
				$fkinfo->[$x][12] = $multi eq 'index' ? undef : $u->{'c_name'};
				# DEFERRABILITY
				$fkinfo->[$x][13] = "$t->{'defer'}";
				# UNIQUE_OR_PRIMARY
				$fkinfo->[$x][14] = ($u->{'contype'} eq 'p' and $multi ne 'index') ? 'PRIMARY' : 'UNIQUE';
				# UK_DATA_TYPE
				$fkinfo->[$x][15] = $attinfo{$t->{'confrelid'}}{$confkey->[$y]}{'typename'};
				# FK_DATA_TYPE
				$fkinfo->[$x][16] = $attinfo{$t->{'conrelid'}}{$conkey->[$y]}{'typename'};
				$x++;
			} ## End each column in this foreign key
		} ## End each foreign key

		my @CLI_cols = (qw(
			UK_TABLE_CAT UK_TABLE_SCHEM UK_TABLE_NAME UK_COLUMN_NAME
			FK_TABLE_CAT FK_TABLE_SCHEM FK_TABLE_NAME FK_COLUMN_NAME
			ORDINAL_POSITION UPDATE_RULE DELETE_RULE FK_NAME UK_NAME
			DEFERABILITY UNIQUE_OR_PRIMARY UK_DATA_TYPE FK_DATA_TYPE
		));

		my @ODBC_cols = (qw(
			PKTABLE_CAT PKTABLE_SCHEM PKTABLE_NAME PKCOLUMN_NAME
			FKTABLE_CAT FKTABLE_SCHEM FKTABLE_NAME FKCOLUMN_NAME
			KEY_SEQ UPDATE_RULE DELETE_RULE FK_NAME PK_NAME
			DEFERABILITY UNIQUE_OR_PRIMARY PK_DATA_TYPE FKDATA_TYPE
		));

		if ($oldname eq 'NAME_lc') {
			if ($odbc) {
				for my $col (@ODBC_cols) {
					$col = lc $col;
				}
			}
			else {
				for my $col (@CLI_cols) {
					$col = lc $col;
				}
			}
		}

		return _prepare_from_data('foreign_key_info', $fkinfo, $odbc ? \@ODBC_cols : \@CLI_cols);

	}


	sub table_info {

		my $dbh = shift;
		my ($catalog, $schema, $table, $type) = @_;

		my $tbl_sql = ();

		my $extracols = q{,NULL::text AS pg_schema, NULL::text AS pg_table};
		if ( # Rule 19a
				(defined $catalog and $catalog eq '%')
				and (defined $schema and $schema eq '')
				and (defined $table and $table eq '')
			 ) {
			$tbl_sql = qq{
                    SELECT
                         NULL::text AS "TABLE_CAT"
                     , NULL::text AS "TABLE_SCHEM"
                     , NULL::text AS "TABLE_NAME"
                     , NULL::text AS "TABLE_TYPE"
                     , NULL::text AS "REMARKS" $extracols
                    };
		}
		elsif (# Rule 19b
					 (defined $catalog and $catalog eq '')
					 and (defined $schema and $schema eq '%')
					 and (defined $table and $table eq '')
					) {
			$extracols = q{,n.nspname AS pg_schema, NULL::text AS pg_table};
			$tbl_sql = qq{SELECT
                       NULL::text AS "TABLE_CAT"
                     , quote_ident(n.nspname) AS "TABLE_SCHEM"
                     , NULL::text AS "TABLE_NAME"
                     , NULL::text AS "TABLE_TYPE"
                     , CASE WHEN n.nspname ~ '^pg_' THEN 'system schema' ELSE 'owned by ' || pg_get_userbyid(n.nspowner) END AS "REMARKS" $extracols
                    FROM pg_catalog.pg_namespace n
                    ORDER BY "TABLE_SCHEM"
                    };
		}
		elsif (# Rule 19c
					 (defined $catalog and $catalog eq '')
					 and (defined $schema and $schema eq '')
					 and (defined $table and $table eq '')
					 and (defined $type and $type eq '%')
					) {
			$tbl_sql = qq{
                    SELECT
                       NULL::text AS "TABLE_CAT"
                     , NULL::text AS "TABLE_SCHEM"
                     , NULL::text AS "TABLE_NAME"
                     , 'TABLE'    AS "TABLE_TYPE"
                     , 'relkind: r' AS "REMARKS" $extracols
                    UNION
                    SELECT
                       NULL::text AS "TABLE_CAT"
                     , NULL::text AS "TABLE_SCHEM"
                     , NULL::text AS "TABLE_NAME"
                     , 'VIEW'     AS "TABLE_TYPE"
                     , 'relkind: v' AS "REMARKS" $extracols
                };
		}
		else {
			# Default SQL
			$extracols = q{,n.nspname AS pg_schema, c.relname AS pg_table};
			my @search;
			my $showtablespace = ', quote_ident(t.spcname) AS "pg_tablespace_name", quote_ident(t.spclocation) AS "pg_tablespace_location"';
			if ($dbh->{private_dbdpg}{version} >= 90200) {
				$showtablespace = ', quote_ident(t.spcname) AS "pg_tablespace_name", quote_ident(pg_tablespace_location(t.oid)) AS "pg_tablespace_location"';
			}

			## If the schema or table has an underscore or a %, use a LIKE comparison
			if (defined $schema and length $schema) {
					push @search, 'n.nspname ' . ($schema =~ /[_%]/ ? 'LIKE ' : '= ') . $dbh->quote($schema);
			}
			if (defined $table and length $table) {
					push @search, 'c.relname ' . ($table =~ /[_%]/ ? 'LIKE ' : '= ') . $dbh->quote($table);
			}
			## All we can see is "table" or "view". Default is both
			my $typesearch = q{IN ('r','v')};
			if (defined $type and length $type) {
				if ($type =~ /\btable\b/i and $type !~ /\bview\b/i) {
					$typesearch = q{= 'r'};
				}
				elsif ($type =~ /\bview\b/i and $type !~ /\btable\b/i) {
					$typesearch = q{= 'v'};
				}
			}
			push @search, "c.relkind $typesearch";

			my $TSJOIN = 'pg_catalog.pg_tablespace t ON (t.oid = c.reltablespace)';
			if ($dbh->{private_dbdpg}{version} < 80000) {
				$TSJOIN = '(SELECT 0 AS oid, 0 AS spcname, 0 AS spclocation LIMIT 0) AS t ON (t.oid=1)';
			}
			my $whereclause = join "\n\t\t\t\t\t AND " => @search;
			$tbl_sql = qq{
                SELECT NULL::text AS "TABLE_CAT"
                     , quote_ident(n.nspname) AS "TABLE_SCHEM"
                     , quote_ident(c.relname) AS "TABLE_NAME"
                     , CASE
                             WHEN c.relkind = 'v' THEN
                                CASE WHEN quote_ident(n.nspname) ~ '^pg_' THEN 'SYSTEM VIEW' ELSE 'VIEW' END
                            ELSE
                                CASE WHEN quote_ident(n.nspname) ~ '^pg_' THEN 'SYSTEM TABLE' ELSE 'TABLE' END
                        END AS "TABLE_TYPE"
                     , d.description AS "REMARKS" $showtablespace $extracols
                FROM pg_catalog.pg_class AS c
                    LEFT JOIN pg_catalog.pg_description AS d
                        ON (c.oid = d.objoid AND c.tableoid = d.classoid AND d.objsubid = 0)
                    LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)
                    LEFT JOIN $TSJOIN
                WHERE $whereclause
                ORDER BY "TABLE_TYPE", "TABLE_CAT", "TABLE_SCHEM", "TABLE_NAME"
                };
		}
		my $sth = $dbh->prepare( $tbl_sql ) or return undef;
		$sth->execute();

		return $sth;
	}

	sub tables {
			my ($dbh, @args) = @_;
			my $attr = $args[4];
			my $sth = $dbh->table_info(@args) or return;
			my $tables = $sth->fetchall_arrayref() or return;
			my @tables = map { (! (ref $attr eq 'HASH' and $attr->{pg_noprefix})) ?
						"$_->[1].$_->[2]" : $_->[2] } @$tables;
			return @tables;
	}

	sub table_attributes {
		my ($dbh, $table) = @_;

		my $sth = $dbh->column_info(undef,undef,$table,undef);

		my %convert = (
			COLUMN_NAME   => 'NAME',
			DATA_TYPE     => 'TYPE',
			COLUMN_SIZE   => 'SIZE',
			NULLABLE      => 'NOTNULL',
			REMARKS       => 'REMARKS',
			COLUMN_DEF    => 'DEFAULT',
			pg_constraint => 'CONSTRAINT',
		);

		my $attrs = $sth->fetchall_arrayref(\%convert);

		for my $row (@$attrs) {
			# switch the column names
			for my $name (keys %$row) {
				$row->{ $convert{$name} } = $row->{$name};

				## Keep some original columns
				delete $row->{$name} unless ($name eq 'REMARKS' or $name eq 'NULLABLE');

			}
			# Moved check outside of loop as it was inverting the NOTNULL value for
			# attribute.
			# NOTNULL inverts the sense of NULLABLE
			$row->{NOTNULL} = ($row->{NOTNULL} ? 0 : 1);

			my @pri_keys = $dbh->primary_key( undef, undef, $table );
			$row->{PRIMARY_KEY} = scalar(grep { /^$row->{NAME}$/i } @pri_keys) ? 1 : 0;
		}

		return $attrs;

	}

	sub _calc_col_size {

		my $mod = shift;
		my $size = shift;


		if ((defined $size) and ($size > 0)) {
			return $size;
		} elsif ($mod > 0xffff) {
			my $prec = ($mod & 0xffff) - 4;
			$mod >>= 16;
			my $dig = $mod;
			return "$prec,$dig";
		} elsif ($mod >= 4) {
			return $mod - 4;
		} # else {
			# $rtn = $mod;
			# $rtn = undef;
		# }

		return;
	}


	sub type_info_all {
		my ($dbh) = @_;

		my $names =
			{
			 TYPE_NAME          => 0,
			 DATA_TYPE          => 1,
			 COLUMN_SIZE        => 2,
			 LITERAL_PREFIX     => 3,
			 LITERAL_SUFFIX     => 4,
			 CREATE_PARAMS      => 5,
			 NULLABLE           => 6,
			 CASE_SENSITIVE     => 7,
			 SEARCHABLE         => 8,
			 UNSIGNED_ATTRIBUTE => 9,
			 FIXED_PREC_SCALE   => 10,
			 AUTO_UNIQUE_VALUE  => 11,
			 LOCAL_TYPE_NAME    => 12,
			 MINIMUM_SCALE      => 13,
			 MAXIMUM_SCALE      => 14,
			 SQL_DATA_TYPE      => 15,
			 SQL_DATETIME_SUB   => 16,
			 NUM_PREC_RADIX     => 17,
			 INTERVAL_PRECISION => 18,
			};

		## This list is derived from dbi_sql.h in DBI, from types.c and types.h, and from the PG docs

		## Aids to make the list more readable:
		my $GIG = 1073741824;
		my $PS = 'precision/scale';
		my $LEN = 'length';
		my $UN;
		my $ti =
			[
			 $names,
# name     sql_type          size   pfx/sfx crt   n/c/s    +-/P/I   local       min max  sub rdx itvl

['unknown',  SQL_UNKNOWN_TYPE,  0,    $UN,$UN,   $UN,  1,0,0, $UN,0,0, 'UNKNOWN',   $UN,$UN,
             SQL_UNKNOWN_TYPE,                                                             $UN, $UN, $UN ],
['bytea',    SQL_VARBINARY,     $GIG, q{'},q{'}, $UN,  1,0,3, $UN,0,0, 'BYTEA',     $UN,$UN,
             SQL_VARBINARY,                                                                $UN, $UN, $UN ],
['bpchar',   SQL_CHAR,          $GIG, q{'},q{'}, $LEN, 1,1,3, $UN,0,0, 'CHARACTER', $UN,$UN,
             SQL_CHAR,                                                                     $UN, $UN, $UN ],
['numeric',  SQL_DECIMAL,       1000, $UN,$UN,   $PS,  1,0,2, 0,0,0,   'FLOAT',     0,1000,
             SQL_DECIMAL,                                                                  $UN, $UN, $UN ],
['numeric',  SQL_NUMERIC,       1000, $UN,$UN,   $PS,  1,0,2, 0,0,0,   'FLOAT',     0,1000,
             SQL_NUMERIC,                                                                  $UN, $UN, $UN ],
['int4',     SQL_INTEGER,       10,   $UN,$UN,   $UN,  1,0,2, 0,0,0,   'INTEGER',   0,0,
             SQL_INTEGER,                                                                  $UN, $UN, $UN ],
['int2',     SQL_SMALLINT,      5,    $UN,$UN,   $UN,  1,0,2, 0,0,0,   'SMALLINT',  0,0,
             SQL_SMALLINT,                                                                 $UN, $UN, $UN ],
['float4',   SQL_FLOAT,         6,    $UN,$UN,   $PS,  1,0,2, 0,0,0,   'FLOAT',     0,6,
             SQL_FLOAT,                                                                    $UN, $UN, $UN ],
['float8',   SQL_REAL,          15,   $UN,$UN,   $PS,  1,0,2, 0,0,0,   'REAL',      0,15,
             SQL_REAL,                                                                     $UN, $UN, $UN ],
['int8',     SQL_BIGINT,        20,   $UN,$UN,   $UN,  1,0,2, 0,0,0,   'INT8',   0,0,
             SQL_BIGINT,                                                                   $UN, $UN, $UN ],
['date',     SQL_DATE,          10,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'DATE',      0,0,
             SQL_DATE,                                                                     $UN, $UN, $UN ],
['tinterval',SQL_TIME,          18,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TINTERVAL', 0,6,
             SQL_TIME,                                                                     $UN, $UN, $UN ],
['timestamp',SQL_TIMESTAMP,     29,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TIMESTAMP', 0,6,
             SQL_TIMESTAMP,                                                                $UN, $UN, $UN ],
['text',     SQL_VARCHAR,       $GIG, q{'},q{'}, $LEN, 1,1,3, $UN,0,0, 'TEXT',      $UN,$UN,
             SQL_VARCHAR,                                                                  $UN, $UN, $UN ],
['bool',     SQL_BOOLEAN,       1,    q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'BOOLEAN',   $UN,$UN,
             SQL_BOOLEAN,                                                                  $UN, $UN, $UN ],
['array',    SQL_ARRAY,         1,    q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'ARRAY',     $UN,$UN,
             SQL_ARRAY,                                                                    $UN, $UN, $UN ],
['date',     SQL_TYPE_DATE,     10,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'DATE',      0,0,
             SQL_TYPE_DATE,                                                                $UN, $UN, $UN ],
['time',     SQL_TYPE_TIME,     18,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TIME',      0,6,
             SQL_TYPE_TIME,                                                                $UN, $UN, $UN ],
['timestamp',SQL_TYPE_TIMESTAMP,29,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TIMESTAMP', 0,6,
             SQL_TYPE_TIMESTAMP,                                                           $UN, $UN, $UN ],
['timetz',   SQL_TYPE_TIME_WITH_TIMEZONE,
                                29,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TIMETZ',    0,6,
             SQL_TYPE_TIME_WITH_TIMEZONE,                                                  $UN, $UN, $UN ],
['timestamptz',SQL_TYPE_TIMESTAMP_WITH_TIMEZONE,
                                29,   q{'},q{'}, $UN,  1,0,2, $UN,0,0, 'TIMESTAMPTZ',0,6,
             SQL_TYPE_TIMESTAMP_WITH_TIMEZONE,                                             $UN, $UN, $UN ],
		#
		# intentionally omitted: char, all geometric types, internal types
	];
	return $ti;
	}


	# Characters that need to be escaped by quote().
	my %esc = (
		q{'}  => '\\047', # '\\' . sprintf("%03o", ord("'")), # ISO SQL 2
		'\\' => '\\134', # '\\' . sprintf("%03o", ord("\\")),
	);

	# Set up lookup for SQL types we don't want to escape.
	my %no_escape = map { $_ => 1 }
		DBI::SQL_INTEGER, DBI::SQL_SMALLINT, DBI::SQL_BIGINT, DBI::SQL_DECIMAL,
		DBI::SQL_FLOAT, DBI::SQL_REAL, DBI::SQL_DOUBLE, DBI::SQL_NUMERIC;

	sub get_info {

		my ($dbh,$type) = @_;

		return undef unless defined $type and length $type;

		my %type = (

## Driver information:

     116 => ['SQL_ACTIVE_ENVIRONMENTS',             0                         ], ## unlimited
   10021 => ['SQL_ASYNC_MODE',                      2                         ], ## SQL_AM_STATEMENT
     120 => ['SQL_BATCH_ROW_COUNT',                 2                         ], ## SQL_BRC_EXPLICIT
     121 => ['SQL_BATCH_SUPPORT',                   3                         ], ## 12 SELECT_PROC + ROW_COUNT_PROC
       2 => ['SQL_DATA_SOURCE_NAME',                "dbi:Pg:$dbh->{Name}"     ],
       3 => ['SQL_DRIVER_HDBC',                     0                         ], ## not applicable
     135 => ['SQL_DRIVER_HDESC',                    0                         ], ## not applicable
       4 => ['SQL_DRIVER_HENV',                     0                         ], ## not applicable
      76 => ['SQL_DRIVER_HLIB',                     0                         ], ## not applicable
       5 => ['SQL_DRIVER_HSTMT',                    0                         ], ## not applicable
	   ## Not clear what should go here. Some things suggest 'Pg', others 'Pg.pm'. We'll use DBD::Pg for now
       6 => ['SQL_DRIVER_NAME',                     'DBD::Pg'                 ],
      77 => ['SQL_DRIVER_ODBC_VERSION',             '03.00'                   ],
       7 => ['SQL_DRIVER_VER',                      'DBDVERSION'              ], ## magic word
     144 => ['SQL_DYNAMIC_CURSOR_ATTRIBUTES1',      0                         ], ## we can FETCH, but not via methods
     145 => ['SQL_DYNAMIC_CURSOR_ATTRIBUTES2',      0                         ], ## same as above
      84 => ['SQL_FILE_USAGE',                      0                         ], ## SQL_FILE_NOT_SUPPORTED (this is good)
     146 => ['SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1', 519                       ], ## not clear what this refers to in DBD context
     147 => ['SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2', 5209                      ], ## see above
      81 => ['SQL_GETDATA_EXTENSIONS',              15                        ], ## 1+2+4+8
     149 => ['SQL_INFO_SCHEMA_VIEWS',               3932149                   ], ## not: assert, charset, collat, trans
     150 => ['SQL_KEYSET_CURSOR_ATTRIBUTES1',       0                         ], ## applies to us?
     151 => ['SQL_KEYSET_CURSOR_ATTRIBUTES2',       0                         ], ## see above
   10022 => ['SQL_MAX_ASYNC_CONCURRENT_STATEMENTS', 0                         ], ## unlimited, probably
       0 => ['SQL_MAX_DRIVER_CONNECTIONS',          'MAXCONNECTIONS'          ], ## magic word
     152 => ['SQL_ODBC_INTERFACE_CONFORMANCE',      1                         ], ## SQL_OIC_LEVEL_1
      10 => ['SQL_ODBC_VER',                        '03.00.0000'              ],
     153 => ['SQL_PARAM_ARRAY_ROW_COUNTS',          2                         ], ## correct?
     154 => ['SQL_PARAM_ARRAY_SELECTS',             3                         ], ## PAS_NO_SELECT
      11 => ['SQL_ROW_UPDATES',                     'N'                       ],
      14 => ['SQL_SEARCH_PATTERN_ESCAPE',           '\\'                      ],
      13 => ['SQL_SERVER_NAME',                     'CURRENTDB'               ], ## magic word
     166 => ['SQL_STANDARD_CLI_CONFORMANCE',        2                         ], ## ??
     167 => ['SQL_STATIC_CURSOR_ATTRIBUTES1',       519                       ], ## ??
     168 => ['SQL_STATIC_CURSOR_ATTRIBUTES2',       5209                      ], ## ??

## DBMS Information

      16 => ['SQL_DATABASE_NAME',                   'CURRENTDB'               ], ## magic word
      17 => ['SQL_DBMS_NAME',                       'PostgreSQL'              ],
      18 => ['SQL_DBMS_VERSION',                    'ODBCVERSION'             ], ## magic word

## Data source information

      20 => ['SQL_ACCESSIBLE_PROCEDURES',           'Y'                       ], ## is this really true?
      19 => ['SQL_ACCESSIBLE_TABLES',               'Y'                       ], ## is this really true?
      82 => ['SQL_BOOKMARK_PERSISTENCE',            0                         ],
      42 => ['SQL_CATALOG_TERM',                    ''                        ], ## empty = catalogs are not supported
   10004 => ['SQL_COLLATION_SEQ',                   'ENCODING'                ], ## magic word
      22 => ['SQL_CONCAT_NULL_BEHAVIOR',            0                         ], ## SQL_CB_NULL
      23 => ['SQL_CURSOR_COMMIT_BEHAVIOR',          1                         ], ## SQL_CB_CLOSE
      24 => ['SQL_CURSOR_ROLLBACK_BEHAVIOR',        1                         ], ## SQL_CB_CLOSE
   10001 => ['SQL_CURSOR_SENSITIVITY',              1                         ], ## SQL_INSENSITIVE
      25 => ['SQL_DATA_SOURCE_READ_ONLY',           'READONLY'                ], ## magic word
      26 => ['SQL_DEFAULT_TXN_ISOLATION',           'DEFAULTTXN'              ], ## magic word (2 or 8)
   10002 => ['SQL_DESCRIBE_PARAMETER',              'Y'                       ],
      36 => ['SQL_MULT_RESULT_SETS',                'Y'                       ],
      37 => ['SQL_MULTIPLE_ACTIVE_TXN',             'Y'                       ],
     111 => ['SQL_NEED_LONG_DATA_LEN',              'N'                       ],
      85 => ['SQL_NULL_COLLATION',                  0                         ], ## SQL_NC_HIGH
      40 => ['SQL_PROCEDURE_TERM',                  'function'                ], ## for now
      39 => ['SQL_SCHEMA_TERM',                     'schema'                  ],
      44 => ['SQL_SCROLL_OPTIONS',                  8                         ], ## not really for DBD?
      45 => ['SQL_TABLE_TERM',                      'table'                   ],
      46 => ['SQL_TXN_CAPABLE',                     2                         ], ## SQL_TC_ALL
      72 => ['SQL_TXN_ISOLATION_OPTION',            10                        ], ## 2+8
      47 => ['SQL_USER_NAME',                       $dbh->{CURRENT_USER}      ],

## Supported SQL

     169  => ['SQL_AGGREGATE_FUNCTIONS',            127                       ], ## all of 'em
     117  => ['SQL_ALTER_DOMAIN',                   31                        ], ## all but deferred
      86  => ['SQL_ALTER_TABLE',                    32639                     ], ## no collate
     114  => ['SQL_CATALOG_LOCATION',               0                         ],
   10003  => ['SQL_CATALOG_NAME',                   'N'                       ],
      41  => ['SQL_CATALOG_NAME_SEPARATOR',         ''                        ],
      92  => ['SQL_CATALOG_USAGE',                  0                         ],
      87  => ['SQL_COLUMN_ALIAS',                   'Y'                       ],
      74  => ['SQL_CORRELATION_NAME',               2                         ], ## SQL_CN_ANY
     127  => ['SQL_CREATE_ASSERTION',               0                         ],
     128  => ['SQL_CREATE_CHARACTER_SET',           0                         ],
     129  => ['SQL_CREATE_COLLATION',               0                         ],
     130  => ['SQL_CREATE_DOMAIN',                  23                        ], ## no collation, no defer
     131  => ['SQL_CREATE_SCHEMA',                  3                         ], ## 1+2 schema + authorize
     132  => ['SQL_CREATE_TABLE',                   13845                     ], ## no collation
     133  => ['SQL_CREATE_TRANSLATION',             0                         ],
     134  => ['SQL_CREATE_VIEW',                    9                         ], ## local + create?
     119  => ['SQL_DATETIME_LITERALS',              65535                     ], ## all?
     170  => ['SQL_DDL_INDEX',                      3                         ], ## create + drop
     136  => ['SQL_DROP_ASSERTION',                 0                         ],
     137  => ['SQL_DROP_CHARACTER_SET',             0                         ],
     138  => ['SQL_DROP_COLLATION',                 0                         ],
     139  => ['SQL_DROP_DOMAIN',                    7                         ],
     140  => ['SQL_DROP_SCHEMA',                    7                         ],
     141  => ['SQL_DROP_TABLE',                     7                         ],
     142  => ['SQL_DROP_TRANSLATION',               0                         ],
     143  => ['SQL_DROP_VIEW',                      7                         ],
      27  => ['SQL_EXPRESSIONS_IN_ORDERBY',         'Y'                       ],
      88  => ['SQL_GROUP_BY',                       2                         ], ## GROUP_BY_CONTAINS_SELECT
      28  => ['SQL_IDENTIFIER_CASE',                2                         ], ## SQL_IC_LOWER
      29  => ['SQL_IDENTIFIER_QUOTE_CHAR',          q{"}                      ],
     148  => ['SQL_INDEX_KEYWORDS',                 0                         ], ## not needed for Pg
     172  => ['SQL_INSERT_STATEMENT',               7                         ], ## 1+2+4 = all
      73  => ['SQL_INTEGRITY',                      'Y'                       ], ## e.g. ON DELETE CASCADE?
      89  => ['SQL_KEYWORDS',                       'KEYWORDS'                ], ## magic word
     113  => ['SQL_LIKE_ESCAPE_CLAUSE',             'Y'                       ],
      75  => ['SQL_NON_NULLABLE_COLUMNS',           1                         ], ## NNC_NOT_NULL
     115  => ['SQL_OJ_CAPABILITIES',                127                       ], ## all
      90  => ['SQL_ORDER_BY_COLUMNS_IN_SELECT',     'N'                       ],
      38  => ['SQL_OUTER_JOINS',                    'Y'                       ],
      21  => ['SQL_PROCEDURES',                     'Y'                       ],
      93  => ['SQL_QUOTED_IDENTIFIER_CASE',         3                         ], ## SQL_IC_SENSITIVE
      91  => ['SQL_SCHEMA_USAGE',                   31                        ], ## all
      94  => ['SQL_SPECIAL_CHARACTERS',             '$'                       ], ## there are actually many more...
     118  => ['SQL_SQL_CONFORMANCE',                4                         ], ## SQL92_INTERMEDIATE ??
      95  => ['SQL_SUBQUERIES',                     31                        ], ## all
      96  => ['SQL_UNION',                          3                         ], ## 1+2 = all

## SQL limits

     112  => ['SQL_MAX_BINARY_LITERAL_LEN',         0                         ],
      34  => ['SQL_MAX_CATALOG_NAME_LEN',           0                         ],
     108  => ['SQL_MAX_CHAR_LITERAL_LEN',           0                         ],
      30  => ['SQL_MAX_COLUMN_NAME_LEN',            'NAMEDATALEN'             ], ## magic word
      97  => ['SQL_MAX_COLUMNS_IN_GROUP_BY',        0                         ],
      98  => ['SQL_MAX_COLUMNS_IN_INDEX',           0                         ],
      99  => ['SQL_MAX_COLUMNS_IN_ORDER_BY',        0                         ],
     100  => ['SQL_MAX_COLUMNS_IN_SELECT',          0                         ],
     101  => ['SQL_MAX_COLUMNS_IN_TABLE',           250                       ], ## 250-1600 (depends on column types)
      31  => ['SQL_MAX_CURSOR_NAME_LEN',            'NAMEDATALEN'             ], ## magic word
   10005  => ['SQL_MAX_IDENTIFIER_LEN',             'NAMEDATALEN'             ], ## magic word
     102  => ['SQL_MAX_INDEX_SIZE',                 0                         ],
     102  => ['SQL_MAX_PROCEDURE_NAME_LEN',         'NAMEDATALEN'             ], ## magic word
     104  => ['SQL_MAX_ROW_SIZE',                   0                         ], ## actually 1.6 TB, but too big to represent here
     103  => ['SQL_MAX_ROW_SIZE_INCLUDES_LONG',     'Y'                       ],
      32  => ['SQL_MAX_SCHEMA_NAME_LEN',            'NAMEDATALEN'             ], ## magic word
     105  => ['SQL_MAX_STATEMENT_LEN',              0                         ],
      35  => ['SQL_MAX_TABLE_NAME_LEN',             'NAMEDATALEN'             ], ## magic word
     106  => ['SQL_MAX_TABLES_IN_SELECT',           0                         ],
     107  => ['SQL_MAX_USER_NAME_LEN',              'NAMEDATALEN'             ], ## magic word

## Scalar function information

      48  => ['SQL_CONVERT_FUNCTIONS',              2                         ], ## CVT_CAST only?
      49  => ['SQL_NUMERIC_FUNCTIONS',              16777215                  ], ## ?? all but some naming clashes: rand(om), trunc(ate), log10=ln, etc.
      50  => ['SQL_STRING_FUNCTIONS',               16280984                  ], ## ??
      51  => ['SQL_SYSTEM_FUNCTIONS',               0                         ], ## ??
     109  => ['SQL_TIMEDATE_ADD_INTERVALS',         0                         ], ## ?? no explicit timestampadd?
     110  => ['SQL_TIMEDATE_DIFF_INTERVALS',        0                         ], ## ??
      52  => ['SQL_TIMEDATE_FUNCTIONS',             1966083                   ],

## Conversion information - all but BIT, LONGVARBINARY, and LONGVARCHAR

      53  => ['SQL_CONVERT_BIGINT',                 1830399                    ],
      54  => ['SQL_CONVERT_BINARY',                 1830399                    ],
      55  => ['SQL_CONVERT_BIT',                    0                          ],
      56  => ['SQL_CONVERT_CHAR',                   1830399                    ],
      57  => ['SQL_CONVERT_DATE',                   1830399                    ],
      58  => ['SQL_CONVERT_DECIMAL',                1830399                    ],
      59  => ['SQL_CONVERT_DOUBLE',                 1830399                    ],
      60  => ['SQL_CONVERT_FLOAT',                  1830399                    ],
      61  => ['SQL_CONVERT_INTEGER',                1830399                    ],
     123  => ['SQL_CONVERT_INTERVAL_DAY_TIME',      1830399                    ],
     124  => ['SQL_CONVERT_INTERVAL_YEAR_MONTH',    1830399                    ],
      71  => ['SQL_CONVERT_LONGVARBINARY',          0                          ],
      62  => ['SQL_CONVERT_LONGVARCHAR',            0                          ],
      63  => ['SQL_CONVERT_NUMERIC',                1830399                    ],
      64  => ['SQL_CONVERT_REAL',                   1830399                    ],
      65  => ['SQL_CONVERT_SMALLINT',               1830399                    ],
      66  => ['SQL_CONVERT_TIME',                   1830399                    ],
      67  => ['SQL_CONVERT_TIMESTAMP',              1830399                    ],
      68  => ['SQL_CONVERT_TINYINT',                1830399                    ],
      69  => ['SQL_CONVERT_VARBINARY',              0                          ],
      70  => ['SQL_CONVERT_VARCHAR',                1830399                    ],
     122  => ['SQL_CONVERT_WCHAR',                  0                          ],
     125  => ['SQL_CONVERT_WLONGVARCHAR',           0                          ],
     126  => ['SQL_CONVERT_WVARCHAR',               0                          ],

		); ## end of %type

		## Put both numbers and names into a hash
		my %t;
		for (keys %type) {
			$t{$_} = $type{$_}->[1];
			$t{$type{$_}->[0]} = $type{$_}->[1];
		}

		return undef unless exists $t{$type};

		my $ans = $t{$type};

		if ($ans eq 'NAMEDATALEN') {
			return $dbh->selectall_arrayref('SHOW max_identifier_length')->[0][0];
		}
		elsif ($ans eq 'ODBCVERSION') {
			my $version = $dbh->{private_dbdpg}{version};
			return '00.00.0000' unless $version =~ /^(\d\d?)(\d\d)(\d\d)$/o;
			return sprintf '%02d.%02d.%.2d00', $1,$2,$3;
		}
		elsif ($ans eq 'DBDVERSION') {
			my $simpleversion = $DBD::Pg::VERSION;
			$simpleversion =~ s/_/./g;
			return sprintf '%02d.%02d.%1d%1d%1d%1d', split (/\./, "$simpleversion.0.0.0.0.0.0");
		}
		 elsif ($ans eq 'MAXCONNECTIONS') {
			 return $dbh->selectall_arrayref('SHOW max_connections')->[0][0];
		 }
		 elsif ($ans eq 'ENCODING') {
			 return $dbh->selectall_arrayref('SHOW server_encoding')->[0][0];
		 }
		 elsif ($ans eq 'KEYWORDS') {
			## http://www.postgresql.org/docs/current/static/sql-keywords-appendix.html
			## Basically, we want ones that are 'reserved' for PostgreSQL but not 'reserved' in SQL:2003
			## 
			return join ',' => (qw(ANALYSE ANALYZE ASC DEFERRABLE DESC DO FREEZE ILIKE INITIALLY ISNULL LIMIT NOTNULL OFF OFFSET PLACING RETURNING VERBOSE));
		 }
		 elsif ($ans eq 'CURRENTDB') {
			 return $dbh->selectall_arrayref('SELECT pg_catalog.current_database()')->[0][0];
		 }
		 elsif ($ans eq 'READONLY') {
			 my $SQL = q{SELECT CASE WHEN setting = 'on' THEN 'Y' ELSE 'N' END FROM pg_settings WHERE name = 'transaction_read_only'};
			 my $info = $dbh->selectall_arrayref($SQL);
			 return defined $info->[0] ? $info->[0][0] : 'N';
		 }
		 elsif ($ans eq 'DEFAULTTXN') {
			 my $SQL = q{SELECT CASE WHEN setting = 'read committed' THEN 2 ELSE 8 END FROM pg_settings WHERE name = 'default_transaction_isolation'};
			 my $info = $dbh->selectall_arrayref($SQL);
			 return defined $info->[0] ? $info->[0][0] : 2;
		 }

		 return $ans;
	} # end of get_info

	sub private_attribute_info {
		return {
				pg_async_status                => undef,
				pg_bool_tf                     => undef,
				pg_db                          => undef,
				pg_default_port                => undef,
				pg_enable_utf8                 => undef,
				pg_utf8_flag                   => undef,
				pg_errorlevel                  => undef,
				pg_expand_array                => undef,
				pg_host                        => undef,
				pg_INV_READ                    => undef,
				pg_INV_WRITE                   => undef,
				pg_lib_version                 => undef,
				pg_options                     => undef,
				pg_pass                        => undef,
				pg_pid                         => undef,
				pg_placeholder_dollaronly      => undef,
				pg_placeholder_nocolons        => undef,
				pg_port                        => undef,
				pg_prepare_now                 => undef,
				pg_protocol                    => undef,
				pg_server_prepare              => undef,
				pg_server_version              => undef,
				pg_socket                      => undef,
				pg_standard_conforming_strings => undef,
				pg_switch_prepared             => undef,
				pg_user                        => undef,
		};
	}
}


{
	package DBD::Pg::st;

	sub parse_trace_flag {
		my ($h, $flag) = @_;
		return DBD::Pg->parse_trace_flag($flag);
	}

	sub bind_param_array {

		## Binds an array of data to a specific placeholder in a statement
		## The DBI version is broken, so we implement a near-copy here

		my $sth = shift;
		my ($p_id, $value_array, $attr) = @_;

		## Bail if the second arg is not undef or an arrayref
		return $sth->set_err(1, "Value for parameter $p_id must be a scalar or an arrayref, not a ".ref($value_array))
			if defined $value_array and ref $value_array and ref $value_array ne 'ARRAY';

		## Bail if the first arg is not a number
		return $sth->set_err(1, q{Can't use named placeholders for non-driver supported bind_param_array})
			unless DBI::looks_like_number($p_id); # because we rely on execute(@ary) here

		## Store the list of items in the hash (will be undef or an arrayref)
		$sth->{ParamArrays}{$p_id} = $value_array;

		## If any attribs were passed in, we need to call bind_param
		return $sth->bind_param($p_id, '', $attr) if $attr; ## This is the big change so -w does not complain

		return 1;
	} ## end bind_param_array

	sub private_attribute_info {
		return {
				pg_async                  => undef,
				pg_bound                  => undef,
				pg_current_row            => undef,
				pg_direct                 => undef,
				pg_numbound               => undef,
				pg_cmd_status             => undef,
				pg_oid_status             => undef,
				pg_placeholder_dollaronly => undef,
				pg_placeholder_nocolons   => undef,
				pg_prepare_name           => undef,
				pg_prepare_now            => undef,
				pg_segments               => undef,
				pg_server_prepare         => undef,
				pg_size                   => undef,
				pg_switch_prepared        => undef,
				pg_type                   => undef,
		};
    }

} ## end st section

1;

__END__

#line 4362
