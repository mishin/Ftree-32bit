#line 1 "DBD/Oracle.pm"
#   Oracle.pm
#
#   Copyright (c) 1994-2005 Tim Bunce, Ireland
#   Copyright (c) 2006-2008 John Scoles (The Pythian Group), Canada
#
#   See COPYRIGHT section in the documentation below

require 5.006;

my $ORACLE_ENV  = ($^O eq 'VMS') ? 'ORA_ROOT' : 'ORACLE_HOME';

{
package DBD::Oracle;
$DBD::Oracle::VERSION = '1.74';
BEGIN {
  $DBD::Oracle::AUTHORITY = 'cpan:PYTHIAN';
}
# ABSTRACT: Oracle database driver for the DBI module

    use DBI ();
    use DynaLoader ();
    use Exporter ();
    use DBD::Oracle::Object();

    # for dev version
    $DBD::Oracle::VERSION ||= '1.00';

    @ISA = qw(DynaLoader Exporter);
    %EXPORT_TAGS = (
      ora_types => [ qw(
	    ORA_VARCHAR2 ORA_STRING ORA_NUMBER ORA_LONG ORA_ROWID ORA_DATE
	    ORA_RAW ORA_LONGRAW ORA_CHAR ORA_CHARZ ORA_MLSLABEL ORA_XMLTYPE
	    ORA_CLOB ORA_BLOB ORA_RSET ORA_VARCHAR2_TABLE ORA_NUMBER_TABLE
	    SQLT_INT SQLT_FLT ORA_OCI SQLT_CHR SQLT_BIN
	) ],
        ora_session_modes => [ qw( ORA_SYSDBA ORA_SYSOPER ORA_SYSASM ORA_SYSBACKUP ORA_SYSDG ORA_SYSKM) ],
        ora_fetch_orient  => [ qw( OCI_FETCH_NEXT OCI_FETCH_CURRENT OCI_FETCH_FIRST
        			   OCI_FETCH_LAST OCI_FETCH_PRIOR OCI_FETCH_ABSOLUTE
        			   OCI_FETCH_RELATIVE)],
    	ora_exe_modes     => [ qw( OCI_STMT_SCROLLABLE_READONLY)],
    	ora_fail_over     => [ qw( OCI_FO_END OCI_FO_ABORT OCI_FO_REAUTH OCI_FO_BEGIN
    				   OCI_FO_ERROR OCI_FO_NONE OCI_FO_SESSION OCI_FO_SELECT
    				   OCI_FO_TXNAL OCI_FO_RETRY)],
    );
    @EXPORT_OK = qw(OCI_FETCH_NEXT OCI_FETCH_CURRENT OCI_FETCH_FIRST OCI_FETCH_LAST OCI_FETCH_PRIOR
    		    OCI_FETCH_ABSOLUTE 	OCI_FETCH_RELATIVE ORA_OCI SQLCS_IMPLICIT SQLCS_NCHAR ora_env_var ora_cygwin_set_env );
    #unshift @EXPORT_OK, 'ora_cygwin_set_env' if $^O eq 'cygwin';
    Exporter::export_ok_tags(qw(ora_types ora_session_modes ora_fetch_orient ora_exe_modes ora_fail_over));

    my $Revision = substr(q$Revision: 1.103 $, 10);

    require_version DBI 1.51;

    DBD::Oracle->bootstrap($DBD::Oracle::VERSION);

    $drh = undef;	# holds driver handle once initialized

    sub CLONE {
        $drh = undef ;
    }

    sub driver{
        return $drh if $drh;

        my($class, $attr) = @_;
        my $oci = DBD::Oracle::ORA_OCI();

        $class .= "::dr";

        # not a 'my' since we use it above to prevent multiple drivers

        $drh = DBI::_new_drh($class, {
            'Name' => 'Oracle',
            'Version' => $VERSION,
            'Err'    => \my $err,
            'Errstr' => \my $errstr,
            'Attribution' => "DBD::Oracle $VERSION using OCI$oci by Tim Bunce",
        });

        DBD::Oracle::dr::init_oci($drh) ;
        $drh->STORE('ShowErrorStatement', 1);

        DBD::Oracle::db->install_method($_) for qw/
            ora_lob_read
            ora_lob_write
            ora_lob_append
            ora_lob_trim
            ora_lob_length
            ora_lob_chunk_size
            ora_lob_is_init
            ora_nls_parameters
            ora_can_unicode
            ora_can_taf
            ora_db_startup
            ora_db_shutdown
        /;

        DBD::Oracle::st->install_method($_) for qw/
            ora_fetch_scroll
            ora_scroll_position
            ora_ping
            ora_stmt_type_name
            ora_stmt_type
        /;

        $drh;
    }


    END {
	# Used to silence 'Bad free() ...' warnings caused by bugs in Oracle's code
	# being detected by Perl's malloc.
	$ENV{PERL_BADFREE} = 0;
	#undef $Win32::TieRegistry::Registry if $Win32::TieRegistry::Registry;
    }

    sub AUTOLOAD {
    	(my $constname = $AUTOLOAD) =~ s/.*:://;
    	my $val = constant($constname);
    	*$AUTOLOAD = sub { $val };
    	goto &$AUTOLOAD;
    }

}


