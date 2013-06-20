# See bottom of file for license and copyright information
package Foswiki::Plugins::ActionTrackerPlugin;

use strict;
use Assert;
use Encode ();
use Error qw( :try );

use Foswiki::Func ();
use Foswiki::Plugins ();

our $VERSION = '2.4.9';
our $RELEASE = "2.4.9";
our $SHORTDESCRIPTION =
    'Adds support for action tags in topics, and automatic notification of action statuses';
our $initialised = 0;

my $doneHeader   = 0;
my $actionNumber = 0;
my $defaultFormat;

# Map default options
our $options;

sub initPlugin {

    $initialised = 0;
    $doneHeader  = 0;

    Foswiki::Func::registerRESTHandler( 'update', \&_updateRESTHandler );
    Foswiki::Func::registerRESTHandler( 'get', \&_getRESTHandler );

    Foswiki::Func::registerTagHandler( 'ACTIONSEARCH', \&_handleActionSearch,
				       'context-free' );
    use Foswiki::Contrib::JSCalendarContrib;
    if ( $@ || !$Foswiki::Contrib::JSCalendarContrib::VERSION ) {
        Foswiki::Func::writeWarning( 'JSCalendarContrib not found ' . $@ );
    }
    else {
        Foswiki::Contrib::JSCalendarContrib::addHEAD('foswiki');
    }

    # SMELL: this is not reliable as it depends on plugin order
    # if (Foswiki::Func::getContext()->{SolrPluginEnabled}) {
    if ($Foswiki::cfg{Plugins}{SolrPlugin}{Enabled}) {
	require Foswiki::Plugins::SolrPlugin;
	Foswiki::Plugins::SolrPlugin::registerIndexTopicHandler(\&_indexTopicHandler);
    }

    return 1;
}

sub commonTagsHandler {
    my ( $otext, $topic, $web, $meta ) = @_;

    return unless ( $_[0] =~ m/%ACTION.*{.*}%/o );

    return unless lazyInit( $web, $topic );

    if ($options->{AUTODISPLAY} ne '1') {
        # Just get rid of the tags in the output
        $_[0] =~ s/%ACTION.*?{.*?}%.*?%ENDACTION%//sg;
        return;
    }

    # Format actions in the topic.
    # Done this way so we get tables built up by
    # collapsing successive actions.
    my $as = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
	$web, $topic, $otext, 1 );
    my $actionGroup;
    my $text = '';

    foreach my $entry ( @{ $as->{ACTIONS} } ) {
        if ( ref($entry) ) {
            if ( !$actionGroup ) {
                $actionGroup =
		    new Foswiki::Plugins::ActionTrackerPlugin::ActionSet();
            }
            $actionGroup->add($entry);
        }
        elsif ( $entry =~ /(\S|\n\s*\n)/s ) {
            if ($actionGroup) {
                $text .=
		    $actionGroup->formatAsHTML(
			$defaultFormat, 'href', 'atpDef' );
                $actionGroup = undef;
            }
            $text .= $entry;
        }
    }
    if ($actionGroup) {
        $text .=
	    $actionGroup->formatAsHTML( $defaultFormat, 'href', 'atpDef' );
    }

    $_[0] = $text;

    # COVERAGE OFF debug only
    if ( $options->{DEBUG} ) {
        $_[0] =~
	    s/%ACTIONNOTIFICATIONS{(.*?)}%/_handleActionNotify($web, $1)/geo;
    }

    # COVERAGE ON

}

# This handler is called by the edit script just before presenting
# the edit text in the edit box.
# We use it to populate the actionform.tmpl template, which is then
# inserted in the edit.action.tmpl as the %UNENCODED_TEXT%.
# We process the %META fields from the raw text of the topic and
# insert them as hidden fields in the form, so the topic is
# fully populated. This allows us to call either 'save' or 'preview'
# to terminate the edit, as selected by the NOPREVIEW parameter.
sub beforeEditHandler {

    #my( $text, $topic, $web, $meta ) = @_;

    if ( Foswiki::Func::getSkin() =~ /\baction\b/ ) {
        return _beforeActionEdit(@_);
    }
    else {
        return _beforeNormalEdit(@_);
    }
}

