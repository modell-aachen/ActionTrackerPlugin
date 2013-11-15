package ActionTrackerPluginTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki::Plugins::ActionTrackerPlugin;
use Foswiki::Plugins::ActionTrackerPlugin::Action;
use Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
use Foswiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $twiki;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # Need this to get the actionnotify template
    $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
    Foswiki::Func::getContext()->{ActionTrackerPluginEnabled} = 1;
    foreach my $lib (@INC) {
        my $d = "$lib/../templates";
        if ( -e "$d/actionnotify.tmpl" ) {
            $Foswiki::cfg{TemplateDir} = $d;
            last;
        }
    }

    Foswiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "Topic1" );
    $meta->putKeyed( 'FIELD',
        { name => 'Who', title => 'Leela', value => 'Turanaga' } );
    Foswiki::Func::saveTopic(
        $this->{test_web}, "Topic1", $meta, "
%ACTION{who=$this->{users_web}.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_late"
    );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "Topic2", undef, "
%ACTION{who=Fred,due=\"2 Jan 02\",open}% Test1: Fred_open_ontime"
    );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "WebNotify", undef, "
   * $this->{users_web}.Fred - fred\@sesame.street.com
"
    );

    Foswiki::Func::saveTopic(
        $this->{test_web}, "WebPreferences", undef, "
   * Set ACTIONTRACKERPLUGIN_HEADERCOL = green
   * Set ACTIONTRACKERPLUGIN_EXTRAS = |plaintiffs,names,16|decision,text,16|sentencing,date|sentence,select,\"life\",\"5 years\",\"community service\"|
"
    );

    Foswiki::Func::saveTopic(
        $this->{users_web}, "Topic2", undef, "
%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{who=$this->{users_web}.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% Main2: Joe_open_ontime
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%
"
    );

    Foswiki::Func::saveTopic(
        $this->{users_web}, "WebNotify", undef, "
   * $this->{users_web}.Sam - sam\@sesame.street.com
"
    );
    Foswiki::Func::saveTopic(
        $this->{users_web}, "Joe", undef, "
   * Email: joe\@sesame.street.com
"
    );
    Foswiki::Func::saveTopic(
        $this->{users_web}, "TheWholeBunch", undef, "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * $this->{users_web}.GungaDin - gunga-din\@war_lords-home.ind
"
    );
    Foswiki::Plugins::ActionTrackerPlugin::initPlugin( "Topic",
        $this->{test_web}, "User", "Blah" );
}

sub test_ActionSearchFn {
    my $this = shift;
    my $chosen =
      Foswiki::Plugins::ActionTrackerPlugin::_handleActionSearch( $twiki,
        new Foswiki::Attrs("web=\".*\""),
        $this->{users_web}, $this->{test_topic} );
    $this->assert_matches( qr/Test0:/, $chosen );
    $this->assert_matches( qr/Test1:/, $chosen );
    $this->assert_matches( qr/Main0:/, $chosen );
    $this->assert_matches( qr/Main1:/, $chosen );
    $this->assert_matches( qr/Main2:/, $chosen );

}

sub test_ActionSearchFnSorted {
    my $this = shift;
    my $chosen =
      Foswiki::Plugins::ActionTrackerPlugin::_handleActionSearch( $twiki,
        new Foswiki::Attrs("web=\".*\" sort=\"state,who\""),
        $this->{users_web}, $this->{test_topic} );
    $this->assert_matches( qr/Test0:/, $chosen );
    $this->assert_matches( qr/Test1:/, $chosen );
    $this->assert_matches( qr/Main0:/, $chosen );
    $this->assert_matches( qr/Main1:/, $chosen );
    $this->assert_matches( qr/Main2:/, $chosen );
    $this->assert_matches( qr/Main0:.*Test1:.*Main1:.*Test0:.*Main2:/so,
        $chosen );
}

