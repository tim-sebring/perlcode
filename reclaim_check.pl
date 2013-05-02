#!/vol/perl/5.8/bin/perl 

use strict;


# Run the rescan commands
print("Rescanning bus...... ");
system("cfgadm -al");
system("vxdisk scandisks");
print(" Done\n\n");

# Run check commands for errors
print("Running checks...... \n");
system("vxprint -ht |egrep \"NDEV|NODEVICE\"");
print("Sleeping for 5 seconds....\n");
system("sleep 5");
system("mount");
system("df -k");
print(" Done\n\n");