sub _beforeNormalEdit {

    #my( $text, $topic, $web, $meta ) = @_;
    # Coarse method of testing if modern action syntax is used
    my $oc = scalar( $_[0] =~ m/%ACTION{.*?}%/g );
    my $cc = scalar( $_[0] =~ m/%ENDACTION%/g );

    if ( $cc < $oc ) {
        return unless lazyInit( $_[2], $_[1] );

        my $as =
	    Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $_[2], $_[1],
								    $_[0], 1 );
        $_[0] = $as->stringify();
    }
}

# Note: a simple return will effectively ignore the action tracker for
# purposes of this edit. However the skin template will still be expanded,
# so for clean error handling, make sure $_[0] is set to something.
sub _beforeActionEdit {
    my ( $text, $topic, $web, $meta ) = @_;

    return unless lazyInit( $web, $topic );

    my $query = Foswiki::Func::getCgiQuery();

    my $uid = $query->param('atp_action');
    unless (defined $uid) {
	$_[0] = "Bad URL parameters; atp_action is not set";
	return;
    }

    # actionform.tmpl is a sub-template inserted into the parent template
    # as %TEXT%. This is done so we can use the standard template mechanism
    # without screwing up the content of the subtemplate.
    my $tmpl =
	Foswiki::Func::readTemplate( 'actionform', Foswiki::Func::getSkin() );

    # Here we want to show the current time in same time format as the user
    # sees elsewhere in his browser on Foswiki.
    my $date =
	Foswiki::Func::formatTime( time(), undef,
				   $Foswiki::cfg{DisplayTimeValues} );

    die unless ($date);

    $tmpl =~ s/%DATE%/$date/g;
    my $user = Foswiki::Func::getWikiUserName();
    $tmpl =~ s/%WIKIUSERNAME%/$user/go;
    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    $tmpl = Foswiki::Func::renderText( $tmpl, $web );

    # The 'command' parameter is used to signal to the afterEditHandler and
    # the beforeSaveHandler that they have to handle the fields of the
    # edit differently
    my $fields = CGI::hidden( -name => 'closeactioneditor', -value => 1 );
    $fields .= CGI::hidden( -name => 'cmd', -value => "" );

    # write in hidden fields
    if ($meta) {
        $meta->forEachSelectedValue( qr/FIELD/, undef, \&_hiddenMeta,
				     { text => \$fields } );
    }

    # Find the action.
    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $web, $topic,
								$text, 1 );

    my ( $action, $pre, $post ) = $as->splitOnAction($uid);
    # Make sure the action currently exists
    unless( $action ) {
	$_[0] = "Action does not exist - cannot edit";
	return
    };

    # Add revision info to support merging
    my $info = $meta->getRevisionInfo();
    $fields .= CGI::hidden( -name => 'originalrev',
			    -value => "$info->{version}_$info->{date}" );

    $tmpl =~ s/%UID%/$uid/go;

    my $submitCmd     = "preview";
    my $submitCmdName = "Preview";
    my $submitCmdOpt  = "";

    if ( $options->{NOPREVIEW} ) {
        $submitCmd     = "save";
        $submitCmdName = "Save";
        $submitCmdOpt  = "?unlock=on";
    }

    $tmpl =~ s/%SUBMITCMDNAME%/$submitCmdName/go;
    $tmpl =~ s/%SUBMITCMDOPT%/$submitCmdOpt/go;
    $tmpl =~ s/%SUBMITCOMMAND%/$submitCmd/go;

    my $fmt = new Foswiki::Plugins::ActionTrackerPlugin::Format(
        $options->{EDITHEADER},
        $options->{EDITFORMAT},
        $options->{EDITORIENT},
        "", ""
	);
    my $editable = $action->formatForEdit($fmt);
    $tmpl =~ s/%EDITFIELDS%/$editable/o;

    $tmpl =~ s/%EBH%/$options->{EDITBOXHEIGHT}/go;
    $tmpl =~ s/%EBW%/$options->{EDITBOXWIDTH}/go;

    $text = $action->{text};

    # Process the text so it's nice to edit. This gets undone in Action.pm
    # when the action is saved.
    $text =~ s/^\t/   /gos;
    unless (Foswiki::Func::getPreferencesValue('ACTIONTRACKERPLUGIN_WYSIWYG')) {
        $text =~ s/<br( \/)?>/\n/gios;
        $text =~ s/<p( \/)?>/\n\n/gios;
    }

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%HIDDENFIELDS%/$fields/go;

    $_[0] = $tmpl;
}

