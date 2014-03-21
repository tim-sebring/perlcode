#!/vol/perl/5.8/bin/perl -w
###################################################################################
#                          Healthcheck Reporting Page Script                      #
###################################################################################
#  This script serves as a reporting page for the healthcheck database, allowing  #
#  specific items to be searched on, returning matching criteria.                 #
###################################################################################
#                           C H A N G E   L O G                                   #
###################################################################################
#   2010/02/15 - myuserid - Changelog added                                        #
#                                                                                 #
###################################################################################

use CGI qw(:all);
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use Data::Dumper;
use Getopt::Long;
use lib '/vol/perl/5.8/DBD/oracle10.2.0.4/lib/site_perl/5.8.1/sun4-solaris';
use DBI;
use strict;

$ENV{'TWO_TASK'}="tblspace";
$ENV{'ORACLE_HOME'}="/vol/oracle10.2.0.4";
$ENV{'TNS_ADMIN'}="/vol/rdbms/oracle/net";

print header;
print start_html('Healthcheck report');
print("<link rel=\"SHORTCUT ICON\" href=\"../favicon.jpg\"/>");

print(qq(<div align="center"><h2>Healthcheck Reporting Page</h2></div>));
print(qq(<BR><BR>));
my $user="username";
my $pass="password";
my $tblspace="tblspace";
my @row;
my %attr;
my $debugflag = 0;

my %monthmap = (
"01" => "JAN",
"02" => "FEB",
"03" => "MAR",
"04" => "APR",
"05" => "MAY",
"06" => "JUN",
"07" => "JUL",
"08" => "AUG",
"09" => "SEP",
"10" => "OCT",
"11" => "NOV",
"12" => "DEC",
    );


# Build my display hash

my %webtext = (
    psrinfo => "CPU Offline or Faulted",
    metastat_i => "SVM Disk error/failure",
    metadbs=> "SVM: Less than 6 Metadbs",
    osver=> "OS Version",
    kernelver=> "Kernel Version",
    dumpadm=> "Dumpadm Device",
    mirror=> "Mirrors Unsynched",
    );


my $cgi = CGI->new;

