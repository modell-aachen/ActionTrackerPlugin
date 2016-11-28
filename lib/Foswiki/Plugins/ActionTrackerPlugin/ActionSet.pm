# See bottom of file for license and copyright information

# Perl object that represents a set of actions (possibly interleaved
# with blocks of topic text)
package Foswiki::Plugins::ActionTrackerPlugin::ActionSet;

use strict;
use integer;
use Foswiki::Func;

use Foswiki::Plugins::ActionTrackerPlugin::Format;

# PUBLIC constructor
sub new {
    my $class = shift;
    my $this  = {};

    $this->{ACTIONS} = [];

    return bless( $this, $class );
}

# PUBLIC Add this action to the list of actions
sub add {
    my ( $this, $action ) = @_;

    push @{ $this->{ACTIONS} }, $action;
}

sub first {
    my $this = shift;
    return undef unless scalar(@{$this->{ACTIONS}});
    return $this->{ACTIONS}->[0];
}

# PUBLIC STATIC load an action set from a block of text
sub load {
    my ( $web, $topic, $text, $keepText ) = @_;

    $text =~ s/\r//g;
    my @blocks       = split( /(%ACTION\{.*?\}%|%ENDACTION%)/ms, $text );
    my $actionSet    = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
    my $i            = 0;
    my $actionNumber = 0;
    while ( $i < scalar(@blocks) ) {
        my $block = $blocks[ $i++ ];
        if ( $block =~ /^%ACTION\{(.*)\}%$/s ) {
            my $attrs = $1;
            my $descr;
            # Sniff ahead to see if we have a matching ENDACTION
            if (   $i + 1 < scalar(@blocks)
                && $blocks[ $i + 1 ] =~ /%ENDACTION%/ )
            {

                # Action block
                $descr = $blocks[ $i++ ];    # action text
                $i++;                        # skip %ENDACTION%
            }
            else {

                # Old syntax
                if ( $blocks[$i] =~ s/^\s*<<(\w+)(.*)\n\1//s ) {
                    $descr = $2;
                    $i++ unless length( $blocks[$i] ) && $blocks[$i] =~ /\S/;
                }
                elsif ( $blocks[$i] =~ s/^(.*?)\n/\n/s ) {
                    $descr = $1;
                }
                else {
                    $descr = $blocks[ $i++ ];
                }
            }
            my $action =
              new Foswiki::Plugins::ActionTrackerPlugin::Action( $web, $topic,
                $actionNumber++, $attrs, $descr );
            $actionSet->add($action);
        }
        elsif ($keepText) {
            $actionSet->add($block);
        }
        $i++ while $i < scalar(@blocks) && !length( $blocks[$i] );
    }
    return $actionSet;
}

# PRIVATE place to put sort fields
my @_sortfields;