sub _hiddenMeta {
    my ( $value, $options ) = @_;

    my $name = $options->{_key};
    ${ $options->{text} } .= CGI::hidden( -name => $name, -value => $value );
    return $value;
}

# This handler is called by the preview script just before
# presenting the text.
# The skin name is passed over from the original invocation of
# edit so if the skin is "action" we know we have been editing
# an action and have to recombine fields to create the
# actual text.
# Metadata is handled by the preview script itself.
sub afterEditHandler {
    my ( $text, $topic, $web ) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    return unless ( $query->param('closeactioneditor') );

    return unless lazyInit( $web, $topic );

    my ( $ancestorRev, $ancestorDate ) = (0, 0);
    my $origin = $query->param('originalrev');
    ASSERT(defined($origin)) if DEBUG;

    if ($origin =~ /^(\d+)_(\d+)$/) {
	( $ancestorRev, $ancestorDate ) = ( $1, $2 );
    }

    # Get the most recently saved rev
    (my $meta, $text) = Foswiki::Func::readTopic($web, $topic);
    my $info = $meta->getRevisionInfo();
    my $mustMerge = ($ancestorRev ne $info->{version}
		     || $ancestorDate && $info->{date}
		     && $ancestorDate ne $info->{date});

    my $latest_as = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
	$web, $topic, $text, 1);

    my $uid = $query->param("uid");
    ASSERT(defined($uid)) if DEBUG;

    my $latest_act = $latest_as->search(
	new Foswiki::Attrs('uid="' . $uid . '"'))->first;

    my $new_act =
	Foswiki::Plugins::ActionTrackerPlugin::Action::createFromQuery(
	    $_[2], $_[1], $latest_act->{ACTION_NUMBER}, $query );

    unless (UNIVERSAL::isa($latest_act, 'Foswiki::Plugins::ActionTrackerPlugin::Action')) {
	# If the edited action was not found in the latest rev, then force it in (it may
	# have been removed in another parallel edit)
	$latest_act = $new_act;
	$latest_as->add($new_act);
    }

    # MODAC: delete closer info when reopening
    if ($latest_act->{state} eq 'closed' && $new_act->{state} ne 'closed') {
	$new_act->{closer} = '';
	$new_act->{closed} = '';
    }

    # See if we can get a common ancestor for merging
    my $old_act;
    if ($mustMerge) {

	# If we have to merge, we need the ancestor root of the action to
	# do a three-way merge.
	# If the previous revision was generated by a reprev,
	# then the original is lost and we can't 3-way merge
	unless ($info->{reprev} && $info->{version}
	    && $info->{reprev} == $info->{version} ) {

	    my ($ances_meta, $ances_text) = Foswiki::Func::readTopic($web, $topic, $ancestorRev);
	    my $ances = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load(
		$web, $topic, $ances_text, $ancestorRev);
	    $old_act = $ances->search(
		new Foswiki::Attrs('uid="' . $uid . '"'))->first;
	}
    }

    my $old_state = $latest_act->{state} || ''; # ignoring $old_act, that mail was send already
    my $old_owner = $latest_act->{who} || '';

    $latest_act->updateFromCopy($new_act, $mustMerge, $info->{version}, $ancestorRev, $old_act);
    $latest_act->populateMissingFields();
    $text = $latest_as->stringify();

    # take the opportunity to fill in the missing fields in actions
    _addMissingAttributes( $text, $_[1], $_[2] );

    # send notification
    # note: notification for creation of new actions is handled in
    # Foswiki::Plugins::ActionTrackerPlugin::Action::populateMissingFields()
    if ( $latest_act->{state} ne $old_state ) {
        $latest_act->notify( $latest_act->{state} );
    } elsif ( $latest_act->{who} ne $old_owner ) {
        $latest_act->notify( 'reassignmentwho' );
    }

    $_[0] = $text;
}