{   package                     # hide from PAUSE
    DBD::Oracle::dr;            # ====== DRIVER ======
    use strict;

    my %dbnames = ();	# holds list of known databases (oratab + tnsnames)

    sub load_dbnames {
	my ($drh) = @_;
	my $debug = $drh->debug;
	my $oracle_home = DBD::Oracle::ora_env_var($ORACLE_ENV);
	local *FH;
	my $d;

	if (($^O eq 'MSWin32') or ($^O =~ /cygwin/i)) {
	  # XXX experimental, will probably change
	  $drh->trace_msg("Trying to fetch ORACLE_HOME and ORACLE_SID from the registry.\n")
		if $debug;
	  my $sid = DBD::Oracle::ora_env_var("ORACLE_SID");
	  $dbnames{$sid} = $oracle_home if $sid and $oracle_home;
	  $drh->trace_msg("Found $sid \@ $oracle_home.\n") if $debug && $sid;
	}

	# get list of 'local' database SIDs from oratab
	foreach $d (qw(/etc /var/opt/oracle), DBD::Oracle::ora_env_var("TNS_ADMIN")) {
	    next unless defined $d;
	    next unless open(FH, "<$d/oratab");
	    $drh->trace_msg("Loading $d/oratab\n") if $debug;
	    my $ot;
	    while (defined($ot = <FH>)) {
		next unless $ot =~ m/^\s*(\w+)\s*:\s*(.*?)\s*:/;
		$dbnames{$1} = $2;	# store ORACLE_HOME value
		$drh->trace_msg("Found $1 \@ $2.\n") if $debug;
	    }
	    close FH;
	    last;
	}

	# get list of 'remote' database connection identifiers
	my @tns_admin = ( DBD::Oracle::ora_env_var("TNS_ADMIN"), '.' );
	push @tns_admin, map { join '/', $oracle_home, $_ }
                         'network/admin',	# OCI 7 and 8.1
                         'net80/admin',	    # OCI 8.0
	    if $oracle_home;
	push @tns_admin, '/var/opt/oracle', '/etc';

    TNS_ADMIN:
	foreach $d ( grep { $_ and -d $_ } @tns_admin  ) {
	    open FH, '<', "$d/tnsnames.ora" or next TNS_ADMIN;

	    $drh->trace_msg("Loading $d/tnsnames.ora\n") if $debug;
	    local *_;
	    while (<FH>) {
		next unless m/^\s*([-\w\.]+)\s*=/;
		my $name = $1;
		$drh->trace_msg("Found $name. ".($dbnames{$name} ? "(oratab entry overridden)" : "")."\n")
		    if $debug;
		$dbnames{$name} = 0; # exists but false (to distinguish from oratab)
	    }
	    close FH;
	    last;
	}

	$dbnames{0} = 1;	# mark as loaded (even if empty)
    }

    sub data_sources {
	my $drh = shift;
	load_dbnames($drh) unless %dbnames;
	my @names = sort  keys %dbnames;
	my @sources = map { $_ ? ("dbi:Oracle:$_") : () } @names;
	return @sources;
    }


    sub connect {
	my ($drh, $dbname, $user, $auth, $attr)= @_;

    # Make 'sid=whatever' an alias for 'whatever'.
    # see  RT91775
    $dbname =~ s/^sid=([^;]+)$/$1/;

	if ($dbname =~ /;/) {
	    my ($n,$v);
	    $dbname =~ s/^\s+//;
	    $dbname =~ s/\s+$//;
	    my @dbname = map {
		($n,$v) = split /\s*=\s*/, $_, -1;
		Carp::carp("DSN component '$_' is not in 'name=value' format")
		    unless defined $v && defined $n;
                (uc($n), $v)
	    } split /\s*;\s*/, $dbname;
	    my %dbname = ( PROTOCOL => 'tcp', @dbname );

	    if ((exists $dbname{SERVER}) and ($dbname{SERVER} eq "POOLED")) {
               $attr->{ora_drcp}=1;
	    }

	    # extract main attributes for connect_data portion
	    my @connect_data_attr = qw(SID INSTANCE_NAME SERVER SERVICE_NAME );
	    my %connect_data = map { ($_ => delete $dbname{$_}) }
		grep { exists $dbname{$_} } @connect_data_attr;

	    my $connect_data = join "", map { "($_=$connect_data{$_})" } keys %connect_data;
	    return $drh->DBI::set_err(-1,
		"Can't connect using this syntax without specifying a HOST and one of @connect_data_attr")
		unless $dbname{HOST} and %connect_data;

	    my @addrs = map { "($_=$dbname{$_})" } keys %dbname;
	    my $addrs = join "", @addrs;
	    if ($dbname{PORT}) {
		$addrs = "(ADDRESS=$addrs)";
	    }
	    else {
		$addrs = "(ADDRESS_LIST=(ADDRESS=$addrs(PORT=1526))"
				     . "(ADDRESS=$addrs(PORT=1521)))";
	    }
	    $dbname = "(DESCRIPTION=$addrs(CONNECT_DATA=$connect_data))";
	    $drh->trace_msg("connect using '$dbname'");
	}

	# If the application is asking for specific database
	# then we may have to mung the dbname

	$dbname = $1 if !$dbname && $user && $user =~ s/\@(.*)//s;

	$drh->trace_msg("$ORACLE_ENV environment variable not set\n")
		if !$ENV{$ORACLE_ENV} and $^O ne "MSWin32";

	# create a 'blank' dbh

	$user = '' if not defined $user;
        (my $user_only = $user) =~ s:/.*::;

        if (substr($dbname,-7,7) eq ':POOLED'){
           $dbname=substr($dbname,0,-7);
           $attr->{ora_drcp} = 1;
        }
        elsif ($ENV{ORA_DRCP}){
	   $attr->{ora_drcp} = 1;
	}

	my ($dbh, $dbh_inner) = DBI::_new_dbh($drh, {
	    'Name' => $dbname,
	    'dbi_imp_data' => $attr->{dbi_imp_data},
	    # these two are just for backwards compatibility
	    'USER' => uc $user_only, 'CURRENT_USER' => uc $user_only,
	    });

	# Call Oracle OCI logon func in Oracle.xs file
	# and populate internal handle data.


	if (exists $ENV{ORA_DRCP_CLASS}) {
	   $attr->{ora_drcp_class} = $ENV{ORA_DRCP_CLASS}
	}
	if($attr->{ora_drcp_class}){
	# if using ora_drcp_class it cannot contain more than 1024 bytes
	# and cannot contain a *
	   if (index($attr->{ora_drcp_class},'*') !=-1){
		Carp::croak("ora_drcp_class cannot contain a '*'!");
	   }
	   if (length($attr->{ora_drcp_class}) > 1024){
		Carp::croak("ora_drcp_class must be less than 1024 characters!");
	   }
	}
	if (exists $ENV{ORA_DRCP_MIN}) {
	   $attr->{ora_drcp_min} = $ENV{ORA_DRCP_MIN}
	}
	if (exists $ENV{ORA_DRCP_MAX}) {
	   $attr->{ora_drcp_max} = $ENV{ORA_DRCP_MAX}
	}
	if (exists $ENV{ORA_DRCP_INCR}) {
	   $attr->{ora_drcp_incr} = $ENV{ORA_DRCP_INCR}
	}

	{
	   local @SIG{ @{ $attr->{ora_connect_with_default_signals} } }
          if $attr->{ora_connect_with_default_signals};
	   DBD::Oracle::db::_login($dbh, $dbname, $user, $auth, $attr)
	      or return undef;
	}

	unless (length $user_only) {
	    $user_only = $dbh->selectrow_array(q{
		SELECT SYS_CONTEXT('userenv','session_user') FROM DUAL
	    })||'';
	    $dbh_inner->{Username} = $user_only;
	    # these two are just for backwards compatibility
	    $dbh_inner->{USER} = $dbh_inner->{CURRENT_USER} = uc $user_only;
	}
	if ($ENV{ORA_DBD_NCS_BUFFER}){
	    $dbh->{'ora_ncs_buff_mtpl'}= $ENV{ORA_DBD_NCS_BUFFER};
	}
	$dbh;

    }

     sub private_attribute_info {
            return { ora_home_key=>undef};
    }

}