# PUBLIC sort by due date or, if given, by an ordered sequence
# of attributes by string value (or numeric value if they are all numbers)
sub sort {
    my ( $this, $order, $reverse ) = @_;
    my @ordered;
    if ( defined($order) ) {
        $order =~ s/[^\w,]//g;
        @_sortfields = (split( /,\s*/, $order ));

	# Determine sort type - numeric or string. Dates are held as numbers.
	my %num_sort = map { $_ => 1 } @_sortfields;
	foreach my $act (@{ $this->{ACTIONS} }) {
	    my $all_string = 1;
	    foreach my $sf (@_sortfields) {
		next unless defined($act->{$sf}); # ignore undefs, they can't help us decide
		if ($num_sort{$sf}) {
		    if ($act->{$sf} =~ /^(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?\s*$/) {
			$all_string = 0;
		    } else {
			$num_sort{$sf} = 0;
		    }
		}
	    }
	    last if $all_string;
	}
        @ordered = sort {
            foreach my $sf (@_sortfields) {
                return -1 unless ref($a);
                return 1  unless ref($b);
                my ( $x, $y ) = ( $a->{$sf}, $b->{$sf} );
                if ( defined($x) && defined($y) ) {
		    my $c;
                    if ($num_sort{$sf}) {
			$c = ($x <=> $y);
		    } else {
			$c = ( $x cmp $y );
		    }
                    return $c if ( $c != 0 );

                    # COVERAGE OFF should never be needed
                }
                elsif ( defined($x) ) {
                    return -1;
                }
                elsif ( defined($y) ) {
                    return 1;
                }

                # COVERAGE ON
            }

            # default to sorting on due
            my $x = $a->secsToGo();
            my $y = $b->secsToGo();
            return $x <=> $y;
        } @{ $this->{ACTIONS} };
    }
    else {
        @ordered =
          sort {
            my $x = $a->secsToGo();
            my $y = $b->secsToGo();
            return $x <=> $y;
          } @{ $this->{ACTIONS} };
    }
    if ( Foswiki::Func::isTrue($reverse) ) {
        @{ $this->{ACTIONS} } = reverse @ordered;
    }
    else {
        @{ $this->{ACTIONS} } = @ordered;
    }
}

# PUBLIC Concatenate another action set to this one
sub concat {
    my ( $this, $actions ) = @_;

    push @{ $this->{ACTIONS} }, @{ $actions->{ACTIONS} };
}

# PUBLIC Search the set of actions for actions that match the given
# attributes. Return an ActionSet. If the search expression is empty,
# all actions match.
sub search {
    my ( $this, $attrs ) = @_;
    my $action;
    my $chosen = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();

    foreach $action ( @{ $this->{ACTIONS} } ) {
        if ( ref($action) && $action->matches($attrs) ) {
            $chosen->add($action);
        }
    }

    return $chosen;
}

sub stringify {
    my $this = shift;
    my $txt  = '';
    foreach my $action ( @{ $this->{ACTIONS} } ) {
        if ( ref($action) ) {
            $txt .= $action->stringify();
        }
        else {
            $txt .= $action;
        }
    }
    return $txt;
}

# PUBLIC format the action set as an HTML table
# Pass $type="name" to to get an anchor to a position
# within the topic, "href" to get a jump. Defaults to "name".
# Pass $newWindow=1 to get separate browser window,
# $newWindow=0 to get jump in same window.
sub formatAsHTML {
    my ( $this, $format, $jump, $class ) = @_;
    return $format->formatHTMLTable( \@{ $this->{ACTIONS} },
        $jump, $class );
}

# PUBLIC format the action set as a plain string
sub formatAsString {
    my ( $this, $format ) = @_;
    return $format->formatStringTable( \@{ $this->{ACTIONS} } );
}

# PUBLIC find actions that have changed.
# Recent actions will have a UID that lets us match them exactly,
# but older actions will not have a UID and will have to be
# matched using a fuzzy match tuned for detecting 'interesting'
# state changes in actions.
# See Action->fuzzyMatches for details.
# Changed actions are returned as text in a hash keyed on the
# names of people who have registered for notification.
sub findChanges {
    my ( $this, $old, $date, $format, $notifications ) = @_;

    my @news = grep { ref($_) } @{ $this->{ACTIONS} };
    my @unmatched;

    # Try and match by UIDs first. If all the actions in your
    # wiki are known to have UIDs, they should all match here.
    foreach my $oaction ( @{ $old->{ACTIONS} } ) {
        next unless ref($oaction);
        my $uid = $oaction->{uid};
        if ( defined($uid) ) {
            my $n = 0;
            while ( $n < scalar(@news) ) {
                my $naction = $news[$n];
                if ( defined( $naction->{uid} )
                    && $naction->{uid} eq $uid )
                {
                    $naction->findChanges( $oaction, $format, $notifications );
                    splice( @news, $n, 1 );
                    last;
                }
                else {
                    $n++;
                }
            }
        }
        push( @unmatched, $oaction );
    }

    # Assume the action _order_ is not changed, but actions may have
    # been inserted or deleted. For each old action,
    # find the next new action that fuzzyMatches the old action starting
    # from the most recently matched new action.
    foreach my $oaction (@unmatched) {
        my $bestMatch = -1;
        my $bestScore = -1;
        my $n         = 0;
        while ( $n < scalar(@news) ) {
            my $naction = $news[$n];
            my $score   = $naction->fuzzyMatches($oaction);
            if ( $score > $bestScore ) {
                $bestMatch = $n;
                $bestScore = $score;
            }
            $n++;
        }
        if ( $bestScore > 7 ) {
            my $naction = $news[$bestMatch];
            $naction->findChanges( $oaction, $format, $notifications );
            splice( @news, $bestMatch, 1 );
        }
    }

    # The remaining actions in @news were not matched
}

# PUBLIC get a map of all people who have actions in this action set
sub getActionees {
    my ( $this, $whos ) = @_;
    my $action;

    foreach $action ( @{ $this->{ACTIONS} } ) {
        next unless ref($action);
        my @persons = split( /,\s*/, $action->{who} );
        foreach my $person (@persons) {
            $whos->{$person} = 1;
        }
    }
}

# PUBLIC STATIC get all actions in topics in the given web that
# match the search expression
# $web - name of the web to search
# $attrs - attributes to match
# $internal - boolean true if topic permissions can be ignored
sub allActionsInWeb {
    my ( $web, $attrs, $internal ) = @_;
    $internal = 0 unless defined($internal);
    my $actions = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
    my @tops    = Foswiki::Func::getTopicList($web);
    my $topics  = $attrs->{topic};

    @tops = grep( /^$topics$/, @tops ) if ($topics);
    my $grep = Foswiki::Func::searchInWebContent(
        '%ACTION{.*}%',
        $web,
        \@tops,
        {
            type                => 'regex',
            files_without_match => 1,
            casesensitive       => 1
        }
    );

    if( ref( $grep ) ne 'HASH' ) { # New Func implementation
        my %oldResultSet;
        while( $grep->hasNext() ) {
            my $webtopic = $grep->next();
            my ($foundWeb, $topic) = Foswiki::Func::normalizeWebTopicName($web, $webtopic);
            $oldResultSet{$topic} = 1;
        }
        $grep = \%oldResultSet;
    }

    foreach my $topic ( keys %$grep ) {
        # SMELL: always read the text, because it's faster in the current
        # impl to find the perms embedded in it
        my $text =
          Foswiki::Func::readTopicText( $web, $topic, undef, $internal );
        next
          unless $internal
          || Foswiki::Func::checkAccessPermission( 'VIEW',
            Foswiki::Func::getWikiName(),
            $text, $topic, $web );
        my $tacts =
          Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $web, $topic,
            $text );
        $tacts = $tacts->search($attrs);
        $actions->concat($tacts);
    }

    return $actions;
}