# Process the actions and add UIDs and other missing attributes
sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    return unless $text;

    return unless lazyInit( $web, $topic );

    my $query = Foswiki::Func::getCgiQuery();
    return unless ($query);

    if ( $query->param('closeactioneditor') ) {

        # this is a save from the action editor. Text will just be the text of the action - we
	# must recover the rest from the topic on disc.

        # Strip pre and post metadata from the text
        my $premeta  = "";
        my $postmeta = "";
        my $inpost   = 0;
        my $text     = "";
        foreach my $line ( split( /\r?\n/, $_[0] ) ) {
            if ( $line =~ /^%META:[^{]+{[^}]*}%/ ) {
                if ($inpost) {
                    $postmeta .= "$line\n";
                }
                else {
                    $premeta .= "$line\n";
                }
            }
            else {
                $text .= "$line\n";
                $inpost = 1;
            }
        }

        # compose the text
        afterEditHandler( $text, $topic, $web );

        # reattach the metadata
        $text .= "\n" unless $text =~ /\n$/s;
        $postmeta = "\n$postmeta" if $postmeta;
        $_[0] = $premeta . $text . $postmeta;
    }
    else {

        # take the opportunity to fill in the missing fields in actions
        _addMissingAttributes( $_[0], $topic, $web );
    }
}

# PRIVATE Add missing attributes to all actions that don't have them
sub _addMissingAttributes {

    #my ( $text, $topic, $web ) = @_;
    my $text = "";
    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an            = 0;
    my %seenUID;

    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $_[2], $_[1],
								$_[0], 1 );

    foreach my $action ( @{ $as->{ACTIONS} } ) {
        next unless ref($action);
        $action->populateMissingFields();
        if ( $seenUID{ $action->{uid} } ) {

            # This can happen if there has been a careless
            # cut and paste. In this case, the first instance
            # of the action gets the old UID. This may banjax
            # change notification, but it's better than the
            # alternative!
            $action->{uid} = $action->getNewUID();
        }
        $seenUID{ $action->{uid} } = 1;
    }
    $_[0] = $as->stringify();
}

# =========================
# Perform filtered search for all actions
sub _handleActionSearch {
    my ( $session, $attrs, $topic, $web ) = @_;

    return unless lazyInit( $web, $topic );

    # use default format unless overridden
    my $fmt;
    my $fmts    = $attrs->remove('format');
    my $plain   = Foswiki::Func::isTrue($attrs->remove('nohtml'));
    my $hdrs    = $attrs->remove('header');
    my $foot    = $attrs->remove('footer');
    my $sep     = $attrs->remove('separator');
    my $orient  = $attrs->remove('orient');
    my $sort    = $attrs->remove('sort');

    # meyer@modell-aachen.de:
    # Kompatibilität zu JQTableSorterPlugin
    my $jqse = $Foswiki::cfg{Plugins}{JQTableSorterPlugin}{Enabled};
    my $jqsortable = $attrs->remove('jqsortable');
    my $jqsortopts = undef;
    if ( $jqse eq 1 && $jqsortable eq 1 ) {
        $jqsortopts = $attrs->remove('jqsortopts');
    }

    my $reverse = $attrs->remove('reverse');
    if ( defined($fmts) || defined($hdrs) || defined($orient) ) {
        $fmts   = $defaultFormat->getFields()      unless ( defined($fmts) );
        $hdrs   = $defaultFormat->getHeaders()     unless ( defined($hdrs) );
        $orient = $defaultFormat->getOrientation() unless ( defined($orient) );
        $fmt = new Foswiki::Plugins::ActionTrackerPlugin::Format(
	    $hdrs, $fmts, $orient, $fmts, '' );
    }
    else {
        $fmt = $defaultFormat;
    }

    my $actions =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs(
	    $web, $attrs, 0 );

    # meyer@modell-aachen.de:
    # Kompatibilität zu JQTableSorterPlugin
    # $actions->sort( $sort, $reverse );
    $actions->sort( $sort, $reverse ) unless $jqsortable;
    my $result;
    if ($plain) {
	   $result = $actions->formatAsString( $fmt );
    } else {

    # meyer@modell-aachen.de:
    # Kompatibilität zu JQTableSorterPlugin
        my $cssClasses = 'atpSearch' . ($jqsortable eq 1 ? ' tablesorter' : '');
        $cssClasses .= " {$jqsortopts}" if $jqsortopts;
	    $result = $actions->formatAsHTML( $fmt, 'href', $cssClasses );
    }
    return $result;
}

