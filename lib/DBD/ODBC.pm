#line 1 "DBD/ODBC.pm"
#
# Copyright (c) 1994,1995,1996,1998  Tim Bunce
# portions Copyright (c) 1997-2004  Jeff Urlwin
# portions Copyright (c) 1997  Thomas K. Wenrich
# portions Copyright (c) 2007-2014 Martin J. Evans
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

## no critic (ProhibitManyArgs ProhibitMultiplePackages)

require 5.008;

# NOTE: Don't forget to update the version reference in the POD below too.
# NOTE: If you create a developer release x.y_z ensure y is greater than
# the preceding y in the non developer release e.g., 1.24 should be followed
# by 1.25_1 and then released as 1.26.
# see discussion on dbi-users at
# http://www.nntp.perl.org/group/perl.dbi.dev/2010/07/msg6096.html and
# http://www.dagolden.com/index.php/369/version-numbers-should-be-boring/
$DBD::ODBC::VERSION = '1.48';

{
    ## no critic (ProhibitMagicNumbers ProhibitExplicitISA)
    ## no critic (ProhibitPackageVars)
    package DBD::ODBC;

    use DBI ();
    use DynaLoader ();
    use Exporter ();

    @ISA = qw(Exporter DynaLoader);

    # my $Revision = substr(q$Id$, 13,2);

    require_version DBI 1.609;

    bootstrap DBD::ODBC $VERSION;

    $err = 0;                   # holds error code   for DBI::err
    $errstr = q{};              # holds error string for DBI::errstr
    $sqlstate = "00000";        # starting state
    $drh = undef;               # holds driver handle once initialised

    use constant {
        # header fields in SQLGetDiagField:
        SQL_DIAG_CURSOR_ROW_COUNT => -1249,
        SQL_DIAG_DYNAMIC_FUNCTION => 7,
        SQL_DIAG_DYNAMIC_FUNCTION_CODE => 12,
        SQL_DIAG_NUMBER => 2,
        SQL_DIAG_RETURNCODE => 1,
        SQL_DIAG_ROW_COUNT => 3,
        # record fields in SQLGetDiagField:
        SQL_DIAG_CLASS_ORIGIN => 8,
        SQL_DIAG_COLUMN_NUMBER => -1247,
        SQL_DIAG_CONNECTION_NAME => 10,
        SQL_DIAG_MESSAGE_TEXT => 6,
        SQL_DIAG_NATIVE => 5,
        SQL_DIAG_ROW_NUMBER => -1248,
        SQL_DIAG_SERVER_NAME => 11,
        SQL_DIAG_SQLSTATE => 4,
        SQL_DIAG_SUBCLASS_ORIGIN => 9,
        # TAF constants - these are just copies of Oracle constants
        # events:
        OCI_FO_END     => 0x00000001,
        OCI_FO_ABORT   => 0x00000002,
        OCI_FO_REAUTH  => 0x00000004,
        OCI_FO_BEGIN   => 0x00000008,
        OCI_FO_ERROR   => 0x00000010,
        # callback return codes:
        OCI_FO_RETRY   => 25410,
        # types:
        OCI_FO_NONE    => 0x00000001,
        OCI_FO_SESSION => 0x00000002,
        OCI_FO_SELECT  => 0x00000004,
        OCI_FO_TXNAL   => 0x00000008
    };
    our @EXPORT_DIAGS = qw(SQL_DIAG_CURSOR_ROW_COUNT SQL_DIAG_DYNAMIC_FUNCTION SQL_DIAG_DYNAMIC_FUNCTION_CODE SQL_DIAG_NUMBER SQL_DIAG_RETURNCODE SQL_DIAG_ROW_COUNT SQL_DIAG_CLASS_ORIGIN SQL_DIAG_COLUMN_NUMBER SQL_DIAG_CONNECTION_NAME SQL_DIAG_MESSAGE_TEXT SQL_DIAG_NATIVE SQL_DIAG_ROW_NUMBER SQL_DIAG_SERVER_NAME SQL_DIAG_SQLSTATE SQL_DIAG_SUBCLASS_ORIGIN);
    our @EXPORT_TAF = qw(OCI_FO_END OCI_FO_ABORT OCI_FO_REAUTH OCI_FO_BEGIN OCI_FO_ERROR OCI_FO_RETRY OCI_FO_NONE OCI_FO_SESSION OCI_FO_SELECT OCI_FO_TXNAL);
    our @EXPORT_OK = (@EXPORT_DIAGS, @EXPORT_TAF);
    our %EXPORT_TAGS = (
        diags => \@EXPORT_DIAGS,
        taf => \@EXPORT_TAF);

    sub parse_trace_flag {
        my ($class, $name) = @_;
        return 0x02_00_00_00 if $name eq 'odbcunicode';
        return 0x04_00_00_00 if $name eq 'odbcconnection';
        return DBI::parse_trace_flag($class, $name);
    }

    sub parse_trace_flags {
        my ($class, $flags) = @_;
        return DBI::parse_trace_flags($class, $flags);
    }

    my $methods_are_installed = 0;
    sub driver{
        return $drh if $drh;
        my($class, $attr) = @_;

        $class .= "::dr";

        # not a 'my' since we use it above to prevent multiple drivers

        $drh = DBI::_new_drh($class, {
            'Name' => 'ODBC',
            'Version' => $VERSION,
            'Err'    => \$DBD::ODBC::err,
            'Errstr' => \$DBD::ODBC::errstr,
            'State' => \$DBD::ODBC::sqlstate,
            'Attribution' => 'DBD::ODBC by Jeff Urlwin, Tim Bunce and Martin J. Evans',
	    });
        if (!$methods_are_installed) {
            DBD::ODBC::st->install_method("odbc_lob_read");
            DBD::ODBC::st->install_method("odbc_rows", { O=>0x00000000 });
            # don't clear errors - IMA_KEEP_ERR = 0x00000004
            DBD::ODBC::st->install_method("odbc_getdiagrec", { O=>0x00000004 });
            DBD::ODBC::db->install_method("odbc_getdiagrec", { O=>0x00000004 });
            DBD::ODBC::db->install_method("odbc_getdiagfield", { O=>0x00000004 });
            DBD::ODBC::st->install_method("odbc_getdiagfield", { O=>0x00000004 });
            $methods_are_installed++;
        }
        return $drh;
    }

    sub CLONE { undef $drh }
    1;
}


