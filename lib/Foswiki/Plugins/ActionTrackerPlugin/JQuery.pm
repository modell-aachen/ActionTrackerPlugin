# See bottom of file for license and copyright information

package Foswiki::Plugins::ActionTrackerPlugin::JQuery;
use strict;

use Assert;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name     => 'ActionTracker',
        version  => '1.1',
        author   => 'Crawford Currie',
        homepage => 'http://foswiki.org/Extensions/ActionTrackerPlugin',
        puburl   => '%PUBURLPATH%/%SYSTEMWEB%/ActionTrackerPlugin',

        # CSS is added in ActionTrackerPlugin.pm
        css           => [],
        documentation => "$Foswiki::cfg{SystemWebName}.ActionTrackerPlugin",
        javascript    => ["atp.js"],
        dependencies  => [ 'UI', 'livequery' ],
    );

    return $this;
}

1;
__END__

Copyright (C) 2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html
