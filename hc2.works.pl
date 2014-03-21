#!/vol/perl/5.8/bin/perl

use Net::SSH::Expect;
use Parallel::ForkManager;
use Data::Dumper;
use POSIX qw/strftime/;
use strict;
#################################################################################
#                             hc2.works.pl                                      #
# This script connects to each server in the server list, and executes various  #
# checks against the connection, keeping track of servers that cannot be        #
# connected to, and the results of any offenders, then sends the final report   #
# to the email group listed in $EMAIL.                                          #
#################################################################################
# NOTE: This script is edited on another system then deployed to oz 
#    automatically. 
#################################################################################
#                            Changelog                                         
# 07-14-2009  myuserid - Created script/started changelog                        
# 07-21-2009  myuserid - Added dumpadm and mirrors sections
# 07-31-2009  myuserid - Added check for servers asking for password
# 08-04-2009  myuserid - Converted main loop to array
# 08-05-2009  myuserid - Added parallel processing, multiple connections at once
# 08-06-2009  myuserid - Converted to use OpenSSH for connecttimeout option (backed out -- not needed)
# 08-26-2009  myuserid - Updated timeouts, updated check for zfs/ufs (elsif)
# 08-28-2009  myuserid - Added DMP check, removed extraneous lines for mirror check
# 09-01-2009  myuserid - Added fmadm faulty check 
# 09-02-2009  myuserid - Added frozen resources check for VCS
# 09-03-2009  myuserid - Added check for VCS - autodisabled resources
# 09-30-2009  myuserid - Added psrinfo check
# 10-01-2009  myuserid - Added SVM Maintenance check
# 10-29-2009  myuserid - Added logging in /var/adm/hc.log
# 05-17-2010  myuserid - Added check for vxsvc process (could be temporary)
# 07-20-2010  myuserid - Added check for faulted VCS resources
# 01-24-2011  myuserid - Updated wiki URL, fixed 'err' grep causing montserrat* to show up always
# 04-12-2011  myuserid - Added fcinfo check for offline HBAs
# 04-20-2011  myuserid - finished check from last July to check for faulted VCS resources (was not completed)
# 01-13-2012  myuserid - Moved script to belle-ld02 from sedcjt825 (mercury environment being removed)
# 03-12-2012  myuserid - Removed vxsvc report from email, based on eleuthera04 issue
# 05-31-2012  myuserid - Added VCS "monitor procedure did not complete" check
# 06-22-2012  myuserid - Re-added the vxsvc report so that we can turn them off for older frames, etc
# 07-12-2012  myuserid - Changed HBA offline check to a powermt display check
# 11-27-2012  myuserid - Updated script to use healthck ID instead of myuserid (non exp password)
#                                                                               
#################################################################################

#################################################################################
#                         TODO List                                             #
# - Check for ZFS when looking for dump device -- ZFS filesystems use dedicated #
# - Add a 'retry' list, any failures (not password failures) will be retried    #
#   at the end of the script, allowing more of a timeout for connections        #
#################################################################################


##################### Variables/Constants #######################################
my $EMAIL = "root@localhost";	# Who gets notified

my $server_list="/vol/adm/sadocs/serverlist";	# List of servers to check


my $time_start;					# Used to capture processing time
my $time_end;					# Used to capture processing time
my $user="username";				# Used in ssh connection
my $progress;					# Used in displaying progress indicator bar
my $total_server_count = 0;			# How many servers are in $server_list
my $connected_server_count = 0;			# How many of those servers we can connect to
my $count = 0;					# Keeps track of how many servers have been processed
my $login_output;				# String returned from ssh conn, used to test success
my @serverlist;					# Array var for holding the server list
my $max_procs = 20;				# Number of concurrent ssh connections to allow at once