{   package DBD::ODBC::dr; # ====== DRIVER ======
    use strict;
    use warnings;

    ## no critic (ProhibitBuiltinHomonyms)
    sub connect {
        my($drh, $dbname, $user, $auth, $attr)= @_;
        #$user = q{} unless defined $user;
        #$auth = q{} unless defined $auth;

        # create a 'blank' dbh
        my $this = DBI::_new_dbh($drh, {
            'Name' => $dbname,
            'USER' => $user,
            'CURRENT_USER' => $user,
	    });

        # Call ODBC _login func in Driver.xst file => dbd_db_login6
        # and populate internal handle data.
        # There are 3 versions (currently) if you have a recent DBI:
        # dbd_db_login (oldest)
        # dbd_db_login6 (with attribs hash & char * args) and
        # dbd_db_login6_sv (as dbd_db_login6 with perl scalar args

        DBD::ODBC::db::_login($this, $dbname, $user, $auth, $attr) or return;

        return $this;
    }
    ## use critic

}


{   package DBD::ODBC::db; # ====== DATABASE ======
    use strict;
    use warnings;

    use constant SQL_DRIVER_HSTMT => 5;
    use constant SQL_DRIVER_HLIB => 76;
    use constant SQL_DRIVER_HDESC => 135;


    sub parse_trace_flag {
        my ($h, $name) = @_;
        return DBD::ODBC->parse_trace_flag($name);
    }

    sub private_attribute_info {
        return {
            odbc_ignore_named_placeholders => undef, # sth and dbh
            odbc_default_bind_type         => undef, # sth and dbh
            odbc_force_bind_type           => undef, # sth and dbh
            odbc_force_rebind              => undef, # sth and dbh
            odbc_async_exec                => undef, # sth and dbh
            odbc_exec_direct               => undef,
            odbc_old_unicode               => undef,
            odbc_describe_parameters       => undef,
            odbc_SQL_ROWSET_SIZE           => undef,
            odbc_SQL_DRIVER_ODBC_VER       => undef,
            odbc_cursortype                => undef,
            odbc_query_timeout             => undef, # sth and dbh
            odbc_has_unicode               => undef,
            odbc_out_connect_string        => undef,
            odbc_version                   => undef,
            odbc_err_handler               => undef,
            odbc_putdata_start             => undef, # sth and dbh
            odbc_column_display_size       => undef, # sth and dbh
            odbc_utf8_on                   => undef, # sth and dbh
            odbc_driver_complete           => undef,
            odbc_batch_size                => undef,
            odbc_array_operations          => undef, # sth and dbh
            odbc_taf_callback              => undef,
            odbc_trace                          => undef, # dbh
            odbc_trace_file                          => undef, # dbh
        };
    }

    sub prepare {
        my($dbh, $statement, @attribs)= @_;

        # create a 'blank' sth
        my $sth = DBI::_new_sth($dbh, {
            'Statement' => $statement,
	    });

        # Call ODBC func in ODBC.xs file.
        # (This will actually also call SQLPrepare for you.)
        # and populate internal handle data.

        DBD::ODBC::st::_prepare($sth, $statement, @attribs)
              or return;

        return $sth;
    }

    sub column_info {
        my ($dbh, $catalog, $schema, $table, $column) = @_;

        $catalog = q{} if (!$catalog);
        $schema = q{} if (!$schema);
        $table = q{} if (!$table);
        $column = q{} if (!$column);
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLColumns" });

        _columns($dbh,$sth, $catalog, $schema, $table, $column)
            or return;

        return $sth;
    }

    sub columns {
        my ($dbh, $catalog, $schema, $table, $column) = @_;

        $catalog = q{} if (!$catalog);
        $schema = q{} if (!$schema);
        $table = q{} if (!$table);
        $column = q{} if (!$column);
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLColumns" });

        _columns($dbh,$sth, $catalog, $schema, $table, $column)
            or return;

        return $sth;
    }


    sub table_info {
        my ($dbh, $catalog, $schema, $table, $type) = @_;

        if ($#_ == 1) {
            my $attrs = $_[1];
            $catalog = $attrs->{TABLE_CAT};
            $schema = $attrs->{TABLE_SCHEM};
            $table = $attrs->{TABLE_NAME};
            $type = $attrs->{TABLE_TYPE};
        }
        # the following was causing a problem
        # changing undef to '' makes a big difference to SQLTables
        # as SQLTables has special cases for empty string calls
        #$catalog = q{} if (!$catalog);
        #$schema = q{} if (!$schema);
        #$table = q{} if (!$table);
        #$type = q{} if (!$type);

        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLTables" });

        DBD::ODBC::st::_tables($dbh,$sth, $catalog, $schema, $table, $type)
              or return;
        return $sth;
    }

    sub primary_key_info {
       my ($dbh, $catalog, $schema, $table ) = @_;

       # create a "blank" statement handle
       my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLPrimaryKeys" });

       $catalog = q{} if (!$catalog);
       $schema = q{} if (!$schema);
       $table = q{} if (!$table);
       DBD::ODBC::st::_primary_keys($dbh,$sth, $catalog, $schema, $table )
	     or return;
       return $sth;
    }

    sub statistics_info {
       my ($dbh, $catalog, $schema, $table, $unique, $quick ) = @_;

       # create a "blank" statement handle
       my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLStatistics" });

       $catalog = q{} if (!$catalog);
       $schema = q{} if (!$schema);
       $table = q{} if (!$table);
       $unique = 1 if (!$unique);
       $quick = 1 if (!$quick);

       DBD::ODBC::st::_statistics($dbh, $sth, $catalog, $schema, $table,
                                 $unique, $quick)
	     or return;
       return $sth;
    }

    sub foreign_key_info {
       my ($dbh, $pkcatalog, $pkschema, $pktable, $fkcatalog, $fkschema, $fktable ) = @_;

       # create a "blank" statement handle
       my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLForeignKeys" });

       $pkcatalog = q{} if (!$pkcatalog);
       $pkschema = q{} if (!$pkschema);
       $pktable = q{} if (!$pktable);
       $fkcatalog = q{} if (!$fkcatalog);
       $fkschema = q{} if (!$fkschema);
       $fktable = q{} if (!$fktable);
       _GetForeignKeys($dbh, $sth, $pkcatalog, $pkschema, $pktable, $fkcatalog, $fkschema, $fktable) or return;
       return $sth;
    }

    sub ping {
        my $dbh = shift;

        # DBD::Gofer does the following (with a 0 instead of "0") but it I
        # cannot make it set a warning.
        #return $dbh->SUPER::set_err("0", "can't ping while not connected") # warning
        #    unless $dbh->SUPER::FETCH('Active');

        #my $pe = $dbh->FETCH('PrintError');
        #$dbh->STORE('PrintError', 0);
        my $evalret = eval {
           # create a "blank" statement handle
            my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLTables_PING" })
                or return 1;

            my ($catalog, $schema, $table, $type);

            $catalog = q{};
            $schema = q{};
            $table = 'NOXXTABLE';
            $type = q{};

            DBD::ODBC::st::_tables($dbh,$sth, $catalog, $schema, $table, $type)
                  or return 1;
            $sth->finish;
            return 0;
        };
        #$dbh->STORE('PrintError', $pe);
        $dbh->set_err(undef,'',''); # clear any stored error from eval above
        if ($evalret == 0) {
            return 1;
        } else {
            return 0;
        }
    }

#####    # saved, just for posterity.
#####    sub oldping  {
#####	my $dbh = shift;
#####	my $state = undef;
#####
#####	# should never 'work' but if it does, that's okay!
#####	# JLU incorporated patches from Jon Smirl 5/4/99
#####	{
#####	    local $dbh->{RaiseError} = 0 if $dbh->{RaiseError};
#####	    # JLU added local PrintError handling for completeness.
#####	    # it shouldn't print, I think.
#####	    local $dbh->{PrintError} = 0 if $dbh->{PrintError};
#####	    my $sql = "select sysdate from dual1__NOT_FOUND__CANNOT";
#####	    my $sth = $dbh->prepare($sql);
#####	    # fixed "my" $state = below.  Was causing problem with
#####	    # ping!  Also, fetching fields as some drivers (Oracle 8)
#####	    # may not actually check the database for activity until
#####	    # the query is "described".
#####	    # Right now, Oracle8 is the only known version which
#####	    # does not actually check the server during prepare.
#####	    my $ok = $sth && $sth->execute();
#####
#####	    $state = $dbh->state;
#####	    $DBD::ODBC::err = 0;
#####	    $DBD::ODBC::errstr = "";
#####	    $DBD::ODBC::sqlstate = "00000";
#####	    return 1 if $ok;
#####	}
#####        return 1 if $state eq 'S0002';  # Base table not found
##### 	return 1 if $state eq '42S02';  # Base table not found.Solid EE v3.51
#####        return 1 if $state eq 'S0022';  # Column not found
#####	return 1 if $state eq '37000';  # statement could not be prepared (19991011, JLU)
#####	# return 1 if $state eq 'S1000';  # General Error? ? 5/30/02, JLU.  This is what Openlink is returning
#####	# We assume that any other error means the database
#####	# is no longer connected.
#####	# Some special cases may need to be added to the code above.
#####	return 0;
#####    }

    # New support for DBI which has the get_info command.
    # leaving support for ->func(xxx, GetInfo) (below) for a period of time
    # to support older applications which used this.
    sub get_info {
        my ($dbh, $item) = @_;
        # Ignore some we cannot do
        if ($item == SQL_DRIVER_HSTMT ||
                $item == SQL_DRIVER_HLIB ||
                    $item == SQL_DRIVER_HDESC) {
            return;
        }
        return _GetInfo($dbh, $item);
    }

    # new override of do method provided by Merijn Broeren
    # this optimizes "do" to use SQLExecDirect for simple
    # do statements without parameters.
    ## no critic (ProhibitBuiltinHomonyms)
    sub do {
        my($dbh, $statement, $attr, @params) = @_;
        my $rows = 0;
        ## no critic (ProhibitMagicNumbers)
        if( -1 == $#params ) {
            $dbh->STORE(Statement => $statement);
            # No parameters, use execute immediate
            $rows = ExecDirect( $dbh, $statement );
            if( 0 == $rows ) {
                $rows = "0E0";    # 0 but true
            } elsif( $rows < -1 ) {
                undef $rows;
            }
        }
        else
        {
          $rows = $dbh->SUPER::do( $statement, $attr, @params );
        }
        return $rows
    }

    ## use critic
    #
    # can also be called as $dbh->func($sql, ExecDirect);
    # if, for some reason, there are compatibility issues
    # later with DBI's do.
    #
    sub ExecDirect {
       my ($dbh, $sql) = @_;
       return _ExecDirect($dbh, $sql);
    }

    # Call the ODBC function SQLGetInfo
    # Args are:
    #	$dbh - the database handle
    #	$item: the requested item.  For example, pass 6 for SQL_DRIVER_NAME
    # See the ODBC documentation for more information about this call.
    #
    sub GetInfo {
        my ($dbh, $item) = @_;
        return get_info($dbh, $item);
    }

    # Call the ODBC function SQLStatistics
    # Args are:
    # See the ODBC documentation for more information about this call.
    #
    sub GetStatistics {
        my ($dbh, $catalog, $schema, $table, $unique) = @_;
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLStatistics" });
        _GetStatistics($dbh, $sth, $catalog, $schema,
		       $table, $unique) or return;
        return $sth;
    }

    # Call the ODBC function SQLForeignKeys
    # Args are:
    # See the ODBC documentation for more information about this call.
    #
    sub GetForeignKeys {
        my ($dbh, $pk_catalog, $pk_schema, $pk_table,
            $fk_catalog, $fk_schema, $fk_table) = @_;
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLForeignKeys" });
        _GetForeignKeys($dbh, $sth, $pk_catalog, $pk_schema, $pk_table,
			$fk_catalog, $fk_schema, $fk_table) or return;
        return $sth;
    }

    # Call the ODBC function SQLPrimaryKeys
    # Args are:
    # See the ODBC documentation for more information about this call.
    #
    sub GetPrimaryKeys {
        my ($dbh, $catalog, $schema, $table) = @_;
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLPrimaryKeys" });
        _GetPrimaryKeys($dbh, $sth, $catalog, $schema, $table) or return;
        return $sth;
    }

    # Call the ODBC function SQLSpecialColumns
    # Args are:
    # See the ODBC documentation for more information about this call.
    #
    sub GetSpecialColumns {
        my ($dbh, $identifier, $catalog, $schema, $table, $scope, $nullable) = @_;
        # create a "blank" statement handle
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLSpecialColumns" });
        _GetSpecialColumns($dbh, $sth, $identifier, $catalog, $schema,
                           $table, $scope, $nullable) or return;
        return $sth;
    }

#    sub GetTypeInfo {
#	my ($dbh, $sqltype) = @_;
#	# create a "blank" statement handle
#	my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLGetTypeInfo" });
#	# print "SQL Type is $sqltype\n";
#	_GetTypeInfo($dbh, $sth, $sqltype) or return;
#	return $sth;
#    }

    sub type_info_all {
        my ($dbh, $sqltype) = @_;
        $sqltype = DBI::SQL_ALL_TYPES unless defined $sqltype;
        my $sth = DBI::_new_sth($dbh, { 'Statement' => "SQLGetTypeInfo" });
        _GetTypeInfo($dbh, $sth, $sqltype) or return;
        my $info = $sth->fetchall_arrayref;
        unshift @{$info}, {
            map { ($sth->{NAME}->[$_] => $_) } 0..$sth->{NUM_OF_FIELDS}-1
           };
        return $info;
    }
}


