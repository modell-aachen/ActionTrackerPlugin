# Tests for module Action.pm
package SimpleActionSetTests;
use base qw( FoswikiFnTestCase );

use strict;

use Foswiki::Plugins::ActionTrackerPlugin::Action;
use Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
use Foswiki::Plugins::ActionTrackerPlugin::Format;
use Foswiki::Attrs;
use Time::ParseDate;
use CGI;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

BEGIN {
    new Foswiki();
    $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
}

my ( $sup, $ss );

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    Foswiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    $this->{actions} = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
    my $action =
      new Foswiki::Plugins::ActionTrackerPlugin::Action( "Test", "Topic", 0,
        "who=A,due=1-Jan-02,open", "Test_Main_A_open_late" );
    $this->{actions}->add($action);
    $action =
      new Foswiki::Plugins::ActionTrackerPlugin::Action( "Test", "Topic", 1,
        "who=$this->{users_web}.A,due=1-Jan-02,closed",
        "Test_Main_A_closed_ontime" );
    $this->{actions}->add($action);
    $action =
      new Foswiki::Plugins::ActionTrackerPlugin::Action( "Test", "Topic", 2,
        "who=Blah.B,due=\"29 Jan 2010\",open",
        "Test_Blah_B_open_ontime" );
    $this->{actions}->add($action);
    $sup = $Foswiki::cfg{DefaultUrlHost} . $Foswiki::cfg{ScriptUrlPath};
    $ss  = $Foswiki::cfg{ScriptSuffix};
}

sub tear_down {
    my $this = shift;
    $this->{actions} = undef;
    $this->SUPER::tear_down();
}

sub testAHTable {
    my $this = shift;
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "|Web|Topic|Edit|",
        "|\$web|\$topic|\$edit|", "rows", "", "" );
    my $s;
    $s = $this->{actions}->formatAsHTML( $fmt, "href", 0, 'atp' );
    $s =~ s/\n//go;
    $s =~ s/(;t=\d+)//g;
    $s =~ s/\s+//g;
    my $t   = $1;
    my $cmp = <<HERE;
<table class="atpSearch">
 <tr>
  <th align="right">Web</th>
  <td>Test</td>
  <td>Test</td>
  <td>Test</td>
 </tr>
 <tr>
  <th align="right">Topic</th>
  <td>Topic</td>
  <td>Topic</td>
  <td>Topic</td>
 </tr>
 <tr>
  <th align="right">Edit</th>
  <td>
   <a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1">edit</a>
  </td>
  <td>
   <a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1">edit</a>
  </td>
  <td>
   <a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1">edit</a>
  </td>
 </tr>
</table>
HERE
    $cmp =~ s/\s+//g;
    $this->assert_html_equals( $cmp, $s );
    $s = $this->{actions}->formatAsHTML( $fmt, "name", 0, 'atp' );
    $s =~ s/\n//go;
    $s =~ /(;t=\d+)/;
    $t = $1;
    $this->assert_html_equals( <<HERE, $s );
<table class="atpSearch">
<tr>
<th align="right">Web</th>
<td><a name="AcTion0" />Test</td>
<td><a name="AcTion1" />Test</td>
<td><a name="AcTion2" />Test</td>
</tr>
<tr>
<th align="right">Topic</th>
<td>Topic</td>
<td>Topic</td>
<td>Topic</td></tr>
<tr>
<th align="right">Edit</th>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t">edit</a></td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t">edit</a></td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t">edit</a></td></tr></table>
HERE
    $s = $this->{actions}->formatAsHTML( $fmt, "name", 1, 'atp' );
    $s =~ s/\n//go;
    $s =~ /(;t=\d+)/;
    $t = $1;
    $this->assert_html_equals( <<HERE, $s );
<table class="atpSearch">
<tr>
<th align="right">Web</th>
<td><a name="AcTion0" />Test</td>
<td><a name="AcTion1" />Test</td>
<td><a name="AcTion2" />Test</td></tr>
<tr>
<th align="right">Topic</th>
<td>Topic</td>
<td>Topic</td>
<td>Topic</td></tr>
<tr>
<th align="right">Edit</th>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t')">edit</a></td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t')">edit</a></td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t')">edit</a></td></tr></table>
HERE
}

sub testAVTable {
    my $this = shift;
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "|Web|Topic|Edit|",
        "|\$web|\$topic|\$edit|", "cols", "", "", );
    my $s;
    $s = $this->{actions}->formatAsHTML( $fmt, "href", 0, 'atp' );
    $s =~ s/\n//go;
    $s =~ /(;t=\d+)/;
    my $t = $1;
    $this->assert_html_equals( <<HERE, $s );
