#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build("ActionTrackerPlugin");
$build->build($build->{target});