sub test_2CommonTagsHandler {
    my $this   = shift;
    my $chosen = "
Before
%ACTION{who=Zero,due=\"11 jun 1993\"}% Finagle0: Zeroth action
%ACTIONSEARCH{web=\".*\"}%
%ACTION{who=One,due=\"11 jun 1993\"}% Finagle1: Oneth action
After
";
    $Foswiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
    Foswiki::Plugins::ActionTrackerPlugin::commonTagsHandler(
        $chosen, "Finagle", $this->{users_web} );
    $chosen = Foswiki::Func::expandCommonVariables(
        $chosen, "Finagle", $this->{users_web} );
    $this->assert_matches( qr/Test0:/,    $chosen );
    $this->assert_matches( qr/Test1:/,    $chosen );
    $this->assert_matches( qr/Main0:/,    $chosen );
    $this->assert_matches( qr/Main1:/,    $chosen );
    $this->assert_matches( qr/Main2:/,    $chosen );
    $this->assert_matches( qr/Finagle0:/, $chosen );
    $this->assert_matches( qr/Finagle1:/, $chosen );
}

# Must be first test, because we check JavaScript handling here
sub test_1CommonTagsHandler {
    my $this = shift;
    my $text = <<HERE;
%ACTION{uid=\"UidOnFirst\" who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
   %ACTION{who=$this->{users_web}.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=$this->{users_web}.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=$this->{users_web}.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=$this->{users_web}.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% <<EOF
This is an action with a lot of associated text to test
   * the VingPazingPoodleFactor,
   * Tony Blair is a brick.
   * Who should really be built
   * Into a very high wall.
EOF
%ACTION{who=ActorSix, due=\"11 2 03\",open}% Bad date
break the table here %ACTION{who=ActorSeven,due=01/01/02,open}% Create the mailer, %USERNAME%

   * A list
   * %ACTION{who=ActorEight,due=01/01/02}% Create the mailer
   * endofthelist

   * Another list
   * should generate %ACTION{who=ActorNine,due=01/01/02,closed}% Create the mailer
HERE

    Foswiki::Plugins::ActionTrackerPlugin::commonTagsHandler( $text, "TheTopic",
        "TheWeb" );
}

sub anchor {
    my $tag = shift;
    return "<a name=\"$tag\"></a>";
}

sub edit {
    my $tag = shift;
    my $url =
"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/TheWeb/TheTopic?skin=action&action=$tag&t={*\\d+*}";
    return
      "<a href=\"$url\" class=\"atp_edit\">edit</a>";
}

sub action {
    my ( $anch, $actor, $col, $date, $txt, $state ) = @_;

    my $text = "<tr valign=\"top\">" . anchor($anch);
    $text .= "<td> $actor </td><td";
    $text .= " bgcolor=\"$col\"" if ($col);
    $text .=
        "> $date </td><td> $txt </td><td> $state </td><td> \&nbsp; </td><td> "
      . edit($anch)
      . " </td></tr>";
    return $text;
}

sub test_BeforeEditHandler {
    my $this = shift;
    my $q    = new Unit::Request(
        {
            atp_action => "AcTion0",
            skin       => 'action',
            atp_action => '666'
        }
    );
    $this->{session}->{request} = $q;
    my $text =
'%ACTION{uid="666" who=Fred,due="2 Jan 02",open}% Test1: Fred_open_ontime';
    Foswiki::Plugins::ActionTrackerPlugin::beforeEditHandler( $text, "Topic2",
        $this->{users_web}, Foswiki::Meta->new($this->{session}, $this->{users_web}, "Topic2") );
    $text = $this->assert_html_matches(
"<input type=\"text\" name=\"who\" value=\"$this->{users_web}\.Fred\" size=\"35\"/>",
        $text
    );
}

sub testAfterEditHandler {
    my $this = shift;
    my $q    = new Unit::Request(
        {
            closeactioneditor => 1,
	    uid               => '1',
	    originalrev       => '0',
            who               => "AlexanderPope",
            due               => "3 may 2009",
            state             => "open",
	    text => "Chickens and eggs"
        }
    );
    Foswiki::Func::saveTopic($this->{test_web}, "EditTopic", undef, <<HERE);
%ACTION{uid="0" state="open"}% Sponge %ENDACTION%
%ACTION{uid="1"}% Cake %ENDACTION%
HERE
    # populate with edit fields
    $this->{session}->{request} = $q;
    my $text = '';
    Foswiki::Plugins::ActionTrackerPlugin::afterEditHandler( $text, "EditTopic", $this->{test_web} );
    $this->assert( $text =~ m/(%ACTION.*%ENDACTION%)\s*(%ACTION.*%ENDACTION%)$/s );
    my $first  = $1;
    my $second = $2;
    my $re     = qr/\s+state=\"open\"\s+/;
    $this->assert_matches( $re, $first );
    $first =~ s/$re/ /;
    $re = qr/\s+creator=\"$this->{users_web}\.WikiGuest\"\s+/o;
    $this->assert_matches( $re, $first );
    $first =~ s/$re/ /;
    $re = qr/\s+due=\"\"\s+/;
    $this->assert_matches( $re, $first );
    $first =~ s/$re/ /;
    $re = qr/\s+created=\"2002-06-03\"\s+/;
    $this->assert_matches( $re, $first );
    $first =~ s/$re/ /;
    $re = qr/\s+who=\"$this->{users_web}.WikiGuest\"\s+/;
    $this->assert_matches( $re, $first );
    $first =~ s/$re/ /;
}

sub test_BeforeSaveHandler1 {
    my $this = shift;
    my $q = new CGI( { closeactioneditor => 1, } );
    $this->{session}->{cgiQuery} = $q;
    my $text =
"%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}%
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";

    Foswiki::Plugins::ActionTrackerPlugin::beforeSaveHandler( $text, "Topic2",
        $this->{users_web} );
    my $re = qr/ state=\"open\"/;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ creator=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ created=\"2002-06-03\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ due=\"\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ who=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/^%META:TOPICINFO.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
    $re = qr/^%META:TOPICPARENT.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
    $re = qr/^%META:FORM.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//m;
}

sub test_BeforeSaveHandler2 {
    my $this = shift;
    my $q = new CGI( { closeactioneditor => 0, } );
    $this->{session}->{cgiQuery} = $q;
    my $text =
"%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}% <<EOF
A Description
EOF
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";

    Foswiki::Plugins::ActionTrackerPlugin::beforeSaveHandler( $text, "Topic2",
        $this->{users_web} );
    my $re = qr/ state=\"open\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ creator=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ created=\"2002-06-03\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ due=\"\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
    $re = qr/ who=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches( $re, $text );
    $text =~ s/$re//;
}

sub test__formfield_format {
    my $this = shift;

    my $text = <<HERE;
%ACTIONSEARCH{who="$this->{users_web}.Sam" state="open" header="|Who|" format="|\$formfield(Who)|"}%
HERE
    $Foswiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
    Foswiki::Plugins::ActionTrackerPlugin::commonTagsHandler( $text, "Finagle",
        $this->{test_web} );
    $this->assert( $text =~ /<td>Turanaga<\/td>/, $text );
}

1;
