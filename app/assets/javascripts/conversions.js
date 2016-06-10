
function delete_conversion(id, gg_address, list_id) {
    $("div.statusdetail[data-id='"+id+"'] span.message").html('Undoing...').removeClass('message').addClass('msg_removing');
    var csrf = $("meta[name='csrf-token']").attr('content');
    console.log("Deleting Conversion "+id);
    $.ajax({
        url: "/conversions/"+id,
        type: "DELETE",
        dataType: "json",
        data: {authenticity_token: csrf},
        success: function(data) {
            console.log("Conversion "+id+" Deleted. "+data);
            $("div.statusdetail[data-id='"+id+"']").remove();
            $("#conversion_"+id).remove();
            alert("Your Listserv is back to normal.");
        },
        statusCode: {
            504: function() {
                $("div.statusdetail[data-id='"+id+"'] span.msg_removing").html('Could not Undo. Try Again or Contact Support.');
                alert("Couldn't reverse the Group creation. Contact support or try again.");
            }
        }

    })
}

function refreshStatus(conversion_id) {
    var statusdetail = $("div.statusdetail[data-id='"+conversion_id+"']");
    $.ajax({
        url: '/conversions/'+conversion_id,
        success: function(data) {
            statusdetail.children('.progressbar').children('.progressbar_color').css('width',data.percentage+'%');
            statusdetail.children('.message').html(data.message);
        }
    });
}

//
// $('#element').donetyping(callback[, timeout=1000])
// Fires callback when a user has finished typing. This is determined by the time elapsed
// since the last keystroke and timeout parameter or the blur event--whichever comes first.
//   @callback: function to be called when even triggers
//   @timeout:  (default=1000) timeout, in ms, to to wait before triggering event if not
//              caused by blur.
// Requires jQuery 1.7+
//

;(function($){
    $.fn.extend({
        donetyping: function(callback,timeout){
            timeout = timeout || 1e3; // 1 second default timeout
            var timeoutReference,
                doneTyping = function(el){
                    if (!timeoutReference) return;
                    timeoutReference = null;
                    callback.call(el);
                };
            return this.each(function(i,el){
                var $el = $(el);
                // Chrome Fix (Use keyup over keypress to detect backspace)
                // thank you @palerdot
                $el.is(':input') && $el.on('keyup keypress',function(e){
                    // This catches the backspace button in chrome, but also prevents
                    // the event from triggering too premptively. Without this line,
                    // using tab/shift+tab will make the focused element fire the callback.
                    if ([9,13].indexOf(e.keyCode) > -1) return;

                    // Check if timeout has been set. If it has, "reset" the clock and
                    // start over again.
                    if (timeoutReference) clearTimeout(timeoutReference);
                    $('#address_validity').html("<img src=\"/ajax-loader.gif\">");
                    $('#title_validity').html("<img src=\"/ajax-loader.gif\">");

                    timeoutReference = setTimeout(function(){
                        // if we made it here, our timeout has elapsed. Fire the
                        // callback
                        doneTyping(el);
                    }, timeout);
                }).on('blur',function(){
                    // If we can, fire the event since we're leaving the field
                    doneTyping(el);
                });
            });
        }
    });
})(jQuery);

$('#title').keydown(function(event) { if([9,13].indexOf(event.keyCode) == -1 ) {$('#submit').prop('disabled',true);}});
$('#address').keydown(function(event) { if([9,13].indexOf(event.keyCode) == -1 ) {$('#submit').prop('disabled',true);}});
$('#title').donetyping(function() { validate(); });
$('#address').donetyping(function() { validate(); });

function validate() {
    var csrf = $("meta[name='csrf-token']").attr('content');

    //Store the current values from the two fields (address/title)
    var address = $('#address').val();
    var title = $('#title').val();

    //Don't use these characters in the title
    var forbidden = ['=','\\','/','!',')','('];

    //This will be the message next to the two fields if all is well
    var OK = "<span class='green'>OK</span>";
    var title_validity = OK;
    var address_validity = OK;

    //Check title for forbidden characters
    for(i=0; i<forbidden.length; i++) {
        if (title.indexOf(forbidden[i])>-1) {
            title_validity = "<span class='red'>Group title cannot contain character: "+forbidden[i]+"</span>";
        }
    }

    //Prefix "nd-" is verboten.
    if(address.substring(0,3) == "nd-") {
        address_validity = "<span class='red'>Group addresses starting with \"nd-\" are not allowed.</span>";
    }
    if(! /^[a-zA-Z0-9\-]+$/.test(address)) {
        address_validity = "<span class='red'>Alphanumeric characters and hypen ( - ) only.</span>";
    }

    //If address isn't obviously wrong, check with Google to see if it's taken.
    $.ajax({
        type: 'POST',
        url: '/conversions/validate',
        dataType: 'json',
        data: {
            authenticity_token: csrf,
            address: address
        },
        success: function(data, textStatus, jqXHR) {
            if(!data.address_valid) {
                address_validity = "<span class='red'>Already Taken.</span>";
            }
        }
    }).done(function() {
        //After all checks are done, update
        $('#title_validity').html(title_validity);
        $('#address_validity').html(address_validity);
        //If all is well, enable the submit button
        if(address_validity == OK && title_validity == OK) {
            $('#submit').prop('disabled',false);
        }
    });
}