# Lazy initialize of plugin 'cause of performance
sub lazyInit {
    my ( $web, $topic ) = @_;

    return 1 if $initialised;

    Foswiki::Plugins::JQueryPlugin::registerPlugin(
	'ActionTracker',
	'Foswiki::Plugins::ActionTrackerPlugin::JQuery');
    unless( Foswiki::Plugins::JQueryPlugin::createPlugin(
		'ActionTracker', $Foswiki::Plugins::SESSION )) {
	die 'Failed to register JQuery plugin';
    }

    require Foswiki::Attrs;
    require Foswiki::Plugins::ActionTrackerPlugin::Options;
    require Foswiki::Plugins::ActionTrackerPlugin::Action;
    require Foswiki::Plugins::ActionTrackerPlugin::ActionSet;
    require Foswiki::Plugins::ActionTrackerPlugin::Format;

    $options = Foswiki::Plugins::ActionTrackerPlugin::Options::load();

    # Add the ATP CSS (conditionally included from $options, which is why
    # it's not done in the JQuery plugin decl)
    Foswiki::Func::addToZone("head", "JQUERYPLUGIN::ActionTracker::CSS", <<"HERE");
<link rel='stylesheet' href='$Foswiki::Plugins::ActionTrackerPlugin::options->{CSS}' type='text/css' media='all' />
HERE

    $defaultFormat = new Foswiki::Plugins::ActionTrackerPlugin::Format(
        $options->{TABLEHEADER}, $options->{TABLEFORMAT},
        $options->{TABLEORIENT}, $options->{TEXTFORMAT},
        $options->{NOTIFYCHANGES}
	);

    if ( $options->{EXTRAS} ) {
        my $e = Foswiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
            $options->{EXTRAS} );

        # COVERAGE OFF safety net
        if ( defined($e) ) {
            Foswiki::Func::writeWarning(
                "- Foswiki::Plugins::ActionTrackerPlugin ERROR $e");
        }

        # COVERAGE ON
    }

    $initialised = 1;

    return 1;
}

# PRIVATE return formatted actions that have changed in all webs
# Debugging only
# COVERAGE OFF debug only
sub _handleActionNotify {
    my ( $web, $expr ) = @_;

    eval 'require Foswiki::Plugins::ActionTrackerPlugin::ActionNotify';
    if ($@) {
        Foswiki::Func::writeWarning("ATP: $@");
        return;
    }

    my $text =
	Foswiki::Plugins::ActionTrackerPlugin::ActionNotify::doNotifications(
	    $web, $expr, 1 );

    $text =~ s/<html>/<\/pre>/gios;
    $text =~ s/<\/html>/<pre>/gios;
    $text =~ s/<\/?body>//gios;
    return "<!-- from an --> <pre>$text</pre> <!-- end from an -->";
}

# COVERAGE ON

