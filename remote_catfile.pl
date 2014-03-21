#!/vol/perl/5.8/bin/perl -w

use CGI qw(:all);
use CGI::Carp qw(fatalsToBrowser);
print header;
print start_html('Viewing slogs');


# Cat's a file for use by the cgi/apache module in slogs/sadocs

my $file_to_cat = param('filename');
print "Viewing File $file_to_cat <BR><BR>";
print "<pre>";
open(FILE, $file_to_cat) || die "Can't open file $file_to_cat\n";

while (<FILE>) {
    print;
}
close(FILE);
print "</pre>";

print qq(</BODY></HTML>);
