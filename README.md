<h1>Perl Code</h1>

Scripts that I've written throughout the years to support various systems... 

Mostly on Solaris at this point.


<h3>cleanup.pl</h3>

<p>This script was used to clean out data after a certain time period. It simply would delete data from
the table that was older than a specified date. This was mostly used in testing, but also was planned
for cleaning out historical data after some time where it was deemed no longer useful.</p>

<h3>gridreport.pl</h3>

<p>Management was interested in particular pieces of information, so this script was an attempt to make those
reports available on the web so the managers requesting the data could access it independently of waiting for
an SA to execute the report. It was quickly deprecated when the Solaris environment was no longer the platform
of choice, so no further reports than what exist now were ever added.</p>

<h3>hc2.works.pl</h3>

<p>This is the main healthcheck script that runs from a central jump server, connects in parallel using
Parallel Fork Manager, executes commands via expect and captures the results. The data is then parsed and
then failures/issues are dumped into an email sent twice daily to the run support team. Parts of it are
relatively crude, but not a lot of time to polish it up was taken because it would soon be replaced with a
database version.</p>

<h3>hc_client.pl</h3>

<p>This is "healthcheck 2.0" -- this is the client script that runs on each server, downloads the commands
that it determines should be executed based on criteria in the script -- solaris/solaris10/vxvm/vcs -- based
on the results of those checks, various commands are downloaded from the database, executed, and the output
is inserted into a different table. This made adding new commands a snap (see manage_commands.pl) and enabling
and disabling commands just a matter of using the web interface.</p>

<h3>mailer.pl</h3>

<p>A simple web-based email/comment script that will email the contents of the html forms to the specified
address. It was made general enough to be used in many different scenarios.</p>

<h3>manage_commands.pl</h3>

<p>This is part of the Healthcheck 2.0 suite -- used to add or remove commands to be executed, as well as
change the frequency at which they execute and report results. Web interface for easy management.</p>

<h3>primary_nodes.pl</h3>

<p>This script can be run on Veritas Cluster Server (VCS) servers to determine if a service group is running
on it's primary node or not. It compares the current node to the SystemList property to see where it should
be running.</p>

<h3>reclaim_check.pl</h3>

<p>When SAN storage is no longer required, the storage team would pull the luns back so they can be reprovisioned.
This introduces the risk of erroneously pulling luns that are still in use, so this script was a quick hit
that I used to determine if there were any hung mounts or disconnected devices following a reclaim.</p>

<h3>reclaim_cleanup.pl</h3>

<p>Following a SAN reclaim when luns are pulled away from the server, the device files and EMC powerpath devices
are left around. This script facilities cleanup of those devices (only works on Solaris 10 systems at this point).
</p>

<h3>remote_catfile.pl</h3>

<p>This script was another quick hit that allowed me to cat particular files to the web. This was used in a web-
based log viewing system. Rather than build it into that script, it was made separate for future utilization 
elsewhere.</p>

<h3>webslog.pl</h3>

<p>Following work on a server, slog (system log) was a way we used to make a note of what we changed, or in
the event of an incident, what was broken and how it was fixed. Over the years this built up a very comprehensive
knowledge base of solutions. The original version of slog was a Vim template, but some team members desired a
web interface, and thus this script was born.</p>