# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::ActionTrackerPlugin::Options;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

our $MIN_JQUERY = '1.7';

sub check {
    my $this = shift;

    my $selVer = $Foswiki::cfg{JQueryPlugin}{JQueryVersion};

    unless ( $selVer && $selVer =~ s/^jquery-// ) {
        return $this->ERROR(<<'EOF');
No {JQueryPlugin}{JQueryVersion} defined. This configuration setting must be
defined for the ActionTrackerPlugin to work. It is defined automatically
when the JQueryPlugin is correctly installed.
EOF
    }

    my @sel = split( /\./, $selVer );
    my @req = split( /\./, $MIN_JQUERY );

    # normalize number of fields, so we can compare 1.3 and 1.4.2.1
    push( @req, 0 ) while scalar(@req) < scalar(@sel);
    push( @sel, 0 ) while scalar(@req) > scalar(@sel);

    # build an integer for each version
    my ( $sv, $rv ) = ( 0, 0 );
    for ( my $i = 0 ; $i < scalar(@sel) ; $i++ ) {
        $sv = $sv * 1000 + $sel[$i];
        $rv = $rv * 1000 + $req[$i];
    }
    unless ( $sv >= $rv ) {
        return $this->ERROR(<<EOF);
ActionTrackerPlugin requires {JQueryPlugin}{JQueryVersion} >= $MIN_JQUERY
but $Foswiki::cfg{JQueryPlugin}{JQueryVersion} is selected.
EOF
    }

    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
