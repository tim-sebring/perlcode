#!/vol/perl/5.8/bin/perl 

######################################################
# Cleans up luns that are errored/unavailable
# following a SAN reclaim procedure.
# 
# Changelog
# 2011/4/11 - sebrint - Script created
#
######################################################
#use Data::Dumper;

use warnings;
use strict;

my $i;

my @emclist;
my @formatlist;
 
# WARNING to run on only ONE NODE at a time
print("\nWARNING: DO NOT run this script on more than one node in a cluster at a time ");
print("\nDo you wish to proceed? (y/[n]): ");
my $ans = <STDIN>;
chomp($ans);
if($ans ne 'y') {
        print("Exiting script.\n");
        exit;
}


# Ensure user is root
my $user = `/usr/ucb/whoami`;
chomp($user);
if ($user ne "root") {
	&print_noroot;
}
# ensure nothing was passed to command line
my $parms = $ARGV[0];

if($parms) { 
	&print_usage;
}

# Collect information on which disks will be cleaned up... using format

print("\n\nCollecting list of emcpower devices...");
@emclist = `echo |format |grep available | awk '\{print \$2\}' |grep emcpower`;
chomp(@emclist);
#my $tmp = Dumper(@emclist);
#print $tmp;
#print("emca = @emclist\n");
# Must remove the 'a' from the end of the line on each emcpower device
#
 foreach my $item (@emclist) {
         $item =~ s/\w$//g;
         }

print(" Done\n");
print("\nCollecting list of CTD devices...");
@formatlist = `echo |format |grep available | awk '\{print \$2\}' |grep -v emcpower`;
chomp(@formatlist);
print(" Done\n\n");

#print("formatlist = @formatlist\n");

# Check to see if there are any devices to clean up
my $flen = @formatlist;
my $elen = @emclist;
if(!$flen and !$elen) {
	print("No devices found to clean up.\nExiting.\n");
	exit;
}

# Print a verification that the user wants to proceed, printing out the disks to be cleaned up.

print("\nThe following devices will be cleaned up:\n\n");
foreach my $e (@emclist) {
	print("$e\n");
}
foreach my $f (@formatlist) {
	print("$f\n");
}
print("\nDo you wish to proceed? (y/[n]): ");
$ans = <STDIN>;
chomp($ans);
if($ans ne 'y') {
	print("Exiting script.\n");
	exit;
}


# loop through emc devices and run the following commands:
print("Executing vxdisk rm and powermt check commands.... ");
foreach my $disk (@emclist) {
#	print("vxdisk rm ${disk}s2\n");
	my $tmp1 = `vxdisk rm ${disk}s2`;
#	print("yes|/etc/powermt check dev=$disk\n");
	my $tmp2 = `yes|/etc/powermt check dev=$disk`;
}
print("Done.\n\n");
# loop through the format devices and run the following command

print("Executing luxadm -e offline commands.... ");
foreach my $disk (@formatlist) {
#	print("luxadm -e offline /dev/dsk/${disk}s2\n");
	my $tmp3 = `luxadm -e offline /dev/dsk/${disk}s2`;
}
print("Done\n\n");

# now offline all of the failing disks, to make them unusable:
#cfgadm -al |grep unusable |awk '{print $1}' |xargs cfgadm -c unconfigure -o unusable_SCSI_LUN
print("Executing cfgadm to unconfigure unusable devices.... ");
#print("cfgadm -al |grep unusable |awk '\{print \$1\}' |xargs cfgadm -c unconfigure -o unusable_SCSI_LUN\n");
my $tmp3a = `cfgadm -al |grep unusable |awk '\{print \$1\}' |xargs cfgadm -c unconfigure -o unusable_SCSI_LUN`;
print("Done\n\n");

# run the cleanup commands
print("Executing devfsadm -Cv... ");
my $tmp4 = `devfsadm -Cv`;
print("Done\nExecuting powercf -q... ");
my $tmp5 = `/etc/powercf -q`;
print("Done\nExecuting powermt config... ");
my $tmp6 = `/etc/powermt config`;
print("Done\nExecuting powermt save... ");
my $tmp7 = `/etc/powermt save`;
print("Done\n");

print("\nReady to start vxdisk scandisks.  Do you wish to proceed? (y/[n]): ");
$ans = <STDIN>;
chomp($ans);
if($ans ne 'y') {
	print("Exiting script.\n");
	exit;
}
my $tmp8 = `/usr/sbin/vxdisk scandisks`;
print("Done.\n\n");
print("vxdisk scandisks has completed.  Do you wish to proceed? (y/[n]): ");
$ans = <STDIN>;
chomp($ans);
if($ans ne 'y') {
	print("Exiting script.\n");
	exit;
}

# Now verify that all of the failed devices are gone:

print("Executing verification checks\n\n");
print("Executing cfgadm -al -o show_SCSI_LUN |egrep \"unusable|failing\"... ");
my $tmp9 = `cfgadm -al -o show_SCSI_LUN |egrep "unusable|failing"`;
if($tmp9) {
	print("\nWarning: devices showing as unusable/failing in cfgadm:\n$tmp9\n");
}
print("Done\nExecuting echo | format |grep available... ");
my $tmp10 = `echo | format |grep available`;
if($tmp10) {
	print("\nWarning: devices shown as not available in format:\n$tmp10\n");
}
print("Done\nExecuting vxdisk list |grep error... ");
my $tmp11 = `vxdisk list |grep error`;
if($tmp11) {
	print("\nWarning: devices showing as errored in vxdisk list:\n$tmp11\n");
}
print("Done\nExecuting powermt display dev=all |grep dead... ");
my $tmp12 = `/etc/powermt display dev=all |grep dead`;
if($tmp12) {
	print("\nWarning: devices showing as dead in powermt display:\n$tmp12\n");
}
print("Done\nExecuting symcfg discover... ");
my $tmp13 = `/usr/symcli/bin/symcfg discover`;
print("Done.\n");


print("Script terminated normally.\n");


########### Functions ######################
sub print_usage {
	print("Cleans up disconnected luns.\n");
	print("Must be run as root\n\n");
	print("Usage: reclaim_cleanup.pl\n");
        exit;
}

sub print_noroot {
	print("This script must be executed as root.\n");
	exit;
}