sub _indexTopicHandler {
    my ($indexer, $doc, $web, $topic, $meta, $text) = @_;
    Foswiki::Func::pushTopicContext( $web, $topic );
    my $initResult = lazyInit( $web, $topic );
    Foswiki::Func::popTopicContext( $web, $topic );
    return unless defined $initResult;

    my $actionset = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load($web, $topic, $meta->text);

    for my $action (@{ $actionset->{ACTIONS} }) {
	my $createDate = Foswiki::Func::formatTime($action->{created}, 'iso', 'gmtime');
	my $dueDate = $action->{due} ? Foswiki::Func::formatTime($action->{due}, 'iso', 'gmtime') : undef;
	my $closedDate = $action->{closed} ? Foswiki::Func::formatTime($action->{closed}, 'iso', 'gmtime') : undef;
	my $webtopic = "$web.$topic";
	$webtopic =~ s/\//./g;
	my $url = Foswiki::Func::getScriptUrl($web, $topic, 'view', '#'=>$action->{uid});
	my $id = $webtopic.':action'.$action->{uid};
	my $title = $action->{task} || _unicodeSubstr($action->{text}, 0, 20) ."...";

	my @notify = split(/[,\s]+/, $action->{notify} || '');

	my $collection = $Foswiki::cfg{SolrPlugin}{DefaultCollection} || "wiki";
	my $language = Foswiki::Func::getPreferencesValue('CONTENT_LANGUAGE') || "en"; # SMELL: standardize

	# reindex this comment
	my $aDoc = $indexer->newDocument();
	$aDoc->add_fields(
	  'id' => $id,
	  'collection' => $collection,
	  'language' => $language,
	  'type' => 'action',
	  'web' => $web,
	  'topic' => $topic,
	  'webtopic' => $webtopic,
	  'url' => $url,
	  'author' => $action->{creator},
	  'contributor' => $action->{creator},
	  'date' => $createDate,
	  'createdate' => $createDate,
	  'title' => $title,
	  'text' => $action->{text},
	  'state' => $action->{state},
	  'container_id' => $web.'.'.$topic,
	  'container_url' => Foswiki::Func::getViewUrl($web, $topic),
#	  'container_title' => $indexer->getTopicTitle($web, $topic, $meta),
	);
	$doc->add_fields('catchall' => $title);
	$doc->add_fields('catchall' => $action->{text});

	$aDoc->add_fields('action_due_dt' => $dueDate) if defined $dueDate;
	$aDoc->add_fields('action_closed_dt' => $closedDate) if defined $closedDate;
	for my $n (@notify) {
	    $aDoc->add_fields('action_notify_lst' => $n);
	}
	for my $w (split(/[\s,]+/, $action->{who} || '')) {
	    $aDoc->add_fields('action_who_lst' => $w);
	}
	# auto-generate custom fields
	for my $key (keys %$action) {
	    next if ref($action->{$key}) || $key eq 'ACTION_NUMBER';
	    $aDoc->add_fields("action_${key}_s", $action->{$key});
	}
	# auto-generate custom fields
	for my $key (keys %{$action->{unloaded_fields}}) {
	    $aDoc->add_fields("action_${key}_s", $action->{unloaded_fields}{$key});
	}

	# ACL
	$aDoc->add_fields($indexer->getAclFields($web, $topic, $meta, $text));

	# add the document to the index
	try {
	  $indexer->add($aDoc);
	  $indexer->commit();
	} catch Error::Simple with {
	  my $e = shift;
	  $indexer->log("ERROR: ".$e->{-text});
	};
    }
}

sub _unicodeSubstr {
    require Encode;
    my $charset = $Foswiki::cfg{Site}{CharSet};
    return Encode::encode($charset, substr(Encode::decode($charset, $_[0]), $_[1], $_[2]));
}

