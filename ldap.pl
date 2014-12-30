#!/usr/bin/perl -w

#use Net::LDAP;
use Net::LDAPS;
use Net::LDAP::Util qw(ldap_error_text);
use Term::ReadKey;
use strict;

my $hostname = "ldap.example.net";
my $userid = `/usr/ucb/whoami`;
my $binddn = "uid=$userid,ou=int,ou=people,dc=example,dc=net";
my $ss;

print("Enter LDAP password to continue: ");
ReadMode('noecho');
my $passwd = <STDIN>;
ReadMode(0);
print("\n");
chomp($passwd);
#my $ldap = Net::LDAP->new($hostname) or die "Unable to connect to $hostname: $@|n";
my $ldap = Net::LDAP->new($hostname, 
                       port => '636',
                       scheme => 'ldaps',
                       cafile => '/var/ldap/UNIXCERT.pem',
) or die "Cound not connect to $hostname\n";

my $result = $ldap->bind(dn=>$binddn, password => $passwd);
if($result->code) {
	die "An error occurred binding to $hostname " . ldap_error_text($result->code) . "\n";
}
#print("If you've gotten this far, you're connected to $hostname.\n");

print("Enter string to search (quit to exit): ");
print("Some example searches: uid=smithj, cn=seb*, gidNumber=280, groupMembership=*sys*\n");
$ss = <STDIN>;
chomp($ss);
print("SS=$ss\n");
#while($ss ne "quit") {
	my @Attrs =  ();
	$result = LDAPsearch($ldap,"$ss", \@Attrs);
#}

my $href = $result->as_struct;
my @arrayOfDNs = keys %$href;

foreach ( @arrayOfDNs) {
	print $_,"\n";
	my $valref = $$href{$_};
	my @arrayOfAttrs = sort keys %$valref;
	my $attrName;
	foreach $attrName (@arrayOfAttrs) {
		next if ($attrName =~ /;binary$/ );
		my $attrVal = @$valref{$attrName};
		print "\t $attrName: @$attrVal \n";
	}
	print "#-------------------------------------\n";
}

my $mesg = $ldap->unbind;
print("Unbound from $hostname.\n");


sub LDAPsearch {

	my ($ldap,$searchString,$attrs, $base) = @_;

print("SearchString = $searchString\n");
	if(!$base) { $base = "ou=int,ou=people,dc=example,dc=net"; }
	if(!$attrs) { $attrs = [ 'uid' ]; }
	my $result = $ldap->search ( base    => "$base",
				     scope   => "sub",
                                     filter  => "$searchString",
                                     attrs   => $attrs
                                   );

}