#my $cgidumper = Dumper($cgi);
#print("Cgi = $cgidumper\n");
######################################################################################################
if($cgi->param()) {
#if(($cgi->param() && $cgi->param('form_submit') eq "Submit")) {

#my $dbh = DBI->connect("dbi:Oracle:tooldevl","$user","$pass")
#|| die($DBI::errstr . "<BR>");
#
# gets the most recent attributes for each server
#my $searchstring = $cgi->param('searchstring');
#my $sth = $dbh->prepare("select hostname,attrname,attrvalue,to_char((timeupdated),'YYYY/mm/dd hh24:mi:ss') \"when\" from tblserverattributes WHERE hostname LIKE '$searchstring' ORDER BY timeupdated");
#
# This shows everything updated within the last day, nothing else.
#my $sth = $dbh->prepare("select hostname,attrname,attrvalue,to_char((timeupdated),'YYYY/mm/dd hh24:mi:ss') \"when\" from tblserverattributes WHERE timeupdated > (sysdate - 1) and hostname LIKE '\%$form{'searchstring'}\%'");
#
#$sth->execute();
#while(@row = $sth->fetchrow_array) {

#my $temp = Dumper(@row);
#print("$temp<BR>");

#$attr{ $row[0]}{$row[1]} = $row[2];
#$attr{ $row[0]}{'timeupdated'} = $row[3];
#}
#my $host;
#my $subkey;
#my $timeslice;
#my $subsubkey;
#
#print(qq(<form name="select_host" method="post" action="gridreport.pl">));
#
#print(qq(Select a server: <select name="host" onchange="selection.value=this.options[this.selectedIndex].value;">));
#print(qq(<option CHECKED value="none">--- Select host---</option>));
#foreach $host (keys %attr) {
#print(qq(<option value="$host">$host</option>));
#foreach $subkey (keys %{$attr{$host}} ) {
#print("$subkey = $attr{$host}{$subkey}<BR>");
#}
#print("<BR><BR>");
#}
#print(qq(</select>));
#print(qq(<BR><BR><input type="text" name="selection" value="" size=30 maxlength=50>));
#
#print(qq(</form>));
#
#
#
#$dbh->disconnect();
#
#print(qq(<br><br><a href="/gridreport.html">Return to healthcheck home</a>));
#}
#######################################################################################################
#elsif ($cgi->param('event_submit') eq "Submit") {
#
#if($cgi->param('report_type') eq "none") {
#print(qq(<h2>Please click your 'back' button and select a valid report.</h2>));
#exit();
#}
#my $rep = $cgi->param('report_type');
#
#print(qq(<h2>Displaying $webtext{$rep} results</h2>));
#
#my $dbh = DBI->connect("dbi:Oracle:tooldevl","$user","$pass")
#|| die($DBI::errstr . "<BR>");
#
# gets the most recent attributes for each server
#my $searchstring = $cgi->param('searchstring');
#my $sth = $dbh->prepare("select hostname,attrname,attrvalue,to_char((timeupdated),'YYYY/mm/dd hh24:mi:ss') \"when\" from tblserverattributes WHERE hostname LIKE '$searchstring' ORDER BY timeupdated");
#
#$sth->execute();
#while(@row = $sth->fetchrow_array) {
#$attr{ $row[0]}{$row[1]} = $row[2];
#$attr{ $row[0]}{'timeupdated'} = $row[3];
#}
#
#my $host;
#my $subkey;
#my $timeslice;
#my $subsubkey;
#
#print(qq(<table border=0>));
#print(qq(<tr><td><strong>Server</strong></td><td><strong>OS Version</strong></td><td><strong>Last Checkin</strong></td></tr>));
#foreach $host (keys %attr) {
#print(qq(<tr><td>$host</td><td>$attr{$host}{osver}</td><td>$attr{$host}{timeupdated}</td></tr>));
#}
#print(qq(</table>));
#$dbh->disconnect();
#
#print(qq(<br><br><a href="/gridreport.html">Return to healthcheck home</a>));
#
#}
#######################################################################################################

    my $date1 = $cgi->param('date1');
    print("Showing healthcheck data for $date1<BR>");
    my ($tempmonth,$tempdate,$tempyear) = split("/",$date1);
    my $newmonth = $monthmap{$tempmonth};
    my $oradate = $tempdate . "-" . $newmonth . "-" . $tempyear;
    my $dbh = DBI->connect("dbi:Oracle:$tblspace","$user","$pass") || die($DBI::errstr . "<BR>");

# gets the most recent attributes for each server
    my $sth = $dbh->prepare("select hostname,attrname,attrvalue,to_char((timeupdated),'YYYY/mm/dd hh24:mi:ss') \"when\" from tblserverattributes WHERE trunc(timeupdated) = to_date('$oradate','dd-MON-yyyy') ORDER BY hostname,timeupdated");

    print(qq(<table border=0 width="90%">));
    print(qq(<tr><td><strong>Hostname</strong></td><td><strong>Attributes</strong></td><td><strong>Value</strong></td></tr>));
    $sth->execute();
    while(@row = $sth->fetchrow_array) {

        $attr{ $row[0]}{$row[1]} = $row[2];
        $attr{ $row[0]}{'timeupdated'} = $row[3];
	if(!$row[2]) { $row[2] = ''; }
	else {
	    print(qq(<tr><td>$row[0]</td><td>$row[1]</td><td>$row[2]</td></tr>));
	}


    }
    print(qq(</table>));

    $dbh->disconnect();
    print(qq(<br><br><a href="/gridreport.html">Return to healthcheck home</a>));
}
else {

    print(qq(<BR><BR>No form submitted. Please <a href="/gridreport.html">Return to healthcheck home</a>));
}
#######################################################################################################
print end_html; 


