#line 1 "DBD/ADO/Const.pm"
package DBD::ADO::Const;

use strict;
use warnings;

use Win32::OLE();
use Win32::OLE::TypeInfo();
use Win32::OLE::Variant();

$DBD::ADO::Const::VERSION = '0.07';

$DBD::ADO::Const::VT_I4_BYREF = Win32::OLE::Variant::VT_I4()
                              | Win32::OLE::Variant::VT_BYREF()
                              ;

my $ProgId  = 'ADODB.Connection';
my $VarSkip = Win32::OLE::TypeInfo::VARFLAG_FHIDDEN()
            | Win32::OLE::TypeInfo::VARFLAG_FRESTRICTED()
            | Win32::OLE::TypeInfo::VARFLAG_FNONBROWSABLE()
            ;
my $Enums;

# -----------------------------------------------------------------------------
sub Enums
# -----------------------------------------------------------------------------
{
  my $class = shift;

  return $Enums if $Enums;

  my $TypeLib = Win32::OLE->new( $ProgId )->GetTypeInfo->GetContainingTypeLib;

  return $Enums = $TypeLib->Enums if defined &Win32::OLE::TypeLib::Enums;

  for my $i ( 0 .. $TypeLib->_GetTypeInfoCount - 1 )
  {
    my $TypeInfo = $TypeLib->_GetTypeInfo( $i );
    my $TypeAttr = $TypeInfo->_GetTypeAttr;
    next unless $TypeAttr->{typekind} == Win32::OLE::TypeInfo::TKIND_ENUM();
    my $Enum = $Enums->{$TypeInfo->_GetDocumentation->{Name}} = {};
    for my $i ( 0 .. $TypeAttr->{cVars} - 1 )
    {
      my $VarDesc = $TypeInfo->_GetVarDesc( $i );
      next if $VarDesc->{wVarFlags} & $VarSkip;
      my $Documentation = $TypeInfo->_GetDocumentation( $VarDesc->{memid} );
      $Enum->{$Documentation->{Name}} = $VarDesc->{varValue};
    }
  }
  return $Enums;
}
# -----------------------------------------------------------------------------
1;

#line 142
