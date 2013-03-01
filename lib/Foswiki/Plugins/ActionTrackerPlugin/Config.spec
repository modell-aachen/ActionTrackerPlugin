# ---+ Extensions
# ---++ ActionTrackerPlugin
# **PERL**
# The following options provide defaults for the various ACTIONTRACKER_*
# preferences. See ActionTrackerPlugin documentation for details of what
# these preferences do.
$Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Options} = {
    CSS   => "%PUBURL%/%SYSTEMWEB%/ActionTrackerPlugin/styles.css",
    DEBUG => 0,
    DEFAULTDUE    => 99999999,
    EDITBOXHEIGHT => '%EDITBOXHEIGHT%',
    EDITBOXWIDTH  => '%EDITBOXWIDTH%',
    EDITFORMAT    => '| $who | $due | $state | $notify |',
    EDITHEADER          => '| Assigned to | Due date | State | Notify |',
    EDITORIENT          => 'rows',
    ENABLESTATESHORTCUT => '1',
    EXTRAS              => '',
    NOTIFYCHANGES       => '$who,$due,$state,$text',
    TABLEFORMAT => '| $who | $due | $text $link | $state | $notify | $edit |',
    TABLEHEADER => '| Assigned to | Due date | Description | State | Notify ||',
    TABLEORIENT => 'cols',
    TEXTFORMAT  => 'Action for $who, due $due, $state$n$text$n$link$n'
};