my $DUMPADM = "/tmp/dumpadm.hc";		# Stores dumpadm output for each server
my $MIRRORS = "/tmp/mirrors.hc";		# Stores mirror output for each server
my $NOCONNECT = "/tmp/noconnect.hc";		# List of servers we could not connect to
my $DMPFILE = "/tmp/dmp.hc";			# List of servers with vx DMP issues (DISABLED)
my $FMADMFILE = "/tmp/fmadm.hc";		# List of servers with faults in fmadm (sol 10 only)
my $FROZENFILE = "/tmp/frozen.hc";		# List of servers with VCS - froze service groups
my $AUTODISFILE = "/tmp/autodis.hc";		# List of servers with autodisabled service groups
my $HC = "/tmp/healthcheck.hc";			# File used to mail complete list to users
my $SVMMAINTFILE = "/tmp/svmmaint.hc";		# List of servers with plexes in maintenance/error state
my $PSRINFOFILE = "/tmp/psrinfo.hc";            # List of servers with CPUs that are not on-line
my $SYSLOG = "/var/adm/hc.log";			# System log of hc script
my $METADBFILE = "/tmp/metadb.hc";		# Count the number of metadbs, should be 6 total
my $VXSVCFILE = "/tmp/vxsvc.hc";		# List of servers with vxsvc running
my $VCSFAULTFILE = "/tmp/vcsfault.hc";		# List of servers with faulted resources in VCS
my $FCINFOFILE = "/tmp/fcinfo.hc";		# List of servers with a non-online fcinfo State
my $VCSTIMEOUTFILE = "/tmp/vcstimeout.hc";	# List of servers experiencing vcs monitor timeouts

################ Calculate today's date for log searching ###########################################
# Want the format YYYY/MM/DD (ie 2012/05/31)
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year = $year + 1900;  			# Number of years since 1900, so we need to add 1900
$mon = $mon + 1;			# Jan is 0, Dec is 11, so we need to add one to get month
if($mon < 10) { $mon = "0" . $mon; }	# Have to turn "5" into "05" to compare date strings
my $sysdate = "$year/$mon/$mday";

######################################### Command list ##############################################

my $dumpadm_cmd = "sudo /usr/sbin/dumpadm |grep \"Dump device\"";
my $mirror_cmd = "sudo /usr/sbin/metastat -p |grep m";
my $dmp_cmd = "sudo /usr/sbin/vxdmpadm listctlr all |egrep \"DISABLED|NOT\"";
my $fmadm_cmd = "sudo /usr/sbin/fmadm faulty |egrep -v \"^ \" |egrep -v \"Fault class|Affects|FRU|Serial|Description|Response|Impact|Action|Host|Platform\" |grep -v ^\$ |egrep -v \"^-\" |egrep -v \"^TIME\"";
my $frozen_cmd = "sudo /opt/VRTS/bin/hastatus -sum |egrep \"^G|^B\""; 
#my $autodis_cmd = "sudo /opt/VRTS/bin/hastatus -sum |egrep \"^B\" |awk '{print \$2 \" \" \$3 \" \" \$5}'";
my $autodis_cmd = "sudo /opt/VRTS/bin/hastatus -sum |egrep \"^B\"";
my $psrinfo_cmd = "/usr/sbin/psrinfo |grep -v on-line";
my $svmmaint_cmd = "sudo /usr/sbin/metastat -i |egrep -i \"erred|sync|repl|maint\"";
my $metadb_cmd = "sudo /usr/sbin/metadb |grep -v flags |wc -l";
#my $vxsvc_cmd = "ps -ef |grep vxsvc |grep -v grep";
my $vxsvc_cmd = "sudo /opt/VRTSob/bin/vxsvc -m";
my $vcsfault_cmd = "sudo /opt/VRTS/bin/hastatus -sum |grep \"^C\"";
#my $fcinfo_cmd = "sudo /usr/sbin/fcinfo hba-port |grep State";
my $fcinfo_cmd = "sudo /etc/powermt display | egrep \"failed\"";
my $vcstimeout_cmd = "sudo grep \"procedure did not complete within\" /var/VRTSvcs/log/engine_A.log";
#####################################################################################################

my $time1 = time();
# Get a total server count and put server list into an array
open(TOTAL, $server_list);
while(<TOTAL>)
{
        chomp();
        push(@serverlist,$_);
        $total_server_count++;
}
close(TOTAL);