# PUBLIC STATIC get all actions in all webs that
# match the search in $attrs
sub allActionsInWebs {
    my ( $theweb, $attrs, $internal ) = @_;
    $internal = 0 unless defined($internal);
    my $filter = $attrs->{web} || $theweb;
    my $choice = 'user';

    # Exclude webs flagged as NOSEARCHALL
    $choice .= ',public' if $filter ne $theweb;
    my @webs = grep { /^$filter$/ } Foswiki::Func::getListOfWebs($choice);
    my $actions = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();

    foreach my $web (@webs) {
        my $subacts = allActionsInWeb( $web, $attrs, $internal );
        $actions->concat($subacts);
    }
    return $actions;
}

# Find the action in the action set with the given uid,
# splitting the rest of the set into before the action,
# and after the action.
sub splitOnAction {
    my ( $this, $uid ) = @_;

    if ( $uid =~ m/^AcTion(\d+)$/o ) {
        $uid = $1;
    }

    my $found = undef;
    my $pre   = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
    my $post  = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();

    foreach my $action ( @{ $this->{ACTIONS} } ) {
        if ($found) {
            $post->add($action);
        }
        elsif ( ref($action) && !defined( $action->{uid}) &&
                  $action->{ACTION_NUMBER} eq $uid ) {
            $found = $action;
        }
        elsif ( ref($action) && defined( $action->{uid}) &&
                  $action->{uid} eq $uid ) {
            $found = $action;
        }
        else {
            $pre->add($action);
        }
    }

    return ( $found, $pre, $post );
}

1;
__END__
Copyright (C) Motorola 2002 - All rights reserved
Copyright (C) 2004-2011 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