# Text that is taken from a web page and added to the parameters of an XHR
# by JavaScript is UTF-8 encoded. This is because UTF-8 is the default encoding
# for XML, which XHR was designed to transport. For usefulness in Javascript
# the response to an XHR should also be UTF-8 encoded.
# This function generates such a response.
sub returnRESTResult {
    my ( $response, $status, $text ) = @_;
    ASSERT( $text !~ /[^\x00-\xff]/,
        "only octets expected in input to returnRESTResult" )
      if DEBUG;

    if ( $Foswiki::cfg{Site}{CharSet} !~ /^utf-?8$/i ) {
        $text = Encode::decode( $Foswiki::cfg{Site}{CharSet}, $text, Encode::FB_HTMLCREF );
        $text = Encode::encode_utf8($text);
    }

    # Foswiki 1.0 introduces the Foswiki::Response object, which handles all
    # responses.
    if ( UNIVERSAL::isa( $response, 'Foswiki::Response' ) ) {
        $response->header(
            -status  => $status,
            -type    => 'text/plain',
            -charset => 'UTF-8'
        );
        $response->print($text);
    }
    else {    # Pre-Foswiki-1.0.
              # Turn off AUTOFLUSH
              # See http://perl.apache.org/docs/2.0/user/coding/coding.html
        local $| = 0;
        my $query = Foswiki::Func::getCgiQuery();
        if ( defined($query) ) {
            my $len;
            { use bytes; $len = length($text); };
            print $query->header(
                -status         => $status,
                -type           => 'text/plain',
                -charset        => 'UTF-8',
                -Content_length => $len
            );
            print $text;
        }
    }
    print STDERR $text if ( $status >= 400 );
    return;
}


sub _updateRESTHandler {
    my ($session, $plugin, $verb, $response) = @_;
    my $query   = Foswiki::Func::getCgiQuery();
    if ($query->param('atpcancel')) {
	my $topic = $query->param('topic');
	my $web;
	( $web, $topic ) =
	    Foswiki::Func::normalizeWebTopicName( undef, $topic );
	try {
	    my $topicObject = Foswiki::Meta->new($session, $web, $topic);
	    $topicObject->clearLease();
	}
	catch Error::Simple with {
	    my $e = shift;
	    return returnRESTResult( $response, 500, $e->{-text} );
	};
	return returnRESTResult( $response, 200, '' );
    }
    try {
        my $topic = $query->param('topic');
        my $web;
        ( $web, $topic ) =
	    Foswiki::Func::normalizeWebTopicName( undef, $topic );
        lazyInit( $web, $topic );
        _updateSingleAction( $web, $topic, $query->param('uid'),
			     $query->param('field') => $query->param('value') );
	returnRESTResult( $response, 200, '' );
    }
    catch Error::Simple with {
        my $e = shift;
	returnRESTResult( $response, 500, $e->{-text} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
	returnRESTResult( $response, 500, $e->stringify() );
    };
    return undef;
}

sub _updateSingleAction {
    my ( $web, $topic, $uid, %changes ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an            = 0;
    my %seenUID;

    my $as =
	Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load( $web, $topic,
								$text, 1 );

    foreach my $action ( @{ $as->{ACTIONS} } ) {
        if ( ref($action) ) {
            if ( $action->{uid} == $uid ) {
                foreach my $key ( keys %changes ) {
                    $action->{$key} = $changes{$key};
                }
            }
        }
    }
    Foswiki::Func::saveTopic( $web, $topic, $meta, $as->stringify(),
			      { comment => 'atp save' } );
}

sub _getRESTHandler {
    my ($session, $plugin, $verb, $response) = @_;
    my $query = Foswiki::Func::getCgiQuery();
    my $topic = $query->param('topic');
    $query->delete('topic');
    my $web;
    ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $topic);
    try {
	lazyInit($web, $topic);
	my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
	my $as = Foswiki::Plugins::ActionTrackerPlugin::ActionSet::load($web, $topic, $text);
	my $query = { map { ($_, $query->param($_)) } $query->param };
	my $action = $as->search($query)->first;
	if (!defined $action) {
		return returnRESTResult($response, 404, 'action not found');
	}
	returnRESTResult($response, 200, encode_json({ %$action }));
    }
    catch Error::Simple with {
        my $e = shift;
	returnRESTResult( $response, 500, $e->{-text} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
	returnRESTResult( $response, 500, $e->stringify() );
    };
    return undef;
}

1;
__END__

Copyright (C) 2002-2003 Motorola UK Ltd - All rights reserved
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
