#!/vol/perl/5.8/bin/perl

###############################################################################
#                        cleanup.pl                                           #
###############################################################################
#  This script is part of the HealthCheck 2.0 family of scripts.              #
#  Other scripts include those running on sedjct825 and belle-ld02            #
#                                                                             #
#  The purpose of this script is to clean up data that has aged a particular  #
#  number of days. The time is arbitrary, and mostly depends on how much      #
#  space the range of data takes up, and what management wants to keep for    #
#  historical reasons.
###############################################################################
#                   Changelog  - please document changes here                 #
#        (and remember to make a backup copy first!)                          #
# 2011-10-21 - sebrint - script created                                       #
###############################################################################

use lib '/vol/perl/5.8/DBD/oracle10.2.0.4/lib/site_perl/5.8.1/sun4-solaris';
use DBI;
use Data::Dumper;
use strict;

$ENV{'TWO_TASK'}="toold";
$ENV{'ORACLE_HOME'}="/vol/oracle10.2.0.4";
$ENV{'TNS_ADMIN'}="/vol/rdbms/oracle/net";
my $user="healthck";
my $pass="sebring12";
my $tblspace="toold";
my @row;
my $sth;
my $dbh;
my %commands;

my $DATERANGE = 5;
		
# connect to database
$dbh = DBI->connect("dbi:Oracle:$tblspace","$user","$pass") || die ($DBI::errstr . "\n");

# Delete
$sth = $dbh->prepare("delete from tblserverattributes where timeupdated < (SYSDATE - $DATERANGE)");


$sth->execute;

$dbh->disconnect();
