#!/vol/perl/5.8/bin/perl -w

use strict;
use CGI qw(:all);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use CGI;
use Data::Dumper;
use Date::Manip;
use MIME::Entity;

my $cgi = CGI->new;
my %form_defaults;
my %form_data;
my $EMAIL = "me@mydomain.net";



print header;

if($cgi->param('reset_form')) {
    &reset_form;
    if($cgi->param('reset_form') eq "Clear") {
	$cgi->delete('reset_form');
    }
}

if($cgi->param('slog_submit')) {

    print start_html('Web-Slog Submission Results');
    print(qq(<div align="center"><h2>Web-Slog Submission Results</h2></div>));
    print(qq(<BR><HR><BR>));

    print("Slog submitted.<BR><BR>");
    print(qq(Go to the <a href="webslog.pl">Slog submission page</a><BR>));
    print(qq(Go to the <a href="/wiki">wiki homepage</a>));


    my $sa_name = $cgi->param('sa_name');
    my $machine_name = $cgi->param('machine_name');
    my @related_machines = split(',',$cgi->param('related_machines'));
    my $slog_date = $cgi->param('slog_date');
    my $slog_time = $cgi->param('slog_time');
    my $ticket_number = $cgi->param('ticket_number');
    my $severity = $cgi->param('severity');
    my $paged = $cgi->param('paged');
    my $vendor_case_number = $cgi->param('vendor_case_number');
    my $vendor_contact = $cgi->param('vendor_contact');
    my $resolve_time = $cgi->param('resolve_time');
    my @keywords = $cgi->param('keywords');
    my $description = $cgi->param('description');

    my $errors = "";

# check for empty fields -- some are required
    if(!$sa_name) { $errors .= "<font color=\"red\">SA Name cannot be blank</font><BR>"; }
    if(!$machine_name) { $errors .= "<font color=\"red\">Machine Name cannot be blank</font><BR>"; }
    if(!$slog_date) { $errors .= "<font color=\"red\">Date of slog cannot be blank</font><BR>"; }
    if(!$slog_time) { $errors .= "<font color=\"red\">Time of slog cannot be blank</font><BR>"; }
    if(!$ticket_number) { $errors .= "<font color=\"red\">Ticket Number cannot be blank</font><BR>"; }
    if(!$severity) { $errors .= "<font color=\"red\">Severity cannot be blank</font><BR>"; }
    if(!$paged) { $errors .= "<font color=\"red\">Paged cannot be blank (yes or no)</font><BR>"; }
    if(!$resolve_time) { $errors .= "<font color=\"red\">Resolve time cannot be blank</font><BR>"; }
    if(!$description) { $errors .= "<font color=\"red\">Description cannot be blank</font><BR>"; }


    if($errors) {
	print(qq(<div align="center"><br><br>Please resolve the following errors by clicking <input type="button" name="back" value="Back" onClick="history.go(-1);"><BR>));
	print(qq(<blockquote>$errors</blockquote></div>));
	print(qq(<BR><BR>));
    }
    else { #no errors
#send the message, and concat to logFiles
i

    my $mail_message = "";

$mail_message .= "***************************************************************\n";
$mail_message .= "\n";
$mail_message .= "SA:                       " . "$sa_name\n";
$mail_message .= "Ticket Number:            " . "$ticket_number\n";
$mail_message .= "Severity                  " . "$severity\n";
$mail_message .= "Date of Issue:            " . "$slog_date\n";
$mail_message .= "Time of Issue:            " . "$slog_time\n";
$mail_message .= "Paged:                    " . "$paged\n";
$mail_message .= "Vendor Ticket:            " . "$vendor_case_number\n";
$mail_message .= "Vendor Contact:           " . "$vendor_contact\n";
$mail_message .= "Resolution Time:          " . "$resolve_time\n";
$mail_message .= "Machine Name:             " . "$machine_name\n";
foreach my $host (@related_machines) {
    $mail_message .= "Related Machine:          " . "$host\n";
}
$mail_message .= "Description:\n$description\n\n";

my $mailob = MIME::Entity->build(Type=>"text/plain",
				 To=> $EMAIL,
				 Subject=> "Maintenance on $machine_name",
				 From =>   "$sa_name\@companyname.com",
				 'Reply-To' =>   "$sa_name\@company.com",
				 Encoding => "quoted-printable",
				 Data => $mail_message,
    );
$mailob->smtpsend;




#email $EMAIL with the slog

#open(MAIL, "|mailx $EMAIL");
#print MAIL "To: $EMAIL\n";
#print MAIL "From: $sa_name\n";
#print MAIL "Subject: Maintenance on $machine_name\n";
#print MAIL "Content-Type: text/plain; charset=\"iso-8859-1\"\n";

#print MAIL $mail_message;
#close(MAIL);





    } #else

} # form_submit

