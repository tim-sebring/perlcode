#!/vol/perl/5.8/bin/perl -w

    use CGI qw(:all);
    use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
    use lib '/vol/perl/5.8/DBD/oracle10.2.0.4/lib/site_perl/5.8.1/sun4-solaris';
    use DBI;
    use Data::Dumper;
    use strict;

    $ENV{'TWO_TASK'}="tooldevl";
    $ENV{'ORACLE_HOME'}="/vol/oracle10.2.0.4";
    $ENV{'TNS_ADMIN'}="/vol/rdbms/oracle/net";
    my $user="username";
    my $pass="password";
    my $tblspace="tblspace";
    my @row;
    my %commands;
    my $sth;
    my $dbh;

    my $cgi = CGI->new;

    print header;
    print start_html('Healthcheck 2.0 - Manage Commands');
    print(qq(<link rel="SHORTCUT ICON" href="../favicon.jpg" />));
    print(qq(<div align="center"><h2>Healthcheck 2.0 - Manage Commands</h2></div>));

########################################################################
    if($cgi->param('submit')) {
# user entered a new command, capture information and update the database
	my $commandname = $cgi->param('commandname');
	my $commandtype = $cgi->param('commandtype');
	my $command = $cgi->param('command');
	my $frequency = $cgi->param('frequency');

	print(qq(Debugging: commandname = $commandname<br>commandtype=$commandtype<BR>command = $command<BR>));

# don't read the active field, it doesn't exist and defaults to yes (1)

#prepare sql
	$dbh = DBI->connect("dbi:Oracle:tooldevl",$user,$pass) || die($DBI::errstr . "<BR>");

	$sth = $dbh->prepare("insert into tblcommands (commandname,commandtype,command,frequency) VALUES (?,?,?,?)");

	$sth->execute($commandname,$commandtype,$command,$frequency);

#need to reload the page so they can see their new command added to the database
	print(qq(Your record has been added. please <a href="manage_commands.pl">click here</a> to reload the page.<BR>));
	print(qq(Please note that clicking the reload button on the browser may cause duplicate commands.<BR><BR>));
	$dbh->disconnect();


    } # if submit
########################################################################
    else {   # not submitted
# show form and current event types

	$dbh = DBI->connect("dbi:Oracle:$tblspace","$user","$pass") || die($DBI::errstr . "<BR>");

	$sth = $dbh->prepare("select * from tblcommands");
	$sth->execute();
	while(@row = $sth->fetchrow_array) {
	    $commands{$row[0]}{'commandtype'} = $row[1];
	    $commands{$row[0]}{'command'} = $row[2];
	    $commands{$row[0]}{'active'} = $row[3];
	    $commands{$row[0]}{'frequency'} = $row[4];
	}

#my $tmp = Dumper(%eventtypes);
#print("$tmp<BR>");

	$dbh->disconnect();

#show form

	print(qq(<form name="add_eventtype" method="post" action="manage_commands.pl">));
	print(qq(<div align="center"><table border=0 width="75\%">));
print(qq(<tr><td><b>Command Name</b></td><td><b>Command Type</b></td><td><b>Command</b></td><td><b>Frequency<BR><font size=1>(minutes)</font></b></td><td><b>Active?</b></td></tr>))
    ;
# loop through existing, add blank at end for adding new eventtypes
	my $ischecked; 
	foreach my $key (sort( keys %commands)) {
	    if($commands{$key}{'active'}) {
                $ischecked = "CHECKED";
	    }
	    else {
                $ischecked = "";
	    }
	    print(qq(<tr><td>$key</td><td>$commands{$key}{'commandtype'}</td><td>$commands{$key}{'command'}</td><td>$commands{$key}{'frequency'}</td><td><input type="checkbox" name="${
key}_active" $ischecked></tr>));
}
print(qq(<tr><td><input type="text" name="commandname" size=15 maxlength=50></td><td><input type="text" name="commandtype" size=15 maxlength=50></td><td><input type="text" name="co
mmand" size=60 maxlength=200></td><td><input type="text" name="frequency" size=5 maxlength=30 />));
	print(qq(<td><input type="submit" name="submit" value="Update"></td></tr></table></div></form>));

	print(qq(<BR><BR><B>Note:</b><BR>));
	print(qq(Currently commands need to be deactivated manually within the database. <BR>));
	print(qq(To deactivate/delete a command, please see the healthcheck administrator.));
	print(qq(<BR>TODO:<BR>allow commands to be disabled via checking on buttons... DHTML, no submit<BR>));


    } # else not submitted
########################################################################


    print end_html;
