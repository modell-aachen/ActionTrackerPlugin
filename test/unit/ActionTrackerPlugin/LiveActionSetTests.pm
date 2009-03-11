package LiveActionSetTests;
use base qw(FoswikiFnTestCase);

use strict;

use Foswiki::Plugins::ActionTrackerPlugin::Action;
use Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
use Foswiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;
use CGI;

my $bit = time();

BEGIN {
    new Foswiki();
    $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    Foswiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jan 2002");

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "WhoCares" );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "Topic1", $meta, "
%ACTION{who=$this->{users_web}.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime",
        { forcenewrevision => 1 }
    );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "Topic2", $meta, "
%ACTION{who=A,due=\"2 Jan 02\",open}% Test_Topic2_A_open_late
", { forcenewrevision => 1 }
    );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "WebNotify", undef, "
   * $this->{users_web}.A - fred\@sesame.street.com
"
    );

    Foswiki::Func::saveTopic(
        $this->{users_web}, "Topic2", $meta, "
%ACTION{who=$this->{users_web}.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime
%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime",
        { forcenewrevision => 1 }
    );

    Foswiki::Func::saveTopic(
        $this->{users_web}, "WebNotify", $meta, "
   * $this->{users_web}.C - sam\@sesame.street.com
", { forcenewrevision => 1 }
    );
    Foswiki::Func::saveTopic(
        $this->{users_web}, "B", $meta, "
   * Email: joe\@sesame.street.com
", { forcenewrevision => 1 }
    );
    Foswiki::Func::saveTopic(
        $this->{users_web}, "E", $meta, "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * $this->{users_web}.GungaDin - gunga-din\@war_lords-home.ind
", { forcenewrevision => 1 }
    );
}

sub test_GetAllInMain {
    my $this  = shift;
    my $attrs = Foswiki::Attrs->new();
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb(
        $this->{users_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_does_not_match( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_does_not_match( qr/Test_Topic2_A_open_late/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_matches( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

sub test_GetAllInTest {
    my $this  = shift;
    my $attrs = Foswiki::Attrs->new();
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb(
        $this->{test_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_matches( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_matches( qr/Test_Topic2_A_open_late/o,   $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

sub test_GetAllInAllWebs {
    my $this = shift;
    my $attrs = Foswiki::Attrs->new( 'web=".*"', 1 );
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{users_web}, $attrs, 0 );
    $actions->sort();
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", '$text' );
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_matches( qr/Test_Topic1_C_open_ontime/o,   $chosen );
    $this->assert_matches( qr/Test_Topic2_A_open_late/o,     $chosen );
    $this->assert_matches( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_matches( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_E_open_ontime/o,   $chosen );

# Make sure they are sorted correctly
#%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");
#%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");
#%ACTION{who=$this->{users_web}.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
#%ACTION{who=$this->{users_web}.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime
#%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime

    $this->assert_matches(
qr/Main_Topic2_E_open_ontime.*Main_Topic2_A_closed_ontime.*Test_Topic2_A_open_late.*Test_Topic1_C_open_ontime.*Main_Topic2_B_open_ontime/so,
        $chosen, $chosen
    );
}

sub test_SortAllWebs {
    my $this  = shift;
    my $attrs = Foswiki::Attrs->new("web=\".*\"");
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{users_web}, $attrs, 0 );
    $actions->sort("who,state");
    my $fmt = new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "",
        '$who $state $text' );
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_matches(
qr/Test_Topic2_A_open_late.*Main_Topic2_B_open_ontime.*Main_Topic2_E_open_ontime.*Main_Topic2_A_closed_ontime.*Test_Topic1_C_open_ontime/so,
        $chosen
    );
}

sub test_AllInTestWebRE {
    my $this = shift;
    my $attrs = Foswiki::Attrs->new( 'web=".*' . $this->{test_web} . '.*"', 1 );
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{users_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_matches( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_matches( qr/Test_Topic2_A_open_late/o,   $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

sub test_AllInMainWebRE {
    my $this = shift;

    my $attrs = Foswiki::Attrs->new( 'web=".*' . $bit . 'Users"' );
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{users_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_does_not_match( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_does_not_match( qr/Test_Topic2_A_open_late/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_matches( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

sub test_AllTopicRE {
    my $this = shift;
    my $attrs = Foswiki::Attrs->new( "web=$this->{test_web} topic=\".*2\"", 1 );
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{test_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_does_not_match( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_matches( qr/Test_Topic2_A_open_late/o, $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_does_not_match( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

sub test_AllWebsTopicRE {
    my $this = shift;
    my $attrs = Foswiki::Attrs->new( "web=\".*\",topic=\".*2\"", 1 );
    my $actions =
      Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
        $this->{users_web}, $attrs, 0 );
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_does_not_match( qr/Test_Topic1_C_open_ontime/o, $chosen );
    $this->assert_matches( qr/Test_Topic2_A_open_late/o,     $chosen );
    $this->assert_matches( qr/Main_Topic2_A_closed_ontime/o, $chosen );
    $this->assert_matches( qr/Main_Topic2_B_open_ontime/o,   $chosen );
    $this->assert_matches( qr/Main_Topic2_E_open_ontime/o,   $chosen );
}

1;