else {
# form hasn't been submitted yet, display form fields

    &reset_form;

# Calculate current date and time for pre-population of html forms
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
    $year += 1900;
    $mon++;
    my $currdate = $mon . "/" . $mday . "/" . $year;
    my $minpadded = sprintf('%02d',$min);
    my $currtime = $hour . ":" . $minpadded;

    print start_html('Web-Slog Submission Form');
    print(qq(<div align="center"><h2>Web-Slog Submission Page</h2></div>));
    print(qq(<BR><HR><BR>));
    print(qq(<form name="slog-submit-form" method="post" action="webslog.pl">));

    print(qq(<table border=0 width="75%" align="center">));
    print(qq(<tr><td align="right"><b>SA</b></td><td><input type="text" name="sa_name" size=30 maxlength=500 value="$form_defaults{sa_name}"></td></tr>));
print(qq(<tr><td align="right"><b>Machine Name</b></td><td><input type="text" name="machine_name" size=30 maxlength=500 value="$form_defaults{machine_name}"></td></tr>));

print(qq(<tr><td align="right"><b>Related Machines <font size=2>(Separate by commas)</font></b></td><td><input type="text" name="related_machines" size=30 maxlength=5000 value="$form_defaults{'related_machines'}"></td></tr>));
print(qq(<tr><td align="right"><b>Date</b></td><td><input type="text" name="slog_date" size=30 maxlength=500 value="$form_defaults{'date'}"></td></tr>));
print(qq(<tr><td align="right"><b>Time</b></td><td><input type="text" name="slog_time" size=30 maxlength=500 value="$form_defaults{'time'}"></td></tr>));
print(qq(<tr><td align="right"><b>Ticket/ITTL Number</b></td><td><input type="text" name="ticket_number" size=30 maxlength=500 value="$form_defaults{'ticket_num'}"></td></tr>));
    print(qq(<tr><td align="right"><b>Severity</b></td><td><input type="text" name="severity" size=30 maxlength=500 value="$form_defaults{'severity'}"></td></tr>));
print(qq(<tr><td align="right"><b>Paged</b></td><td><input type="text" name="paged" size=30 maxlength=500 value="$form_defaults{'paged'}"></td></tr>));
print(qq(<tr><td align="right"><b>Vendor Case Number</b></td><td><input type="text" name="vendor_case_number" size=30 maxlength=500 value="$form_defaults{'vendor_case'}"></td></tr>));
print(qq(<tr><td align="right"><b>Vendor Contact</b></td><td><input type="text" name="vendor_contact" size=30 maxlength=500 value="$form_defaults{'vendor_contact'}"></td></tr>));
print(qq(<tr><td align="right"><b>Resolve Time</b></td><td><input type="text" name="resolve_time" size=30 maxlength=500 value="$form_defaults{'resolve_time'}"></td></tr>));
print(qq(<tr><td align="right"><b>Key Words<font size=2>(for searching)</font></b></td><td><input type="text" name="keywords" size=30 maxlength=500 value="$form_defaults{'keywords'}"></td></tr>));
    print(qq(<tr><td align="right" valign="top"><b>Description</b></td><td><textarea name="description" rows=17 cols=70>$form_defaults{'description'}</textarea></td></tr>));

    print(qq(</table>));

print(qq(<table align="center" border=0><tr><td><div align=center><input type="submit" name="slog_submit" value="Submit"></form></td><td><form method="GET" action="webslog.pl"> <input type="submit" name="reset_form" value="Clear"></div>));
    print(qq(</form></td></tr></table>));


} #end else


print end_html;


sub reset_form {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
    $year += 1900;
    $mon++;
    my $currdate = $mon . "/" . $mday . "/" . $year;
    my $minpadded = sprintf('%02d',$min);
    my $currtime = $hour . ":" . $minpadded;


    %form_defaults = (
	sa_name => "",
	machine_name => "none",
	related_machines => "",
	date => $currdate,
	time => $currtime,
	ticket_num => "",
	severity => "4",
	paged => "no",
	vendor_case => "",
	vendor_contact => "",
	resolve_time => "00:30",
	keywords => "",
	description => "",
	);
} #reset_form

sub check_syntax {
    # checks the syntax of the user-entered data to make sure it's valid

    return 1;  #will add later, for now assuming all forms are valid.
    
}
