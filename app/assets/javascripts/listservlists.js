function toggle_visibility(list_id) {
    console.log('Visibility toggle clicked.');
    var csrf = $("meta[name='csrf-token']").attr('content');
    var button = $("#"+list_id+" td a.toggle");
    if (button.html().indexOf("Visible") > -1) {
        console.log("Setting id " + list_id + " to invisible");
        var state = false;
        var label = 'Invisible';
    } else if (button.html().indexOf("Invisible") > -1) {
        var state = true;
        var label = 'Visible';
    }
    $.ajax({
        url: '/listservlists/'+list_id,
        type: 'PUT',
        data: {visible: state, authenticity_token: csrf},
        success: function() {
            button.html(label);
        }
    });
}