# Since this is not running as root, /var/adm will be off limits unless we touch and chown the
# destination log file first. Touching an existing file will not alter it

my $tempresult = `/bin/sudo /bin/touch $SYSLOG`;
my $tempresult2 = `/bin/sudo /bin/chown $user $SYSLOG`;

# Write to log to show that hc script has begun execution
open(LOG,">>$SYSLOG");
print LOG strftime('%Y-%b-%d %H:%M',localtime); 
print LOG " - Healthcheck started";
print LOG "\n";
close(LOG);

# Print contents of array for testing
#print Dumper(@serverlist);

# Create the object that will allow parallel processing
my $pm = new Parallel::ForkManager($max_procs);

# Write headers to the various output files
open(DUMP,">>$DUMPADM");
print DUMP "\n\n===== Checking for dumpadm settings ============================\n";
print DUMP "= Command executed: $dumpadm_cmd\n";
print DUMP "= Offending criteria (string to match): 'dedicated'\n";
print DUMP "================================================================\n";
close(DUMP);

open(MIR,">>$MIRRORS");
print MIR "\n\n===== Checking for unsynched SVM mirrors ========================\n";
print MIR "= Command executed: $mirror_cmd\n";
print MIR "= Offending criteria: 'less than 2 plexes attached to a mirror'\n";
print MIR "=================================================================\n";
close(MIR);

open(NOC,">>$NOCONNECT");
print NOC "\n\n=================================================================\n";
print NOC "===== The following servers could not be connected to ===========\n";
print NOC "=================================================================\n";
close(NOC);

open(DMP,">>$DMPFILE");
print DMP "\n\n===== Checking for Vx DMP issues ==============================\n";
print DMP "= Command executed: $dmp_cmd\n";
print DMP "= Offending criteria: 'DIS' or 'NOT' -- finds DISABLED and NOT CONNECTED\n";
print DMP "========================================================================\n";
close(DMP);

open(FROZ,">>$FROZENFILE");
print FROZ "\n\n===== Checking for Frozen VCS Service groups  ========================\n";
print FROZ "= Command executed: $frozen_cmd\n";
print FROZ "= Offending criteria: Service group in 'FROZEN' category in hastatus\n";
print FROZ "========================================================================\n";
close(FROZ);


open(FM,">>$FMADMFILE");
print FM "\n\n===== Checking for fmadm faulty issues ==============================\n";
print FM "= Command executed: fmadm faulty\n";
print FM "= Offending criteria: None - display faults only\n";
print FM "========================================================================\n";
close(FM);

open(AD,">>$AUTODISFILE");
print AD "\n\n===== Checking for Autodisabled service groups =======================\n";
print AD "= Command executed: $autodis_cmd\n";
print AD "= Offending criteria: Autodisabled = Y\n";
print AD "========================================================================\n";
close(AD);

open(PSR,">>$PSRINFOFILE");
print PSR "\n\n===== Checking for offline or faulted CPUs =======================\n";
print PSR "= Command executed: $psrinfo_cmd\n";
print PSR "= Offending criteria: not 'on-line'\n";
print PSR "========================================================================\n";
close(PSR);

open(SVM,">>$SVMMAINTFILE");
print SVM "\n\n===== Checking for SVM Mirrors in error state =======================\n";
print SVM "= Command executed: $svmmaint_cmd\n";
print SVM "= Offending criteria: err|sync|repl|maint\n";
print SVM "========================================================================\n";
close(SVM);

open(MDB,">>$METADBFILE");
print MDB "\n\n===== Checking for SVM Metadbs =======================\n";
print MDB "= Command executed: $metadb_cmd\n";
print MDB "= Offending criteria: less than 6 per server\n";
print MDB "========================================================================\n";
close(MDB);

open(VXSVC,">>$VXSVCFILE");
print VXSVC "\n\n===== Checking for vxsvc process =======================\n";
print VXSVC "= Command executed: $vxsvc_cmd\n";
print VXSVC "= Offending criteria: process is running \n";
print VXSVC "========================================================================\n";
close(VXSVC);