<table class="atpSearch">
<tr>
<th>Web</th>
<th>Topic</th>
<th>Edit</th></tr>
<tr>
<td>Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t">edit</a></td></tr>
<tr>
<td>Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t">edit</a></td></tr>
<tr>
<td>Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t">edit</a></td></tr></table>
HERE
    $s = $this->{actions}->formatAsHTML( $fmt, "name", 0, 'atp' );
    $s =~ s/\n//go;
    $s =~ /(;t=\d+)/;
    $t = $1;
    $this->assert_html_equals( <<HERE, $s );
<table class="atpSearch">
<tr>
<th>Web</th>
<th>Topic</th>
<th>Edit</th></tr>
<tr>
<td>
<a name="AcTion0" />
Test</td>
<td>Topic</td>
<td>
<a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t">edit</a>
</td></tr>
<tr>
<td>
<a name="AcTion1" />
Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t">edit</a></td></tr>
<tr>
<td>
<a name="AcTion2" />
Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t">edit</a>
</td>
</tr>
</table>
HERE
    $s = $this->{actions}->formatAsHTML( $fmt, "name", 1, 'atp' );
    $s =~ s/\n//go;
    $s =~ /(;t=\d+)/;
    $t = $1;
    $this->assert_html_equals( <<HERE, $s );
<table class="atpSearch">
<tr>
<th>Web</th>
<th>Topic</th>
<th>Edit</th></tr>
<tr>
<td><a name="AcTion0" />Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion0;nowysiwyg=1$t')">edit</a></td></tr>
<tr>
<td><a name="AcTion1" />Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion1;nowysiwyg=1$t')">edit</a></td></tr>
<tr>
<td><a name="AcTion2" />Test</td>
<td>Topic</td>
<td><a href="$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t" onclick="return atp_editWindow('$sup/edit$ss/Test/Topic?skin=action%2cpattern;atp_action=AcTion2;nowysiwyg=1$t')">edit</a></td></tr></table>
HERE
}

sub testSearchOpen {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "state=open", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_matches( qr/Blah_B_open/, $text );
    $this->assert_matches( qr/A_open/,      $text );
    $this->assert_does_not_match( qr/closed/, $text );
}

sub testSearchClosed {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "closed", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_does_not_match( qr/open/o, $text );
}

sub testSearchWho {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "who=A", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_does_not_match( qr/B_open_ontime/o, $text );
}

sub testSearchLate {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "late", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_matches( qr/Test_Main_A_open_late/, $text );
    $this->assert_does_not_match( qr/ontime/o, $text );
}

sub testSearchLate2 {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "state=\"late\"", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_matches( qr/Test_Main_A_open_late/, $text );
    $this->assert_does_not_match( qr/ontime/o, $text );
}

sub testSearchAll {
    my $this   = shift;
    my $attrs  = new Foswiki::Attrs( "", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $text = $chosen->stringify($fmt);
    $this->assert_matches( qr/Main_A_open_late/o,     $text );
    $this->assert_matches( qr/Main_A_closed_ontime/o, $text );
    $this->assert_matches( qr/Blah_B_open_ontime/o,   $text );
}

# add more actions to the fixture
sub addMoreActions {
    my $this        = shift;
    my $moreactions = new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $action =
      new Foswiki::Plugins::ActionTrackerPlugin::Action( "Test", "Topic", 0,
        "who=C,due=\"1 Jan 02\",open",
        "C_open_late" );
    $moreactions->add($action);
    $this->{actions}->concat($moreactions);
}

# x1 so it gets executed second last
sub testx1Search {
    my $this = shift;
    $this->addMoreActions();
    my $fmt =
      new Foswiki::Plugins::ActionTrackerPlugin::Format( "", "", "", "\$text" );
    my $attrs  = new Foswiki::Attrs( "late", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my $text   = $chosen->stringify($fmt);
    $this->assert_matches( qr/A_open_late/,  $text );
    $this->assert_matches( qr/C_open_late/o, $text );
    $this->assert_does_not_match( qr/ontime/o, $text );
}

# x2 so it gets executed last
sub testx2Actionees {
    my $this = shift;
    $this->addMoreActions();
    my $attrs = new Foswiki::Attrs( "late", 1 );
    my $chosen = $this->{actions}->search($attrs);
    my %peeps;
    $chosen->getActionees( \%peeps );
    $this->assert_not_null( $peeps{"$this->{users_web}.A"} );
    $this->assert_not_null( $peeps{"$this->{users_web}.C"} );
    $this->assert_null( $peeps{"Blah.B"} );
}

1;