{   package                     # hide from PAUSE
    DBD::Oracle::db;            # ====== DATABASE ======
    use strict;
    use DBI qw(:sql_types);

    sub prepare {
	my($dbh, $statement, @attribs)= @_;

	# create a 'blank' sth

	my $sth = DBI::_new_sth($dbh, {
	    'Statement' => $statement,
	    });

	# Call Oracle OCI parse func in Oracle.xs file.
	# and populate internal handle data.

	DBD::Oracle::st::_prepare($sth, $statement, @attribs)
	    or return undef;

	$sth;
    }

#Ah! I see you have the machine that goes PING!!
#Yes!! We leased it from the company that made it
#then the cost came out of the operating budget
#not the capital ...

    sub ping {
	my($dbh) = @_;
	local $@;
	my $ok = 0;
	eval {
	    local $SIG{__DIE__};
	    local $SIG{__WARN__};
	    $ok=ora_ping($dbh);
	};
	return ($@) ? 0 : $ok;
    }


    sub get_info {
	my($dbh, $info_type) = @_;
	require DBD::Oracle::GetInfo;
	my $v = $DBD::Oracle::GetInfo::info{int($info_type)};
	$v = $v->($dbh) if ref $v eq 'CODE';
	return $v;
    }

    sub private_attribute_info { #this should only be for ones that have setters and getters
        return { ora_max_nested_cursors	=> undef,
                 ora_array_chunk_size	=> undef,
                 ora_ph_type		=> undef,
                 ora_ph_csform		=> undef,
                 ora_parse_error_offset => undef,
                 ora_dbh_share		=> undef,
                 ora_envhp		=> undef,
                 ora_svchp		=> undef,
                 ora_errhp		=> undef,
                 ora_init_mode		=> undef,
                 ora_charset		=> undef,
                 ora_ncharset		=> undef,
                 ora_session_mode	=> undef,
                 ora_verbose		=> undef,
                 ora_oci_success_warn	=> undef,
                 ora_objects		=> undef,
                 ora_ncs_buff_mtpl	=> undef,
                 ora_drcp		=> undef,
                 ora_drcp_class		=> undef,
                 ora_drcp_min		=> undef,
                 ora_drcp_max		=> undef,
                 ora_drcp_incr		=> undef,
                 ora_oratab_orahome	=> undef,
                 ora_module_name	=> undef,
                 ora_driver_name	=> undef,
                 ora_client_info	=> undef,
                 ora_client_identifier	=> undef,
                 ora_action		=> undef,
                 ora_taf_function	=> undef,
                 };
    }


    sub table_info {
	my($dbh, $CatVal, $SchVal, $TblVal, $TypVal) = @_;
	# XXX add knowledge of temp tables, etc
	# SQL/CLI (ISO/IEC JTC 1/SC 32 N 0595), 6.63 Tables
	if (ref $CatVal eq 'HASH') {
	    ($CatVal, $SchVal, $TblVal, $TypVal) =
		@$CatVal{'TABLE_CAT','TABLE_SCHEM','TABLE_NAME','TABLE_TYPE'};
	}
	my @Where = ();
	my $SQL;
	if ( defined $CatVal && $CatVal eq '%' && (!defined $SchVal || $SchVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19a
		$SQL = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , NULL TABLE_TYPE
     , NULL REMARKS
  FROM DUAL
SQL
	}
	elsif ( defined $SchVal && $SchVal eq '%' && (!defined $CatVal || $CatVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19b
		$SQL = <<'SQL';
SELECT NULL TABLE_CAT
     , s    TABLE_SCHEM
     , NULL TABLE_NAME
     , NULL TABLE_TYPE
     , NULL REMARKS
  FROM
(
  SELECT USERNAME s FROM ALL_USERS
  UNION
  SELECT 'PUBLIC' s FROM DUAL
)
 ORDER BY TABLE_SCHEM
SQL
	}
	elsif ( defined $TypVal && $TypVal eq '%' && (!defined $CatVal || $CatVal eq '') && (!defined $SchVal || $SchVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19c
		$SQL = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , t.tt TABLE_TYPE
     , NULL REMARKS
  FROM
(
  SELECT 'TABLE'    tt FROM DUAL
    UNION
  SELECT 'VIEW'     tt FROM DUAL
    UNION
  SELECT 'SYNONYM'  tt FROM DUAL
    UNION
  SELECT 'SEQUENCE' tt FROM DUAL
) t
 ORDER BY TABLE_TYPE
SQL
	}
	else {
		$SQL = <<'SQL';
SELECT *
  FROM
(
  SELECT /*+ CHOOSE */
       NULL         TABLE_CAT
     , t.OWNER      TABLE_SCHEM
     , t.TABLE_NAME TABLE_NAME
     , decode(t.OWNER
	  , 'SYS'    , 'SYSTEM '
	  , 'SYSTEM' , 'SYSTEM '
          , '' ) || t.TABLE_TYPE TABLE_TYPE
     , c.COMMENTS   REMARKS
  FROM ALL_TAB_COMMENTS c
     , ALL_CATALOG      t
 WHERE c.OWNER      (+) = t.OWNER
   AND c.TABLE_NAME (+) = t.TABLE_NAME
   AND c.TABLE_TYPE (+) = t.TABLE_TYPE
)
SQL
		if ( defined $SchVal ) {
			push @Where, "TABLE_SCHEM LIKE '$SchVal' ESCAPE '\\'";
		}
		if ( defined $TblVal ) {
			push @Where, "TABLE_NAME  LIKE '$TblVal' ESCAPE '\\'";
		}
		if ( defined $TypVal ) {
			my $table_type_list;
			$TypVal =~ s/^\s+//;
			$TypVal =~ s/\s+$//;
			my @ttype_list = split (/\s*,\s*/, $TypVal);
			foreach my $table_type (@ttype_list) {
				if ($table_type !~ /^'.*'$/) {
					$table_type = "'" . $table_type . "'";
				}
				$table_type_list = join(", ", @ttype_list);
			}
			push @Where, "TABLE_TYPE IN ($table_type_list)";
		}
		$SQL .= ' WHERE ' . join("\n   AND ", @Where ) . "\n" if @Where;
		$SQL .= " ORDER BY TABLE_TYPE, TABLE_SCHEM, TABLE_NAME\n";
	}
	my $sth = $dbh->prepare($SQL) or return undef;
	$sth->execute or return undef;
	$sth;
}


    sub primary_key_info {
        my($dbh, $catalog, $schema, $table) = @_;
        if (ref $catalog eq 'HASH') {
            ($schema, $table) = @$catalog{'TABLE_SCHEM','TABLE_NAME'};
            $catalog = undef;
        }
	my $SQL = <<'SQL';
SELECT *
  FROM
(
  SELECT /*+ CHOOSE */
         NULL              TABLE_CAT
       , c.OWNER           TABLE_SCHEM
       , c.TABLE_NAME      TABLE_NAME
       , c.COLUMN_NAME     COLUMN_NAME
       , c.POSITION        KEY_SEQ
       , c.CONSTRAINT_NAME PK_NAME
    FROM ALL_CONSTRAINTS   p
       , ALL_CONS_COLUMNS  c
   WHERE p.OWNER           = c.OWNER
     AND p.TABLE_NAME      = c.TABLE_NAME
     AND p.CONSTRAINT_NAME = c.CONSTRAINT_NAME
     AND p.CONSTRAINT_TYPE = 'P'
)
 WHERE TABLE_SCHEM = ?
   AND TABLE_NAME  = ?
 ORDER BY TABLE_SCHEM, TABLE_NAME, KEY_SEQ
SQL
#warn "@_\n$Sql ($schema, $table)";
	my $sth = $dbh->prepare($SQL) or return undef;
	$sth->execute($schema, $table) or return undef;
	$sth;
}

    sub foreign_key_info {
	my $dbh  = shift;
	my $attr = ( ref $_[0] eq 'HASH') ? $_[0] : {
	    'UK_TABLE_SCHEM' => $_[1],'UK_TABLE_NAME ' => $_[2]
	   ,'FK_TABLE_SCHEM' => $_[4],'FK_TABLE_NAME ' => $_[5] };
	my $SQL = <<'SQL';  # XXX: DEFERABILITY
SELECT *
  FROM
(
  SELECT /*+ CHOOSE */
         to_char( NULL )    UK_TABLE_CAT
       , uk.OWNER           UK_TABLE_SCHEM
       , uk.TABLE_NAME      UK_TABLE_NAME
       , uc.COLUMN_NAME     UK_COLUMN_NAME
       , to_char( NULL )    FK_TABLE_CAT
       , fk.OWNER           FK_TABLE_SCHEM
       , fk.TABLE_NAME      FK_TABLE_NAME
       , fc.COLUMN_NAME     FK_COLUMN_NAME
       , uc.POSITION        ORDINAL_POSITION
       , 3                  UPDATE_RULE
       , decode( fk.DELETE_RULE, 'CASCADE', 0, 'RESTRICT', 1, 'SET NULL', 2, 'NO ACTION', 3, 'SET DEFAULT', 4 )
                            DELETE_RULE
       , fk.CONSTRAINT_NAME FK_NAME
       , uk.CONSTRAINT_NAME UK_NAME
       , to_char( NULL )    DEFERABILITY
       , decode( uk.CONSTRAINT_TYPE, 'P', 'PRIMARY', 'U', 'UNIQUE')
                            UNIQUE_OR_PRIMARY
    FROM ALL_CONSTRAINTS    uk
       , ALL_CONS_COLUMNS   uc
       , ALL_CONSTRAINTS    fk
       , ALL_CONS_COLUMNS   fc
   WHERE uk.OWNER            = uc.OWNER
     AND uk.CONSTRAINT_NAME  = uc.CONSTRAINT_NAME
     AND fk.OWNER            = fc.OWNER
     AND fk.CONSTRAINT_NAME  = fc.CONSTRAINT_NAME
     AND uk.CONSTRAINT_TYPE IN ('P','U')
     AND fk.CONSTRAINT_TYPE  = 'R'
     AND uk.CONSTRAINT_NAME  = fk.R_CONSTRAINT_NAME
     AND uk.OWNER            = fk.R_OWNER
     AND uc.POSITION         = fc.POSITION
)
 WHERE 1              = 1
SQL
	my @BindVals = ();
	while ( my ( $k, $v ) = each %$attr ) {
	    if ( $v ) {
		$SQL .= "   AND $k = ?\n";
		push @BindVals, $v;
	    }
	}
	$SQL .= " ORDER BY UK_TABLE_SCHEM, UK_TABLE_NAME, FK_TABLE_SCHEM, FK_TABLE_NAME, ORDINAL_POSITION\n";
	my $sth = $dbh->prepare( $SQL ) or return undef;
	$sth->execute( @BindVals ) or return undef;
	$sth;
    }


    sub column_info {
        my $dbh  = shift;
        my $attr = ( ref $_[0] eq 'HASH') ? $_[0] : {
            'TABLE_SCHEM' => $_[1],'TABLE_NAME' => $_[2],'COLUMN_NAME' => $_[3] };
        my $ora_server_version = ora_server_version($dbh);
        my($typecase,$typecaseend, $choose) = ('','','/*+ CHOOSE */');
        if ($ora_server_version->[0] >= 8) {
            $typecase = <<'SQL';
CASE WHEN tc.DATA_TYPE LIKE 'TIMESTAMP% WITH% TIME ZONE' THEN 95
     WHEN tc.DATA_TYPE LIKE 'TIMESTAMP%'                 THEN 93
     WHEN tc.DATA_TYPE LIKE 'INTERVAL DAY% TO SECOND%'   THEN 110
     WHEN tc.DATA_TYPE LIKE 'INTERVAL YEAR% TO MONTH'    THEN 107
ELSE
SQL
            $typecaseend = 'END';
        } elsif ($ora_server_version->[0] >= 11) {
            # rt91217 CHOOSE hint deprecated
            $choose = '';
        }
        my $char_length = $ora_server_version->[0] < 9 ? 'DATA_LENGTH':'CHAR_LENGTH';
        my $SQL = <<"SQL";
SELECT *
  FROM
(
  SELECT $choose
         to_char( NULL )     TABLE_CAT
       , tc.OWNER            TABLE_SCHEM
       , tc.TABLE_NAME       TABLE_NAME
       , tc.COLUMN_NAME      COLUMN_NAME
       , $typecase decode( tc.DATA_TYPE
         , 'MLSLABEL' , -9106
         , 'ROWID'    , -9104
         , 'UROWID'   , -9104
         , 'BFILE'    ,    -4 -- 31?
         , 'LONG RAW' ,    -4
         , 'RAW'      ,    -3
         , 'LONG'     ,    -1
         , 'UNDEFINED',     0
         , 'CHAR'     ,     1
         , 'NCHAR'    ,     1
         , 'NUMBER'   ,     decode( tc.DATA_SCALE, NULL, 8, 3 )
         , 'FLOAT'    ,     8
         , 'VARCHAR2' ,    12
         , 'NVARCHAR2',    12
         , 'BLOB'     ,    30
         , 'CLOB'     ,    40
         , 'NCLOB'    ,    40
         , 'DATE'     ,    93
         , NULL
         ) $typecaseend      DATA_TYPE          -- ...
       , tc.DATA_TYPE        TYPE_NAME          -- std.?
       , decode( tc.DATA_TYPE
         , 'LONG RAW' , 2147483647
         , 'LONG'     , 2147483647
         , 'CLOB'     , 2147483647
         , 'NCLOB'    , 2147483647
         , 'BLOB'     , 2147483647
         , 'BFILE'    , 2147483647
         , 'NUMBER'   , decode( tc.DATA_SCALE
                        , NULL, 126
                        , nvl( tc.DATA_PRECISION, 38 )
                        )
         , 'FLOAT'    , tc.DATA_PRECISION
         , 'DATE'     , 19
         , 'VARCHAR2' , tc.$char_length
         , 'CHAR'     , tc.$char_length
         , 'NVARCHAR2', tc.$char_length
         , 'NCHAR'    , tc.$char_length
         , tc.DATA_LENGTH
         )                   COLUMN_SIZE
       , decode( tc.DATA_TYPE
         , 'LONG RAW' , 2147483647
         , 'LONG'     , 2147483647
         , 'CLOB'     , 2147483647
         , 'NCLOB'    , 2147483647
         , 'BLOB'     , 2147483647
         , 'BFILE'    , 2147483647
         , 'NUMBER'   , nvl( tc.DATA_PRECISION, 38 ) + 2
         , 'FLOAT'    ,  8 -- ?
         , 'DATE'     , 16
         , tc.DATA_LENGTH
         )                   BUFFER_LENGTH
       , decode( tc.DATA_TYPE
         , 'DATE'     ,  0
         , tc.DATA_SCALE
         )                   DECIMAL_DIGITS     -- ...
       , decode( tc.DATA_TYPE
         , 'FLOAT'    ,  2
         , 'NUMBER'   ,  decode( tc.DATA_SCALE, NULL, 2, 10 )
         , NULL
         )                   NUM_PREC_RADIX
       , decode( tc.NULLABLE
         , 'Y'        ,  1
         , 'N'        ,  0
         , NULL
         )                   NULLABLE
       , cc.COMMENTS         REMARKS
       , tc.DATA_DEFAULT     COLUMN_DEF         -- Column is LONG!
       , decode( tc.DATA_TYPE
         , 'MLSLABEL' , -9106
         , 'ROWID'    , -9104
         , 'UROWID'   , -9104
         , 'BFILE'    ,    -4 -- 31?
         , 'LONG RAW' ,    -4
         , 'RAW'      ,    -3
         , 'LONG'     ,    -1
         , 'UNDEFINED',     0
         , 'CHAR'     ,     1
         , 'NCHAR'    ,     1
         , 'NUMBER'   ,     decode( tc.DATA_SCALE, NULL, 8, 3 )
         , 'FLOAT'    ,     8
         , 'VARCHAR2' ,    12
         , 'NVARCHAR2',    12
         , 'BLOB'     ,    30
         , 'CLOB'     ,    40
         , 'NCLOB'    ,    40
         , 'DATE'     ,     9 -- not 93!
         , NULL
         )                   SQL_DATA_TYPE      -- ...
       , decode( tc.DATA_TYPE
         , 'DATE'     ,     3
         , NULL
         )                   SQL_DATETIME_SUB   -- ...
       , to_number( NULL )   CHAR_OCTET_LENGTH  -- TODO
       , tc.COLUMN_ID        ORDINAL_POSITION
       , decode( tc.NULLABLE
         , 'Y'        , 'YES'
         , 'N'        , 'NO'
         , NULL
         )                   IS_NULLABLE
    FROM ALL_TAB_COLUMNS  tc
       , ALL_COL_COMMENTS cc
   WHERE tc.OWNER         = cc.OWNER
     AND tc.TABLE_NAME    = cc.TABLE_NAME
     AND tc.COLUMN_NAME   = cc.COLUMN_NAME
)
 WHERE 1              = 1
SQL
        my @BindVals = ();
        while ( my ( $k, $v ) = each %$attr ) {
            if ( $v ) {
                $SQL .= "   AND $k LIKE ? ESCAPE '\\'\n";
                push @BindVals, $v;
            }
        }
        $SQL .= " ORDER BY TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION\n";


        # Since DATA_DEFAULT is a LONG, DEFAULT values longer than 80 chars will
        # throw an ORA-24345 by default; so we check if LongReadLen is set at
        # the default value, and if so, set it to something less likely to fail
        # in common usage.
        #
        # We do not set LongTruncOk however as that would make COLUMN_DEF
        # incorrect, in those (extreme!) cases it would be better if the user
        # sets LongReadLen herself.

        my $long_read_len = $dbh->FETCH('LongReadLen');

        my ($sth, $exc);

        {
            local $@;
            eval {
                $dbh->STORE(LongReadLen => 1024*1024) if $long_read_len == 80;
                $sth = $dbh->prepare( $SQL );
            };
            $exc = $@;
        }
        if ($exc) {
            $dbh->STORE(LongReadLen => 80) if $long_read_len == 80;
            die $exc;
        }

        $dbh->STORE(LongReadLen => 80) if $long_read_len == 80;

        return undef if not $sth;

        $sth->execute( @BindVals ) or return undef;
        $sth;
    }

    sub statistics_info {
        my($dbh, $catalog, $schema, $table, $unique_only, $quick) = @_;
        if (ref $catalog eq 'HASH') {
            ($schema, $table) = @$catalog{'TABLE_SCHEM','TABLE_NAME'};
            $catalog = undef;
        }
        my $choose = '/*+ CHOOSE */';
        my $ora_server_version = ora_server_version($dbh);
        if ($ora_server_version->[0] >= 11) {
            # rt91217 CHOOSE hint deprecated
            $choose = '';
        }
        my $SQL = <<"SQL";
SELECT *
  FROM
(
  SELECT $choose
         NULL              TABLE_CAT
       , t.OWNER           TABLE_SCHEM
       , t.TABLE_NAME      TABLE_NAME
       , to_number( NULL ) NON_UNIQUE
       , NULL              INDEX_QUALIFIER
       , NULL              INDEX_NAME
       ,'table'            TYPE
       , to_number( NULL ) ORDINAL_POSITION
       , NULL              COLUMN_NAME
       , NULL              ASC_OR_DESC
       , t.NUM_ROWS        CARDINALITY
       , t.BLOCKS          PAGES
       , NULL              FILTER_CONDITION
    FROM ALL_TABLES        t
   UNION
  SELECT NULL              TABLE_CAT
       , t.OWNER           TABLE_SCHEM
       , t.TABLE_NAME      TABLE_NAME
       , decode( t.UNIQUENESS,'UNIQUE', 0, 1 ) NON_UNIQUE
       , c.INDEX_OWNER     INDEX_QUALIFIER
       , c.INDEX_NAME      INDEX_NAME
       , decode( t.INDEX_TYPE,'NORMAL','btree','CLUSTER','clustered','other') TYPE
       , c.COLUMN_POSITION ORDINAL_POSITION
       , c.COLUMN_NAME     COLUMN_NAME
       , decode( c.DESCEND,'ASC','A','DESC','D') ASC_OR_DESC
       , t.DISTINCT_KEYS   CARDINALITY
       , t.LEAF_BLOCKS     PAGES
       , NULL              FILTER_CONDITION
    FROM ALL_INDEXES       t
       , ALL_IND_COLUMNS   c
   WHERE t.OWNER           = c.INDEX_OWNER
     AND t.INDEX_NAME      = c.INDEX_NAME
     AND t.TABLE_OWNER     = c.TABLE_OWNER
     AND t.TABLE_NAME      = c.TABLE_NAME
     AND t.UNIQUENESS   LIKE :3
)
 WHERE TABLE_SCHEM = :1
   AND TABLE_NAME  = :2
 ORDER BY NON_UNIQUE, TYPE, INDEX_QUALIFIER, INDEX_NAME, ORDINAL_POSITION
SQL
        my $sth = $dbh->prepare($SQL) or return undef;
        $sth->execute($schema, $table, $unique_only ?'UNIQUE':'%') or return undef;
        $sth;
    }

    sub type_info_all {
	my ($dbh) = @_;
        my $version = ( ora_server_version($dbh)->[0] < DBD::Oracle::ORA_OCI() )
                    ?   ora_server_version($dbh)->[0] : DBD::Oracle::ORA_OCI();
        my $vc2len = ( $version < 8 ) ? "2000" : "4000";

	my $type_info_all = [
	    {
		TYPE_NAME          =>  0,
		DATA_TYPE          =>  1,
		COLUMN_SIZE        =>  2,
		LITERAL_PREFIX     =>  3,
		LITERAL_SUFFIX     =>  4,
		CREATE_PARAMS      =>  5,
		NULLABLE           =>  6,
		CASE_SENSITIVE     =>  7,
		SEARCHABLE         =>  8,
		UNSIGNED_ATTRIBUTE =>  9,
		FIXED_PREC_SCALE   => 10,
		AUTO_UNIQUE_VALUE  => 11,
		LOCAL_TYPE_NAME    => 12,
		MINIMUM_SCALE      => 13,
		MAXIMUM_SCALE      => 14,
		SQL_DATA_TYPE      => 15,
		SQL_DATETIME_SUB   => 16,
		NUM_PREC_RADIX     => 17,
		INTERVAL_PRECISION => 18,
	    },
	    [ "LONG RAW",        SQL_LONGVARBINARY, 2147483647,"'",  "'",
		undef,            1,0,0,undef,0,undef,
		"LONG RAW",        undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "RAW",             SQL_VARBINARY,     2000,      "'",  "'",
		"max length",     1,0,3,undef,0,undef,
		"RAW",             undef,undef,SQL_VARBINARY,    undef,undef,undef, ],
	    [ "LONG",            SQL_LONGVARCHAR,   2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"LONG",            undef,undef,SQL_LONGVARCHAR,  undef,undef,undef, ],
	    [ "CHAR",            SQL_CHAR,          2000,      "'",  "'",
		"max length",     1,1,3,undef,0,0,
		"CHAR",            undef,undef,SQL_CHAR,         undef,undef,undef, ],
	    [ "DECIMAL",         SQL_DECIMAL,       38,        undef,undef,
		"precision,scale",1,0,3,0,    0,0,
		"DECIMAL",         0,    38,   SQL_DECIMAL,      undef,10,   undef, ],
	    [ "DOUBLE PRECISION",SQL_DOUBLE,        15,        undef,undef,
		undef, 1,0,3,0,    0,0,
		"DOUBLE PRECISION",undef,undef,SQL_DOUBLE,       undef,10,   undef, ],
	    [ "DATE",            SQL_TYPE_TIMESTAMP,19,        "'",  "'",
		undef,            1,0,3,undef,0,0,
		"DATE",            0,    0,    SQL_DATE,         3,    undef,undef, ],
	    [ "VARCHAR2",        SQL_VARCHAR,       $vc2len,   "'",  "'",
		"max length",     1,1,3,undef,0,0,
		"VARCHAR2",        undef,undef,SQL_VARCHAR,      undef,undef,undef, ],
	    [ "BLOB",            SQL_BLOB, 2147483647,"'",  "'",
		 undef,            1,1,0,undef,0,undef,
		"BLOB",            undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "BFILE",           -9114, 2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"BFILE",           undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "CLOB",            SQL_CLOB,   2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"CLOB",            undef,undef,SQL_LONGVARCHAR,  undef,undef,undef, ],
		["TIMESTAMP WITH TIME ZONE",	# type name
			SQL_TYPE_TIMESTAMP_WITH_TIMEZONE,	# data type
			40,		# column size
			"TIMESTAMP'",	# literal prefix
			"'",		# literal suffix
			"precision",	# create params
			1,		# nullable
			0,		# case sensitive
			3,		# searchable
			undef,		# unsigned attribute
			0,		# fixed prec scale
			0,		# auto unique value
			undef,		# local type name
			0,		# minimum scale
			6,		# maximum scale
			SQL_TIMESTAMP,	# sql data type
			5,		# sql datetime sub
			undef,		# num prec radix
			undef,		# interval precision
		],
		[ "INTERVAL DAY TO SECOND",	# type name
			SQL_INTERVAL_DAY_TO_SECOND,	# data type
			22,				# column size	'+00 11:12:10.222222200'
			"INTERVAL'",	# literal prefix
			"'",		# literal suffix
			"precision",	# create params
			1,		# nullable
			0,		# case sensitive
			3,		# searchable
			undef,		# unsigned attribute
			0,		# fixed prec scale
			0,		# auto unique value
			undef,		# local type name
			0,		# minimum scale
			9,		# maximum scale
			SQL_INTERVAL,	# sql data type
			10,		# sql datetime sub
			undef,		# num prec radix
			undef,		# interval precision
		],
		[ "INTERVAL YEAR TO MONTH",	# type name
			SQL_INTERVAL_YEAR_TO_MONTH,	# data type
			13,		# column size 	'+012345678-01'
			"INTERVAL'",	# literal prefix
			"'",		# literal suffix
			"precision",	# create params
			1,		# nullable
			0,		# case sensitive
			3,		# searchable
			undef,		# unsigned attribute
			0,		# fixed prec scale
			0,		# auto unique value
			undef,		# local type name
			0,		# minimum scale
			9,		# maximum scale
			SQL_INTERVAL,	# sql data type
			7,		# sql datetime sub
			undef,		# num prec radix
			undef,		# interval precision
		]
	  ];

	return $type_info_all;
    }

    sub plsql_errstr {
	# original version thanks to Bob Menteer
	my $sth = shift->prepare_cached(q{
	    SELECT name, type, line, position, text
	    FROM user_errors ORDER BY name, type, sequence
	}) or return undef;
	$sth->execute or return undef;
	my ( @msg, $oname, $otype, $name, $type, $line, $pos, $text );
	$oname = $otype = 0;
	while ( ( $name, $type, $line, $pos, $text ) = $sth->fetchrow_array ) {
	    if ( $oname ne $name || $otype ne $type ) {
		push @msg, "Errors for $type $name:";
		$oname = $name;
		$otype = $type;
	    }
	    push @msg, "$line.$pos: $text";
	}
	return join( "\n", @msg );
    }

    #
    # note, dbms_output must be enabled prior to usage
    #
    sub dbms_output_enable {
	my ($dbh, $buffersize) = @_;
	$buffersize ||= 20000;	# use oracle 7.x default
	$dbh->do("begin dbms_output.enable(:1); end;", undef, $buffersize);
    }

    sub dbms_output_get {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached("begin dbms_output.get_line(:l, :s); end;")
		or return;
	my ($line, $status, @lines);
	my $version = join ".", @{ ora_server_version($dbh) }[0..1];
	my $len =  32767;
	if ($version < 10.2){
	    $len = 400;
	}
	# line can be greater that 255 (e.g. 7 byte date is expanded on output)
	$sth->bind_param_inout(':l', \$line, $len, { ora_type => 1 });
	$sth->bind_param_inout(':s', \$status, 20, { ora_type => 1 });
	if (!wantarray) {
	    $sth->execute or return undef;
	    return $line if $status eq '0';
	    return undef;
	}
	push @lines, $line while($sth->execute && $status eq '0');
	return @lines;
    }

    sub dbms_output_put {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached("begin dbms_output.put_line(:1); end;")
		or return;
	my $line;
	foreach $line (@_) {
	    $sth->execute($line) or return;
	}
	return 1;
    }


    sub dbms_msgpipe_get {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached(q{
	    begin dbms_msgpipe.get_request(:returnpipe, :proc, :param); end;
	}) or return;
	my $msg = ['','',''];
	$sth->bind_param_inout(":returnpipe", \$msg->[0],   30);
	$sth->bind_param_inout(":proc",       \$msg->[1],   30);
	$sth->bind_param_inout(":param",      \$msg->[2], 4000);
	$sth->execute or return undef;
	return $msg;
    }

    sub dbms_msgpipe_ack {
        my $dbh = shift;
        my $msg = shift;
        my $sth = $dbh->prepare_cached(q{
	    begin dbms_msgpipe.acknowledge(:returnpipe, :errormsg, :param); end;}) or return;
        $sth->bind_param_inout(":returnpipe", \$msg->[0],   30);
        $sth->bind_param_inout(":proc",       \$msg->[1],   30);
        $sth->bind_param_inout(":param",      \$msg->[2], 4000);
        $sth->execute or return undef;
        return 1;
    }

    sub ora_server_version {
        my $dbh = shift;
        return $dbh->{ora_server_version} if defined $dbh->{ora_server_version};
        my $banner = $dbh->selectrow_array(<<'SQL', undef, 'Oracle%', 'Personal Oracle%');
SELECT banner
  FROM v$version
  WHERE banner LIKE ? OR banner LIKE ?
SQL
        if (defined $banner) {
            my @version = $banner =~ /(?:^|\s)(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)(?:\s|$)/;
            $dbh->{ora_server_version} = \@version if @version;
        }
    }

    sub ora_nls_parameters {
	my $dbh = shift;
	my $refresh = shift;

	if ($refresh || !$dbh->{ora_nls_parameters}) {
            my $nls_parameters = $dbh->selectall_arrayref(q{
		SELECT parameter, value FROM v$nls_parameters
	    }) or return;
	    $dbh->{ora_nls_parameters} = { map { $_->[0] => $_->[1] } @$nls_parameters };
	}

	# return copy of params to protect against accidental editing
	my %nls = %{$dbh->{ora_nls_parameters}};
	return \%nls;
    }

    sub ora_can_unicode {
	my $dbh = shift;
	my $refresh = shift;
	# 0 = No Unicode support.
	# 1 = National character set is Unicode-based.
	# 2 = Database character set is Unicode-based.
	# 3 = Both character sets are Unicode-based.

	return $dbh->{ora_can_unicode}
	    if defined $dbh->{ora_can_unicode} && !$refresh;

	my $nls = $dbh->ora_nls_parameters($refresh);

	$dbh->{ora_can_unicode}  = 0;
	$dbh->{ora_can_unicode} += 1 if $nls->{NLS_NCHAR_CHARACTERSET} =~ /UTF/;
	$dbh->{ora_can_unicode} += 2 if $nls->{NLS_CHARACTERSET}       =~ /UTF/;

	return $dbh->{ora_can_unicode};
    }

}   # end of package DBD::Oracle::db


{   package                     # hide from PAUSE
    DBD::Oracle::st;            # ====== STATEMENT ======


   sub bind_param_inout_array {
	my $sth = shift;
	my ($p_id, $value_array,$maxlen, $attr) = @_;
	return $sth->set_err($DBI::stderr, "Value for parameter $p_id must be an arrayref, not a ".ref($value_array))
	   if defined $value_array and ref $value_array and ref $value_array ne 'ARRAY';

	return $sth->set_err($DBI::stderr, "Can't use named placeholder '$p_id' for non-driver supported bind_param_inout_array")
	   unless DBI::looks_like_number($p_id); # because we rely on execute(@ary) here

	return $sth->set_err($DBI::stderr, "Placeholder '$p_id' is out of range")
	   if $p_id <= 0; # can't easily/reliably test for too big

	# get/create arrayref to hold params
	my $hash_of_arrays = $sth->{ParamArrays} ||= { };

        $$hash_of_arrays{$p_id} = $value_array;
	return ora_bind_param_inout_array($sth, $p_id, $value_array,$maxlen, $attr);
	1;

    }


    sub execute_for_fetch {
       my ($sth, $fetch_tuple_sub, $tuple_status) = @_;
       my $row_count = 0;
       my $err_total = 0;
       my $tuple_count="0E0";
       my $tuple_batch_status;
       my $dbh = $sth->{Database};
       my $batch_size =($dbh->{'ora_array_chunk_size'}||= 1000);
       if(defined($tuple_status)) {
           @$tuple_status = ();
           $tuple_batch_status = [ ];
       }

       my $finished;
       while (1) {
           my @tuple_batch;
           for (my $i = 0; $i < $batch_size; $i++) {
               $finished = $fetch_tuple_sub->();
               push @tuple_batch, [@{$finished || last}];

           }
           last unless @tuple_batch;

           my $err_count = 0;
           my $res = ora_execute_array($sth,
                                           \@tuple_batch,
                                           scalar(@tuple_batch),
                                           $tuple_batch_status,
                                           $err_count );

           if(defined($res)) { #no error
                $row_count += $res;
           } else {
                $row_count = undef;
           }

           $err_total += $err_count;

           $tuple_count+=@tuple_batch;
           push @$tuple_status, @$tuple_batch_status
                if defined($tuple_status);

           last if !$finished;

       }
       #error check here
       return $sth->set_err($DBI::stderr, "executing $tuple_count generated $err_total errors")
       	   if $err_total;

       return wantarray
                ? ($tuple_count, defined $row_count ? $row_count : undef)
                : $tuple_count;

    }

    sub private_attribute_info {
        return { map { $_ => undef } qw/
            ora_lengths
            ora_types
            ora_rowid
            ora_est_row_width
            ora_type
            ora_fail_over
        / };
   }
}

1;

__END__

#line 5637
