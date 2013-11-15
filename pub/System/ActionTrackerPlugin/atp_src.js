(function($) { 
    var restUpdate = function() {
	var input = $(this);
	var form = input.closest("form");
	// Transfer user selected value to "value" field
	if (input.hasClass("userval"))
	    form[0].value.value = input.val();
	if (typeof(StrikeOne) != 'undefined')
	    StrikeOne.submit(form);
	$.ajax({
	    url: form.attr("action"),
	    type: "post",
	    data: form.serialize(),
	    //dataType: "json",
	    success: function(d, t, r) {
		//console.debug(t);
		if (input.attr("tagName") == "SELECT") {
		    input.attr("class", input.attr("class").replace(/\s*\bvalue_\S+\b/, ''));
		    input.addClass("value_" + input.val());
		}
	    },
	    error: function(r, t, e) {
		alert(t);
	    }
	});
    };

    $("select.atp_update").livequery(function() { $(this).change(restUpdate); });
    $("input.atp_update").livequery(function() { $(this).click(restUpdate); });

    var canCloseDialog = false;
    $('a.atp_edit').livequery(function() {
	$(this).click(function(event) {
	    var dlgHref = this.href;
	    var meta = $(this).metadata();
	    var pref = foswiki.getPreference;
	    var div = $("#atp_editor");
	    if (!div.length) {
		div = $("<div id='atp_editor' title='Edit action'></div>");
		$("body").append(div);
		div.dialog({autoOpen: false, width: 600, beforeClose: function() {
		    if (canCloseDialog) return true;
		    $.blockUI();
		    $.ajax({
			type: 'POST',
			url: pref('SCRIPTURLPATH')+'/rest'+pref('SCRIPTSUFFIX')+'/ActionTrackerPlugin/update',
			data: {
			    atpcancel: 1,
			    topic: meta.web+'.'+meta.topic
			},
			success: function() { $.unblockUI(); div.dialog('close'); },
			error: function() {
			    alert('Failed clearing your lease for this action. Other users may not be able to edit the action\'s topic for some time. You can edit the topic and then cancel to fix this.');
			    $.unblockUI(); div.dialog('close');
			}
		    });
		    canCloseDialog = true;
		    return true;
		} });
	    }
	    div.load(this.href,
		     function(done, status) {
			 var m = /<!-- ATP_CONFLICT ~(.*?)~(.*?)~(.*?)~(.*?)~ -->/.exec(done, "s");
			 if (m) {
			     // Messages are defined in oopsleaseconflict.action.tmpl
			     var message= /<!-- ATP_CONFLICT_MESSAGE ~(.*?)~(.*?)~(.*?)~(.*?)~(.*?)~(.*?)~ -->/.exec(done, "s");
			     if (message === null){
				 message=[
				      'Could not access ' + m[1] + ', the topic containing this action',
				      m[2] + ' may still be editing the topic, but their lease expired ' + m[3] + ' ago.',
				      m[2] + 'has been editing the topic for ' + m[3] + 'and their lease is still active for another ' + m[4],
				      'To clear the lease, try editing ' + m[1] + ' with the standard text editor.',
				      'Error when I tried to edit the action',
				      'Sorry, validation failed, possibly because someone else is already editing the action. Pleas try again in a few minutes.'
				 ];
			     }
			     var ohno = message[1]; //Could not access...containing the action.
			     if (m[4] == "") {
				 ohno += message[2]; //...may still be editing the topic....ago.
			     } else {
				 ohno += message[3]; //...has been editing the topic...
			     }
			     ohno += message[4]; //To clear the lease...
			     div.html(ohno);
			     div.dialog("open");
			 } else if (status == "error") {
			     alert(message[5]); //Error when I tried...
			 } else {
			     div.dialog("open");
			     canCloseDialog = false;
			 }
		     });
	    return false;
	});
    });

    $('#atp_editor input[type="submit"]').livequery(function() {
	$(this).click(function() {
	    canCloseDialog = true;
	    $("#atp_editor").dialog("close");
	    return true;
	});
    });

    $('#atp_editor #atpCancel').livequery(function() {
	$(this).click(function() {
	    $('#atp_editor').dialog('close');
	    return true;
	});
    });

    $("#atp_editor form[name='loginform']").livequery(function() {
	$(this).submit(function() {
	    var form = $(this);
	    $.ajax({
		url: form.attr("action"),
		data: form.serialize(),
		success: function(d, t, r) {
		    // Dialog will have been closed by the submit. That's
		    // OK, as we want to relayout anyway.
		    $("#atp_editor").html(d).dialog("open");
		},
		error: function(r, t, e) {
		    // IE fails validation of the login
		    alert(message[6]); // Sorry, validation failed...
		}
	    });
	    return false;
	});
    });

    /* calendar for due date */
    $('#atp_editor input[name="calendar"]').livequery(function() {
	var cal = $(this);
	$(this).click(function() {
	    return showCalendar(cal.prev().attr('id'), '%d %b %Y');
	});
    });
})(jQuery); 
