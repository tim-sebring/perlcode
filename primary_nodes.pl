#!/vol/perl/5.8/bin/perl 

use CGI qw(:all);
use CGI::Carp qw(fatalsToBrowser);
use Net::SSH::Expect;

use strict;
print header;
print start_html('Check for service groups not running on primary nodes');

my $serverlist = "/vol/adm/sadocs/serverlist2";
my $user = "username";
my $cmd1="sudo /opt/VRTS/bin/hagrp -display|grep SystemList |grep -v ClusterService |grep -v multin |egrep \"global|localclus\"";
my $hostname_nodots;
my $prtbreak = 0;

open(SERVERLIST, "< $serverlist");

while(<SERVERLIST>)
{
    chomp();
#print("$_ ");
    my $ssh = Net::SSH::Expect->new (
	host => "$_",
	user => "$user",
	raw_pty => 1
	);


    # Initiates the ssh connection to the remote host
    $ssh->run_ssh() or die "SSH process couldn't start: $!";
    my $ret;
    my $rc1 = eval{$ret = $ssh->read_all(12);};
    unless($rc1) {
	print("$_ - Could not connect -- skipping.<BR>");
	next();
    }

    my $rc = eval{( $ret =~ />\s*|$\s*\z/) or die "where's the remote prompt?";};
    if($rc) {
	if($ret =~ m/[Pp]assword:/) {
	    print("$_ - Asking for password -- skipping.<BR>");
	    next();
	}
    }

    $ssh->exec("stty raw -echo");
    # find the hostname without all the dots and subdomains
    my $tmpindex = index($_,'.');
    if($tmpindex != -1) {
	$hostname_nodots = substr($_, 0, $tmpindex);
    }
    else {
	$hostname_nodots = $_;
    }
    my $cmdoutput = $ssh->exec("$cmd1");

#if($cmdoutput =~ /not found/) {
#print(" - Not a clustered server.<BR>"); 
#next();
# }

    if($prtbreak) {
	print("<BR>");
	$prtbreak = 0;
    }

    # strip out the prompt at the end of the string
#$cmdoutput =~ s/\S*:$user>|\$//;
#my $prompt = $ENV{PS1};
#print("Prompt = $prompt<BR>");
#$cmdoutput =~ s/$prompt//;
    # convert newlines to <BR> -- only when displaying on the web... not for processing!
    #$cmdoutput =~ s/\n/<BR>/g;
    chomp($cmdoutput);
#chop($cmdoutput);
#my @lines = split /\n/,$cmdoutput;
#foreach my $line (@lines) {
#print("DEBUG LINE = $line<BR>");
#}


    #need to split the output into separate lines... process 1 at a time? or put in array?
    my @splitfile = split(/\n/, $cmdoutput);


    foreach $cmdoutput (@splitfile) {
	my @readline = split(/\s+/, $cmdoutput);
	my $readline = @readline;
	my $grpname = $readline[0];
	my $locality = $readline[2];
	shift(@readline);
	shift(@readline);
	shift(@readline);
	my %myhash = @readline;
	my @ordered_list = sort values %myhash;
	my $primary_num = $ordered_list[0];
	my %rhash = reverse %myhash;
	my $primary_name = $rhash{$primary_num};
	if($cmdoutput =~ /SystemList/) {
	    print("$_ : Primary node for group $grpname is $primary_name.<BR>");
	    $prtbreak = 1;
	}


    }


    $ssh->close();
}
print("<BR>Script complete.<BR>");
print qq(</BODY></HTML>);