open(VXFAULT,">>$VCSFAULTFILE");
print VXFAULT "\n\n===== Checking for Faulted VCS Resources  =================\n";
print VXFAULT "= Command executed: $vcsfault_cmd\n";
print VXFAULT "= Offending criteria: resource faulted \n";
print VXFAULT "====================================================================\n";
close(VXFAULT);

open(FCINFO,">>$FCINFOFILE");
print FCINFO "\n\n===== Checking for Failed Paths ======================\n";
print FCINFO "= Command executed: $fcinfo_cmd\n";
print FCINFO "= Offending criteria: failed\n";
print FCINFO "========================================================\n";
close(FCINFO);

open(VCSTO,">>$VCSTIMEOUTFILE");
print VCSTO "\n\n===== Checking for VCS Monitor Timeouts ======================\n";
print VCSTO "= Command executed: $vcstimeout_cmd\n";
print VCSTO "= Offending criteria: Contains 'procedure did not complete within'\n";
print VCSTO "========================================================\n";
close(VCSTO);



print("Executing health check scripts....\n");

$time_start = time();   # For calculating total time on script


$pm->run_on_finish(
	sub { 
		my ($pid, $exit_code, $ident) = @_;
		$connected_server_count += $exit_code;
	        $progress = ($count / $total_server_count) * 100;
       		printf "Progress: %4.1f\%\r",$progress;
        	$count++;

    	}
	
  );


# Open the server list for reading
open(SERVERS, $server_list) or die "Cannot open $server_list, $!";

# Used for progress indicator
select STDERR;
$| = 1;