{   package DBD::ODBC::st; # ====== STATEMENT ======
    use strict;
    use warnings;

    *parse_trace_flag = \&DBD::ODBC::db::parse_trace_flag;

    sub private_attribute_info {
        return {
            odbc_ignore_named_placeholders => undef, # sth and dbh
            odbc_default_bind_type         => undef, # sth and dbh
            odbc_force_bind_type           => undef, # sth and dbh
            odbc_force_rebind              => undef, # sth and dbh
            odbc_async_exec                => undef, # sth and dbh
            odbc_query_timeout             => undef, # sth and dbh
            odbc_putdata_start             => undef, # sth and dbh
            odbc_column_display_size       => undef, # sth and dbh
            odbc_utf8_on                   => undef, # sth and dbh
            odbc_exec_direct               => undef, # sth and dbh
            odbc_old_unicode               => undef, # sth and dbh
            odbc_describe_parameters       => undef, # sth and dbh
            odbc_batch_size                => undef, # sth and dbh
            odbc_array_operations          => undef, # sth and dbh
        };
    }

    sub ColAttributes { # maps to SQLColAttributes
        my ($sth, $colno, $desctype) = @_;
        my $tmp = _ColAttributes($sth, $colno, $desctype);
        return $tmp;
    }

    sub cancel {
        my $sth = shift;
        my $tmp = _Cancel($sth);
        return $tmp;
    }

    sub execute_for_fetch {
        my ($sth, $fetch_tuple_sub, $tuple_status) = @_;
        #print "execute_for_fetch\n";
        my $row_count = 0;
        my $tuple_count="0E0";
        my $tuple_batch_status;
        my $batch_size = $sth->FETCH('odbc_batch_size');

        $sth->trace_msg("execute_for_fetch($fetch_tuple_sub, " .
                            ($tuple_status ? $tuple_status : 'undef') .
                                ") batch_size = $batch_size\n", 4);
        # Use DBI's execute_for_fetch if ours is disabled
        my $override = (defined($ENV{ODBC_DISABLE_ARRAY_OPERATIONS}) ?
                            $ENV{ODBC_DISABLE_ARRAY_OPERATIONS} : -1);
        if ((($sth->FETCH('odbc_array_operations') == 0) && ($override != 0)) ||
                $override == 1) {
            $sth->trace_msg("array operations disabled\n", 4);
            my $sth = shift;
            return $sth->SUPER::execute_for_fetch(@_);
        }

        $tuple_batch_status = [ ]; # we always want this here
        if (defined($tuple_status)) {
            @$tuple_status = ();
        }
        my $finished;
        while (1) {
            my @tuple_batch;
            for (my $i = 0; $i < $batch_size; $i++) {
                $finished = $fetch_tuple_sub->();
                push @tuple_batch, [ @{$finished || last} ];
            }
            $sth->trace_msg("Found " . scalar(@tuple_batch) . " rows\n", 4);
            last unless @tuple_batch;
            my $res = odbc_execute_for_fetch($sth,
					     \@tuple_batch,
					     scalar(@tuple_batch),
					     $tuple_batch_status);
            $sth->trace_msg("odbc_execute_array returns " .
                                ($res ? $res : 'undef') . "\n", 4);

            #print "odbc_execute_array XS returned $res\n";
            # count how many tuples were used
            # basically they are all used unless marked UNUSED
            if ($tuple_batch_status) {
                foreach (@$tuple_batch_status) {
                    $tuple_count++ unless $_ == 7; # SQL_PARAM_UNUSED
                    next if ref($_);
                    $_ = -1;	# we don't know individual row counts
                }
                if ($tuple_status) {
                    push @$tuple_status, @$tuple_batch_status
                        if defined($tuple_status);
                }
            }
            if (!defined($res)) {	# error
                $row_count = undef;
                last;
            } else {
                $row_count += $res;
            }
            last if !$finished;
        }
        if (!wantarray) {
            return undef if !defined $row_count;
            return $tuple_count;
        }
        return (defined $row_count ? $tuple_count : undef, $row_count);
    }
}

1;

__END__

#line 2729
