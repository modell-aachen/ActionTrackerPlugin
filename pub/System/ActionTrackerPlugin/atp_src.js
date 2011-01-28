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
		console.debug(t);
	    },
	    error: function(r, t, e) {
		alert(t);
	    }
	});
    };

    $("select.atp_update").livequery("change", restUpdate);
    $("input.atp_update").livequery("click", restUpdate);

    $('a.atp_edit').livequery("click", function(event) {
	var div = $("#atp_editor");
	if (!div.length) {
	    div = $("<div id='atp_editor' title='Edit action'></div>");
	    $("body").append(div);
	    div.dialog({autoOpen: false, width: 600});
	}
	div.load(this.href,
		 function(done) {
		     div.dialog("open");
		 });
	return false;
    });

    $('#atp_editor input[type="submit"]').livequery(function() {
	$(this).button();
	$(this).click(function() {
	    $("#atp_editor").dialog("close");
	    return true;
	});
    });
})(jQuery); 