# Main server list loop, all checks executed from inside this loop
#while(<SERVERS>) {
foreach my $host (0 .. $#serverlist) {
	my $pid = $pm->start($serverlist[$host]) and next;

#	print("\nStarting server $serverlist[$host].\n");

	# Create ssh object to one server
	my $ssh = Net::SSH::Expect->new (
		host => "$serverlist[$host]",
		user => "$user",
		raw_pty => 1,
		restart_timeout_upon_receive => 1,
		timeout => 6,
		ssh_option => " -x",
	);

#		log_file=> "/tmp/$serverlist[$host].log",
#		ssh_option => " -x -o ConnectTimeout=4",
#		binary => "/usr/local/bin/ssh",
#		exp_debug => 1,
#		no_terminal => 1,



	# Validate that we have a successful ssh connection
	$login_output = $ssh->run_ssh() or die "Could start ssh process, error $!\n";

	sleep(1);

	my $ret;
	my $rc1 = eval{$ret = $ssh->read_all(12);};
	unless($rc1) {
	        open(NOCON,">>$NOCONNECT");
                print NOCON "$serverlist[$host] - Could not connect -- skipping.\n";
                close(NOCON);
		$pm->finish(0);  # Couldn't connect to this one, skip to next server in main loop
		
	}

	my $rc = eval{( $ret =~ />\s*|$\s*\z/) or die "where's the remote prompt?";};
        if($rc) {
		if($ret =~ m/[Pp]assword:/) {
#                	print("Server asking for password, key not installed.\n");
                	open(NOCON,">>$NOCONNECT");
                	print NOCON "$serverlist[$host] - Asking for password -- skipping.\n";
                	close(NOCON);
			$pm->finish(0);    # Couldn't connect to this one, skip to next server in main loop
		}
        }


	$ssh->exec("stty raw -echo");
###############################################################################################

	# Execute dumpadm check
	my $dumpadm_output = $ssh->send("$dumpadm_cmd");
	my $line;
	while ( defined ($line = $ssh->read_line()) ) {
		if($line =~ m/dedicated/) {
			if($line =~ m/zvol/) {
				# do nothing, uses zfs
#				print("Dumpadm uses zvol -- rootfs is zfs.\n");
			}
			else {
				open(DUMP,">>$DUMPADM");
				print DUMP "$serverlist[$host] $line \n";
				close(DUMP);
			}
		}
	}

###############################################################################################

	# clear the buffer
	$ssh->eat($ssh->peek(1));

	my $fcinfo_output = $ssh->send("$fcinfo_cmd");
	my $line;
	my $found = 0;
        while ( defined ($line = $ssh->read_line()) ) {
		if($line =~ m/failed/) {
			$found = 1;
		}
	}
	
	if($found) {
		open(FC,">>$FCINFOFILE");
		print FC "$serverlist[$host] has one or more failed powerpath paths.\n";
		close(FC);
		$found=0;
	}

###############################################################################################

	# In order to correctly get information about metadevices, we need to determine
	# that a server is using a ufs root filesystem. For ZFS, metastat will return
	# a 'no databases' error. This command can determine filesystem type:

	# df -g /  2> /dev/null |grep fstype |awk '{print $1}'

	my $tmpcmd = "df -g /  2> /dev/null |grep fstype |awk '{print \$1}'";
	$ssh->eat($ssh->peek(0));
	my $tmpoutput = $ssh->send("$tmpcmd");
	my $line;
	while ( defined ($line = $ssh->read_line()) ) {
		if($line =~ m/zfs/) 
		{
			# no reason for this yet
#			open(MIR,">>$MIRRORS");
#			print MIR "$serverlist[$host] - has ZFS root, no metadevices exist\n";
#			close(MIR);
		}
		elsif($line =~ m/ufs/)  
		{   # ufs filesystem
			# Execute SVM Mirror check - looking for unsynched mirrors
			my $mirror_output = $ssh->send("$mirror_cmd");
        		my $line2;
			my $mirror_fail=0;
        		while ( defined ($line2 = $ssh->read_line()) ) {
        			my $tmpcount = ($line2 =~ tr/d//);
                		if($tmpcount < 3) {
					$mirror_fail = 1;
                		}		
			}
			if ($mirror_fail) {
				open(MIR,">>$MIRRORS");
				print MIR "$serverlist[$host] has unsynched mirrors.\n";
				close(MIR);
				$mirror_fail = 0;
			}
		
			# Might as well check for metaDBs here too, since we know its not zfs
			# Flush the input buffer
        		$ssh->read_all(2);
	
			$ssh->send("$metadb_cmd");
			my $line;
			while ( $line = $ssh->read_all() ) {
				if ($line < 6)  {
					open(MDB,">>$METADBFILE");
					print MDB "$serverlist[$host] has less than 6 metadbs\n";
					close(MDB);
				}
			} 

		} # end of ufs block
	}
###############################################################################################
	# Execute DMP check
	# First must see if the vxdmpadm binary exists in /usr/sbin -- otherwise no Veritas installed

	# Temporarily exclude any files in serverlist.nodmpcheck
	
	my $EXCLUDEDMP = "/vol/adm/sadocs/serverlist.nodmpcheck";
	my @dmpexclude;		# Holds the servers that will be excluded
	open(EXDMP, $EXCLUDEDMP);

	while (<EXDMP>) {
		chomp();
        	push(@dmpexclude,$_);
	}
	close($EXCLUDEDMP);
#	print("@dmpexclude\n");

	my @isithere = grep(/$serverlist[$host]/, @dmpexclude);
	# Find length = 0 means no match
	my $length = @isithere;

	unless($length) {
	
	my $filetocheck = "/usr/sbin/vxdmpadm";
#	if (-e $filetocheck) {
		$ssh->eat($ssh->peek(0));
		my $dmpout = $ssh->send("$dmp_cmd");
		$line = $ssh->read_line();
#	        while ( defined ($line = $ssh->read_line()) ) {
                	if($line =~ m/DIS|NOT/) {
                        	open(DMP,">>$DMPFILE");
                        	print DMP "$serverlist[$host] has a bad path.\n";
                        	close(DMP);
			}
#                }
#        }
#	else { # File not there, no veritas
#		print("$serverlist[$host] does not have vxdmpadm.\n");
#	}


	}   # End of unless($length)
###############################################################################################
	# Flush the input buffer
	$ssh->read_all(2);

	# Execute check for fmadm -- this will not exist on Solaris 8 servers. Skip those.
	$ssh->eat($ssh->peek(0));
	my $tmpout = $ssh->send("/bin/which /usr/sbin/fmadm");
	my $tmpout = $ssh->read_line();
	if($tmpout =~ m/not found/) {
#		print("fmadm doesn't exist\n");
	}
	else {
		$ssh->read_all(2);
		$ssh->eat($ssh->peek(0));
		my $fmout = $ssh->send("$fmadm_cmd");
		while ( defined ($line = $ssh->read_line()) ) {

	# Temporarily disabled while working on other checks -- will troubleshoot later
			if($line =~ m/sorry/i) {
				# Bad line, do not include it.
			}
			else {
                		open(FM,">>$FMADMFILE");
                        	print FM "$serverlist[$host]:\t$line\n";
                        	close(FM);
			}
               }
	}
	# End of fmadm check
###############################################################################################

	# Flush the input buffer
        $ssh->read_all(1);

	# Check for frozen VCS resources, if VCS is installed
	$ssh->eat($ssh->peek(0));
	my $tmpout = $ssh->send("/bin/which /opt/VRTS/bin/hastatus");
	my $tmpout2 = $ssh->read_line();
	if($tmpout2 =~ m/not found/) {
#		print("Server $serverlist[$host] not clustered\n");
	}
	else {
		my %frozen;
		$ssh->read_all(2);
		$ssh->eat($ssh->peek(0));
		$ssh->send("$frozen_cmd");
		while ( defined ($line = $ssh->read_line()) ) {
			my @list = split(/\s+/, $line);
#			print Dumper \@list;
			if ($list[0] =~ /B/) {
				my ($group,$system,$probed,$autodis,$online) = @list[1..5];
				# Since $autodis is captured here, no need for separate check
                                if($autodis =~ /Y/) {
					if($system =~ /$serverlist[$host]/) {
                                        	open(AD,">>$AUTODISFILE");
                                        	print AD "$group is autodisabled on $system\n";
                                        	close(AD);
					}
                                }
				next if $online =~ /OFFLINE/; # filter "OFFLINE"
				next if $group =~ /ClusterService/;
				push @{$frozen{$group}}, $system;
				next;
			}
			if ($list[0] =~ /G/) {
				my $group = $list[1];
				foreach my $system (@{$frozen{$group}}) {
#				print("System = $system Host = $serverlist[$host]\n");
					if($system =~ /$serverlist[$host]/) {
					# Added 7/20/2010 - find last instance of freeze cmd
			my $tmpcmd = "sudo /bin/cat /var/VRTSvcs/log/engine_A.log |grep -- \"-freeze\" | grep $group |tail -1";
						$ssh->read_all(1);
						my $junk = $ssh->send("$tmpcmd");
						my $logoutput = $ssh->read_line();
						open(FROZ,">>$FROZENFILE");
						print FROZ "$group is frozen on $system\n";
						print FROZ "      $logoutput\n";
						close(FROZ);
					}
				}
				next;
			}
		}
		# Another VCS check -- checking for faulted resources
		$ssh->eat($ssh->peek(0));
		$ssh->send("$vcsfault_cmd");
		while (defined ($line = $ssh->read_line()) ) {
			my @faultlist = split(/\s+/, $line);
			if($faultlist[0] =~ /C/) {
				my ($group,$type,$resname,$system) = @faultlist[1..4];
				if($system =~ /$serverlist[$host]/) {
					open(FAULT,">>$VCSFAULTFILE");
					print FAULT "$system - group $group contains faulted $type : $resname\n";
					close(FAULT);
				}
			}
		}

                # Another VCS check -- checking for monitor timeout entries in engine_A.log
                $ssh->eat($ssh->peek(0));
                $ssh->send("$vcstimeout_cmd");
                while (defined ($line = $ssh->read_line()) ) {
#			print("Line = $line\n");
                        my @logentry = split(/\s+/, $line);
#			my $tmp3 = Dumper(@logentry);
#			print("Dumper = $tmp3\n");
#			print("LogEntry0 = $logentry[0] -- Logentry5 =  $logentry[5]\n");
                        if($logentry[0] =~ /$sysdate/) {
				my $servername = $logentry[5];
                                $servername =~ s/\(//;
                                $servername =~ s/\)//;
#				print("servername is $servername.\n");
#				print("serverlisthost is $serverlist[$host].\n");
#                                if($serverlist[$host] =~ /$servername/) {
                                        open(VCSTO,">>$VCSTIMEOUTFILE");
                                        print VCSTO "$line\n";
                                        close(VCSTO);
#                                }
                        }
                }



	


	}   # End of else, checking for presence of VCS on the host
	# End of cluster checks
###############################################################################################
	# Flush the input buffer
	$ssh->read_all(1);


	# Check for CPUs off-line or faulted
	$ssh->eat($ssh->peek(0));
        my $psrinfo_output = $ssh->send("$psrinfo_cmd");
        my $line;
        while ( defined ($line = $ssh->read_line()) ) {
                if(($line =~ m/[^(on\-line)]/) && ($line =~ /since/)) {
                        open(PSR,">>$PSRINFOFILE");
                        print PSR "$serverlist[$host] has a faulted or off-line CPU\n";
                        close(PSR);
                }
        }
###############################################################################################
	 # Flush the input buffer
#        $ssh->read_all(1);
	$ssh->read_all();

        # Execute svm maintenance check
	$ssh->eat($ssh->peek(0));
        $ssh->send("$svmmaint_cmd");
        my $line;
	my $svm_error=0;	 		# keeps track of whether or not there's a problem (not multiple lines per server)
        while ( $line = $ssh->read_all(3))  {
#        while ( defined ($line = $ssh->read_line()) ) {
                if($line =~ /erred|maint|repl|sync/ix) {
			$svm_error = 1;
                }
        }
	if($svm_error) {
		open(SVM,">>$SVMMAINTFILE");
		print SVM "$serverlist[$host] has a bad mirror/disk\n";
		close(SVM);
		$svm_error=0;
		$ssh->read_all(2);
	}
###############################################################################################
        # Flush the input buffer
        $ssh->read_all(3);
#	$line = "";


	# Execute metadb check
	# This now exists as part of the zfs/ufs mirror check above
#	$ssh->eat($ssh->peek(1));
#	$ssh->send("$metadb_cmd");
#	my $line;
#	while ( defined ( $line = $ssh->read_line()) ) {
#	while ( $line = $ssh->read_all() ) {
#		print("$serverlist[$host] - $line\n");
#		$line = $line + 0;
#		if(($line < 6) && ($line =~ /\d\s*$/)) {
#		if ($line < 6)  {
#			print("Less than 6 metadbs!\n");
#			open(MDB,">>$METADBFILE");
#			print MDB "$serverlist[$host] has less than 6 metadbs\n";
#			close(MDB);
#		}
#	}
###############################################################################################
#	# Flush the input buffer
#	$ssh->read_all(1);

	# Execute vxsvc check
	$ssh->eat($ssh->peek(1));
	$ssh->send("$vxsvc_cmd");
	my $line;
	while ( $line = $ssh->read_all() ) {
		if ( $line =~ /Current state of server : RUNNING/i) {
			open(VXSVC,">>$VXSVCFILE");
			print VXSVC "$serverlist[$host] is running vxsvc\n";
			close(VXSVC);
		}
	}

	# Flush the input buffer
        $ssh->read_all(1);









	# Close ssh connection to this server
	$ssh->close();	
	$pm->finish(1);
}  # End of main while loop for server list

# Since multiple processes were spawned asynchronously, must wait until they're all finished
# before continuing.
$pm->wait_all_children;

# Progress indicator, final value
$progress = ($count / $total_server_count) * 100;
printf "Progress: %4.1f\%\r",$progress;
# Set carriage returns back to normal after progress indicator is complete
select STDOUT;
print "\n";
$| = 0;


# Close filehandle to serverlist
#close(SERVERS);
# Calculate total script time and display to screen
$time_end = time();
my $total_time = $time_end - $time_start;
print("Health check scripts complete.\n");
print("Completed in $total_time seconds.\n");
print("Connected to $connected_server_count out of $total_server_count servers.\n");





# Scripts are done executing, now send the email out with all of the information
# from all of the output files


# Concatenate all files into one for mailing
open(HC,">>", $HC) or die "Could not open $HC $!"; 		
open(DUMP, "<", $DUMPADM) or die "Could not open $DUMPADM $!"; 		
open(MIR,  "<", $MIRRORS) or die "Could not open $MIRRORS $!";	
open(NOC,  "<", $NOCONNECT) or die "Could not open $NOCONNECT $!";	
open(DMP,  "<", $DMPFILE) or die "Could not open $DMPFILE $!";
open(FROZ,  "<", $FROZENFILE) or die "Could not open $FROZENFILE $!";
open(FM,   "<", $FMADMFILE) or die "Could not open $FMADMFILE $!";
open(AD,   "<", $AUTODISFILE) or die "Could not open $AUTODISFILE $!";
open(PSR,  "<", $PSRINFOFILE) or die "Could not open $PSRINFOFILE $!";
open(SVM,  "<", $SVMMAINTFILE) or die "Could not open $SVMMAINTFILE $!";
open(MDB,  "<", $METADBFILE) or die "Could not open $METADBFILE $!";
open(VXSVC, "<", $VXSVCFILE) or die "Could not open $VXSVCFILE $!";
open(VCSFAULT, "<", $VCSFAULTFILE) or die "Could not open $VCSFAULTFILE $!";
open(FCINFO, "<", $FCINFOFILE) or die "Could not open $FCINFOFILE $!";
open(VCSTO, "<", $VCSTIMEOUTFILE) or die "Could not open $VCSTIMEOUTFILE $!";


print HC "Using $server_list as the current list of servers.\n\n";
print HC "Please visit http://belle-ld02.nwie.net/wiki/index.php/Health_Check_Scripts\n";
print HC "for more information on the Health Check scripts.\n\n";
while (my $line = <SVM> ) {
        print HC $line;
}
while (my $line = <VCSFAULT> ) {
	print HC $line;
}
while (my $line = <VXSVC> ) {
        print HC $line;
}
while ( my $line = <DUMP> ) {
	print HC $line;
}
while (my $line = <MIR> ) {
	print HC $line;
}
while (my $line = <DMP> ) {
	print HC $line;
}
while (my $line = <FM> ) {
        print HC $line;
}
# temporary
#print HC "This check has been temporarily suspended while under development.\n";
while (my $line = <FROZ> ) {
        print HC $line;
}
while (my $line = <AD> ) {
        print HC $line;
}
while (my $line = <PSR> ) {
	print HC $line;
}
while (my $line = <MDB> ) {
	print HC $line;
}
while (my $line = <FCINFO> ) {
	print HC $line;
}
while (my $line = <NOC> ) {
        print HC $line;
}
while (my $line = <VCSTO> ) {
	print HC $line;
}

print HC "\n------------------------------------------------------------------------\n";
print HC "Completed in $total_time seconds.\n";
print HC "Connected to $connected_server_count out of $total_server_count servers.\n";
close(NOC);
close(MIR);
close(DUMP);
close(FM);
close(AD);
close(FROZ);
close(HC);
close(DMP);
close(PSR);
close(SVM);
close(MDB);
close(VXSVC);
close(VCSFAULT);
close(VCSTO);

my $mail_sub = "Healthcheck report results";

open(MAIL, "|mail $EMAIL");
print MAIL "To: $EMAIL\n";
print MAIL "From: Healthcheck\n";
print MAIL "Subject: $mail_sub\n";
print MAIL "Content-Type: text/plain; charset=\"iso-8859-1\"\n";

open(MESSAGE, "<", "$HC") or die "$!";
print MAIL <MESSAGE>;
close(MESSAGE);
close(MAIL);

# Delete files once mail has been sent (/tmp/*.hc)
unlink </tmp/*.hc>;

open(LOG,">>$SYSLOG");
print LOG "Healthcheck completed at ";
print LOG strftime('%Y-%b-%d %H:%M',localtime);
print LOG "\n";
close(LOG);
