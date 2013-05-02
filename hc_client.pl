#!/vol/perl/5.8/bin/perl

###############################################################################
#                        hc_client.pl                                         #
###############################################################################
#  This script is part of the HealthCheck 2.0 family of scripts.              #
#  Other scripts include those running on sedjct825 and belle-ld02            #
#                                                                             #
#  The purpose of this script is to collect information from solaris servers  #
#  allowing us to enhance our monitoring capability, especially where tools   #
#  like sitescope are not appropriate or available.                           #
#  This particular script was designed originally to be executed from a       #
#  NAS automount (/devl/hc or /vol/hc) and a separate client would be used    #
#  for DMZ servers like WHI, although they have a NAS available too...        #
###############################################################################
#                   Changelog  - please document changes here                 #
#        (and remember to make a backup copy first!)                          #
# 2010-10-27 - sebrint - script created                                       #
# 2012-01-30 - sebrint - adding cron scheduling system                        #
###############################################################################

use lib '/vol/perl/5.8/DBD/oracle10.2.0.4/lib/site_perl/5.8.1/sun4-solaris';
use DBI;
use Data::Dumper;
use strict;

$ENV{'TWO_TASK'}="tooldevl";
$ENV{'ORACLE_HOME'}="/vol/oracle10.2.0.4";
$ENV{'TNS_ADMIN'}="/vol/rdbms/oracle/net";
my $user="healthck";
my $pass="sebring12";
my $tblspace="tooldevl";
my @row;
my $sth;
my $dbh;
my %commands;


# Get time information,, so when this runs we know which commands to execute
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $wholeyear = $yearOffset + 1900;   # yearOffset will read 112 for 2012, 1900+112 = 2012

my $debug = 0;
if($debug) {
	print("Dumping date/time vars to screen:\n");
	print("     Second      = $second\n");
	print("     Minute      = $minute\n");
	print("     Hour        = $hour\n");
	print("     DayOfMonth  = $dayOfMonth\n");
	print("     Month       = $month\n");
	print("     Year        = $wholeyear\n");
	print("     DayOfWeek   = $dayOfWeek\n");
	print("     DayOfYear   = $dayOfYear\n");
	print("     DST         = $daylightSavings\n");
	print("\n\n");
}







# Retrieve commands to run on this (and every) host, depending on what flags
# this server has. So far these are:
# solaris 	(all solaris servers, regardless of version)
# solaris10 	(only solaris 10 servers (and likely > 10 as well)
# vxvm 		(servers with veritas volume manager installed
# vcs 		(servers running vcs)

# Likely the following will be added in the future, depending on need
# vcs_srdf	(servers running vcs with global service groups/SRDF)
# vxcfs		(servers running VX Clustered File System)
# zfs		(servers running zfs (for zpool/zfs commands, etc)
 
sub is_solaris {
	# will determine if 'solaris' commands are to be run on this host
	my $os = `uname -s`;
	chomp($os);
	if($os eq "SunOS") { return 1;}
	else { return 0;}
}
sub is_solaris10 {
	# will determine if 'solaris10' commands are to be run on this host
	my $osver = `uname -r`;
	chomp($osver);
	if((&is_solaris) && ($osver eq "5.10")) { return 1;}
	else { return 0;}
}
sub is_vxvm {
	# will determine if 'vxvm' commands are to be run on this host
	my $res = `/usr/sbin/modinfo |grep vx`;
	if($res =~ m/VxVM/) { return 1;}
	else { return 0; }
}
sub is_vcs {
	# will determine if 'vcs' commands are to be run on this host
	my $res = `which /opt/VRTS/bin/hastatus`;
	if($res =~ m/not found/) { return 0;}
	else { return 1;}
}


# get hostname
my $hostname = `hostname`;
		
# connect to database
$dbh = DBI->connect("dbi:Oracle:$tblspace","$user","$pass") || die ($DBI::errstr . "\n");

# pull the appropriate commands from the database
$sth = $dbh->prepare("SELECT * FROM tblcommands WHERE commandtype = ?");
if(&is_solaris) { 
	$sth->execute('solaris'); 
	# capture results into an array
	my $debug;
	while(@row = $sth->fetchrow_array) {
        	$commands{$row[0]}{'commandtype'} = $row[1];
	        $commands{$row[0]}{'command'} =     $row[2];
		$commands{$row[0]}{'frequency'} =   $row[4];
        	$debug = `$row[2]`;
	}
}

if(&is_solaris10) { 
	$sth->execute('solaris10'); 
	while(@row = $sth->fetchrow_array) {
        	$commands{$row[0]}{'commandtype'} = $row[1];
	        $commands{$row[0]}{'command'} =     $row[2];
		$commands{$row[0]}{'frequency'} =   $row[4];
	}
}

if(&is_vxvm) {
        $sth->execute('vxvm'); 
        while(@row = $sth->fetchrow_array) {
                $commands{$row[0]}{'commandtype'} = $row[1];
                $commands{$row[0]}{'command'} =     $row[2];
		$commands{$row[0]}{'frequency'} =   $row[4];
        }
}

if(&is_vcs) {
        $sth->execute('vcs');        
        while(@row = $sth->fetchrow_array) {
                $commands{$row[0]}{'commandtype'} = $row[1];
                $commands{$row[0]}{'command'} =     $row[2];
		$commands{$row[0]}{'frequency'} =   $row[4];
        }
}



#my $tmp = Dumper(%commands);
#print("$tmp");

$sth = $dbh->prepare("INSERT INTO tblServerAttributes (hostname,attrname,attrvalue) VALUES (?,?,?)");

my $hostname = `hostname`;
my $commands;
# execute the commands
foreach my $command (keys %commands) {
	
	# Before executing, need to make sure that its time for that particular command.
	# Current frequency options:
	# 5 minutes
	# 20 minutes
	# 1 hour
	# 12 hours
	# 1 day
	# 1 week

	if($commands{$command}{'frequency'} == 5) {
		# 5 minute command, execute every time	
		$commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
		$sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
	}
	if($commands{$command}{'frequency'} == 20) {
                # 20 minute command

		if($minute == "00" || $minute == "20" || $minute == "40") {
                	$commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
                	$sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
		}
        }
        if($commands{$command}{'frequency'} == 60) {
                # 1 hour command

                if($minute == "00") {
                        $commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
                        $sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
                }
        }
        if($commands{$command}{'frequency'} == 720) {
                # 12 hour command

                if($minute == "00" && ($hour == "04" || $hour == "16")) {
                        $commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
                        $sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
                }
        }
        if($commands{$command}{'frequency'} == 1440) {
                # 24 hour command

                if($minute == "00" && $hour == "03") {
                        $commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
                        $sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
                }
        }
        if($commands{$command}{'frequency'} == 10080) {
                # 1 week command

                if($dayOfWeek == "0" && $hour == "04" && $minute == "30") {
                        $commands{$command}{'result'} = `$commands{$command}{'command'}`; # This line executes the commands
                        $sth->execute($hostname,$command,$commands{$command}{'result'});  # This line inserts results into DB
                }
        }



}


$dbh->disconnect();











