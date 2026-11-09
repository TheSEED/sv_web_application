#!/usr/bin/env perl

use strict;
use warnings;

use WebApplicationDBHandle;

use Getopt::Long;


sub usage {
  print "remove_deprecated_sessions.pl >>> removes deprecated sessions from the web application database\n";
  print "  Removes anonymous UserSession rows older than 2 days\n";
  print "  Removes authenticated UserSession rows older than 30 days\n";
  print "  Removes legacy Session/SessionItem rows older than 2 days\n";
  print "remove_deprecated_sessions.pl -execute 1 \n";
}

my $execute;

GetOptions ( 'execute=s' => \$execute );


unless ($execute) {
  &usage();
  exit 0;
}


# initialize db-master
my ($dbmaster, $error) = WebApplicationDBHandle->new();

# check if we got a dbmaster
if ($error) {
  print $error."\n";
  exit 0;
}

my $dbh = $dbmaster->db_handle;

# Remove anonymous UserSession rows older than 2 days
my $anon_cutoff = time - 172800;
# Remove authenticated UserSession rows older than 30 days
my $auth_cutoff = time - 2592000;
# Remove all legacy Session/SessionItem rows older than 2 days (table no longer written to)
my $legacy_cutoff = time - 172800;

eval {

  print "Deleting anonymous UserSession entries older than 2 days...\n";
  $dbh->do("DELETE FROM UserSession WHERE timestamp < FROM_UNIXTIME($anon_cutoff) AND user IS NULL");

  print "Deleting authenticated UserSession entries older than 30 days...\n";
  $dbh->do("DELETE FROM UserSession WHERE timestamp < FROM_UNIXTIME($auth_cutoff) AND user IS NOT NULL");

  print "Deleting legacy SessionItem entries...\n";
  $dbh->do("DELETE FROM SessionItem WHERE session IN (SELECT _id FROM Session WHERE creation < FROM_UNIXTIME($legacy_cutoff))");

  print "Deleting legacy Session entries...\n";
  $dbh->do("DELETE FROM Session WHERE creation < FROM_UNIXTIME($legacy_cutoff)");

  $dbh->commit;

};

if ($@) {
  Trace("Transaction aborted: $@") if T(0);
  eval { $dbh->rollback };
  if ($@) {
    Confess("Rollback failed: $@");
  }
} else {

  print "Done.\n";

}
