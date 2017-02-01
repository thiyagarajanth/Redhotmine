
function kanban_init()
{
    $( ".kanban-pane" ).sortable({
        connectWith: ".kanban-pane",
        start: function(event,ui){
            ui.item.removeClass("acceptable");
        },
        receive: function(event,ui){
            /* check */
            result = cardIsAccepted(ui.item,ui.sender,$(this));
            if (result.success){
                ui.item.addClass("acceptable");
            }else{
                console.debug("rejected:" + result.error);
                ui.item.removeClass("acceptable");
            }
            if (!ui.item.hasClass('acceptable')){
                ui.sender.sortable("cancel");
            }else{
                if (!confirm("Are you sure? Click 'OK' will update the moving to server")){
                    ui.sender.sortable("cancel");
                    console.log(ui);
                }else{
                    var popup = $("#popupWindow");
                    var id= $(ui.item).attr('id');
                    var element = "#popupWindow";
                    var kanban_status_id=$(this).attr("state_id");
                    var issue_status_id=$(ui.item).find("#issue_card_status_id").val();
                    var project_id=$(ui.item).find("#project_id").val();
                    var kanban_pane_id=$(this).attr("id").split('_')[1];
                    popupCard(ui.sender,$(this),ui.item,popup,"drop");
                    $.ajax({
                        url: "/kanbans/kanban_issue_show", // Route to the Script Controller method
                        type: "POST",
                        dataType: "script",
                        data: { project_id:project_id,issue_id: id,issue_status_id:issue_status_id,kanban_status_id:kanban_status_id,kanban_pane_id:kanban_pane_id  }, // This goes to Controller in params hash, i.e. params[:file_name]
                        complete: function () {
                        },
                        success: function (e, xhr, settings) {
                            find_issue_status_id();
                            $('#ajax-indicator').hide();


                        },
                        error: function () {
//                            alert("Error in authentication")
                        }
                    });

                    $(popup).on('dialogclose', function(event) {
                        ui.sender.sortable("cancel");
                    });

//                   popupCard(ui.sender,$(this),ui.item,popup,"drop");
                    updatePanesWip(ui.sender,$(this));
                }
            }
        },
        remove: function(event,ui){
            ui.item.removeClass("acceptable");
        },
    });

    $(".ui-icon-triangle-1-s.ui-icon").click(function(event){
            $('html').one('click',function() {
                $('.menu-holder').hide();
            });
            $(this).parent().find('.menu-holder').menu().toggle();
            event.stopPropagation();
        }
    );

    $(".kanan-card").draggable({
        connectToSortable: '.kanban-pane',
        revert: "invalid"
    });

    $( ".kanban-card" ).addClass( "ui-helper-clearfix ui-corner-all ")
        .find( ".card-header" )
        .addClass( "ui-widget-header ui-corner-all" )
        .prepend( "<span class='ui-icon ui-icon-minusthick'></span>")
        .end()
        .find( ".card-content" );

    $( ".card-header > .ui-icon-minusthick" ).click(function() {
        $( this ).toggleClass( "ui-icon-minusthick" ).toggleClass( "ui-icon-plusthick" );
        $( this ).parents( ".kanban-card:first" ).find( ".card-content" ).toggle();
        $( this ).parents( ".kanban-card:first" ).toggleClass("card-min-height card-max-height");
    });
    $( ".kanban-pane" ).disableSelection();
    $( ".backlog-search" ).enableSelection();

    $("table").find("li[id^='li_collapse_all']").click(function(){
        $(this).find("span").toggleClass("ui-icon-minus").toggleClass("ui-icon-plus");
        $(this).find(".menu-text").text($(this).find("span").hasClass("ui-icon-minus") ? "Collapse all" : "Expand All");
        pane_id = $(this).attr("id").match(/\d+$/)[0];
        $(this).closest("table").find("#pane_"+pane_id).find(".card-header .ui-icon").trigger("click");
    });

    $("table").find("li[id^='li_check_all']").click(function(){
        $(this).find("span").toggleClass("ui-icon-check").toggleClass("ui-icon-closethick");
        $(this).find(".menu-text").text($(this).find("span").hasClass("ui-icon-check") ? "Check all" : "Uncheck all");
        pane_id = $(this).attr("id").match(/\d+$/)[0];
        $(this).closest("table").find("#pane_"+pane_id).find("#close_check_box").trigger('click');
    });

    $("table").find("li[id^='li_close']").click(function(){
        pane_id = $(this).attr("id").match(/\d+$/)[0];
        var issue_ids = [];
        cards = $(this).closest("table").find("#pane_"+pane_id).find(".kanban-card");
        for (var i = 0; i < cards.length; i++){
            if ($(cards[i]).find("#close_check_box").is(":checked")){
                issue_ids.push(cards[i].id);
            }
        }
        if (issue_ids.length){
            close_issues(issue_ids, pane_id);
        }
    });

    $("th").find("#backlog-search-icon").click(function(){
        var input = $(this).closest("table").find("#backlog-search");
        input.toggle();
        if (input.is("autofocus"))
            input.focus(0);
        else
            input.focus(1);
        input.val("");
        input.trigger("keyup");
    });

    $(".find-card").keyup(function(){
        var keywords = $.trim($(this).val());
        if (keywords === "") {keywords = "#"}
        kanban_boards = $($(this).attr("selector"));
        kanban_boards.find($(".kanban-card")).hide().filter(":contains('"+(keywords)+"')").show();
    });

    $("#backlog-search").keyup(function(){
        var keywords = $.trim($(this).val());
        var pane = $(this).closest("td");
        var stage = pane.data("stage_id");
        if (keywords === "") {keywords="#"}
        pane.find(".kanban-card")
            .hide()
            .filter(":contains('"+(keywords)+"')")
            .show();
        text = $("#wip_"+stage).text();
        text = text.split(":");
        text = "(" + pane.children(".kanban-card:visible").length + ":" + text[1];
        $("#wip_"+stage).text(text);
    }).keyup();

    //$( document ).tooltip();

//    $(".kanban-card").bind("dblclick", function(){
//        popupCard($(this).parent(".kanban-pane"),null,$(this),$("#popupWindow"),"edit")
//    });

    $(".kanban-card").bind("dblclick", function(){
        var id= $(this).attr('id');
        var element = "#popupWindow";
        var kanban_status_id=$(this).find("#kanban_state_id").val();
        var issue_status_id=$(this).find("#issue_card_status_id").val();
        var kanban_pane_id=$(this).first().parent().attr("id").split('_')[1];
        var project_id=$(this).find("#project_id").val();
        popupCard($(this).parent(".kanban-pane"),null,$(this),$(element),"edit")
       $.ajax({
            url: "/kanbans/kanban_issue_show", // Route to the Script Controller method
            type: "POST",
            dataType: "script",
            data: { project_id:project_id,issue_id: id,issue_status_id:issue_status_id,kanban_status_id:kanban_status_id,kanban_pane_id:kanban_pane_id  }, // This goes to Controller in params hash, i.e. params[:file_name]
            complete: function () {
            },
            success: function (e, xhr, settings) {
                $('#ajax-indicator').hide();

            },
            error: function () {
//                alert("Error in authentication")
            }
        });


  });


    $(document).on('click', '.kanban-card .status .issue_edit_icon', function() {
//        console.log(33333333333333)
        var id= $(this).attr('id');
        var parent = $(this).parent().parent();
        var element = "#popupWindow";
        var kanban_status_id=$(parent).find("#kanban_state_id").val();
        var issue_status_id=$(parent).find("#issue_card_status_id").val();
        var kanban_pane_id=$(parent).first().parent().attr("id").split('_')[1];
        var project_id=$(parent).find("#project_id").val();
        popupCard($(parent).parent(".kanban-pane"),null,$(this),$(element),"edit")
        $.ajax({
            url: "/kanbans/kanban_issue_show", // Route to the Script Controller method
            type: "POST",
            dataType: "script",
            data: { project_id:project_id,issue_id: id,issue_status_id:issue_status_id,kanban_status_id:kanban_status_id,kanban_pane_id:kanban_pane_id  }, // This goes to Controller in params hash, i.e. params[:file_name]
            complete: function () {
            },
            success: function (e, xhr, settings) {
                console.log("Success");
                $('#ajax-indicator').hide();
//                $(document).ready(hideOnLoad);
            },
            error: function () {
//                alert("Error in authentication")
            }
        });


    });

    $("#popupSubmit").click(function(){
        /* Ajax update card here */
        updateCard();
    });
    $(".kanban-card a").css("color","blue");
    //Ajax Call.
    getKanbanStateIssueStatus();
    getKanbanStates();
    getKanbanWorkflow();
    getUserWipAndLimit($("#my-profile").data("user").user.id);

    $(".cards-per-column").each(function(index){
        getCardsPerCol($(this));
    });

    $(".cards-per-column").change(function(){
        setCardWidth($(this));
    });

    $(".kanban-card:contains('P0')").addClass("p1-color")
    $(".kanban-card:contains('P1')").addClass("p2-color")
    $(".kanban-card:contains('P2')").addClass("p3-color")
    $(".kanban-card:contains('P3')").addClass("p4-color")
    $(".kanban-card:contains('P4')").addClass("p5-color")
    $('.find-card').trigger('keyup');
}

function find_issue_status_id()
{
    var kanban_state_id= $('form.edit_issue select#kanban_state_id').val();
    $.ajax({
        url: "/kanbans/find_issue_status_id", // Route to the Script Controller method
        type: "GET",
        dataType: "json",
        // This goes to Controller in params hash, i.e. params[:file_name]
        data: {kanban_state_id: kanban_state_id},

        success: function (data) {

            $('form.edit_issue select#issue_status_id').val(data.issue_status_id)
            $('#ajax-indicator').hide();
        }
    });


}


function getCardsPerCol(input){
    var kanban = input.parent(".kanban-board");
    var card = kanban.find(".kanban-card");
    var card_w = card.width();
    if (card){
        var pane_w = card.parent(".kanban-pane").width();
        input.val(parseInt(pane_w/card_w));
    }
}

function setCardWidth(input){
    var n = parseInt(input.val());
    var kanban = input.parent(".kanban-board");
    if (kanban){
        var pane_w = kanban.find(".kanban-pane").width();
        var card_w = parseInt((pane_w - 12)/n);
        kanban.find(".kanban-card").css("max-width","").width(card_w);
    }
}


function updateWip(wip,wip_limit,stage){
    $("wip_"+stage).html("<span class:wip-text> (" + wip + ":" +wip_limit +")");
}

/* Popup window */
function popupCard(fromPane,toPane,card,popup,event)
{
    renderPopupCard(popup,card,event,fromPane,toPane);
    var isModal = (event == "drop")? true : false;
    //var w = (event == "drop")? "auto" : "1024px";
    //var h = (event == "drop")? "auto" : "720px";
    var w = "1024px";
    popup.dialog({
        autoOpen: true,
        //modal: isModal,
        width: w,
        //height: h,
    });
}

/* Ajax call */
function updateCard(popup,card,sender,receiver){
}

function kanbanStateToIssueStatus(state_id){
    var issue_status_id = 9999;
    var t = $("#kanban-data").data("kanban_state_issue_status");
    for (var i = 0; i < t.length; i++){
        if (t[i].kanban_state_id == state_id){
            issue_status_id = t[i].issue_status_id;
            break;
        }
    }
    return issue_status_id;
}

function issueStatusToKanbanState(status_id, tracker_id){
    var kanban_state_id = 9999;
    var t = $("#kanban-data").data("kanban_state_issue_status");
    for (var i = 0; i < t.length; i++){
        if (t[i].issue_status_id  == status_id && t[i].tracker_id == tracker_id){
            kanban_state_id = t[i].kanban_state_id;
            break;
        }
    }
    return kanban_state_id;
}

function filterJournals(journals){
    prop_keys = ["priority_id", "fixed_version_id", "done_ratio", "assigned_to_id"];

    for (var i = journals.length; i > 0; i--){
        journal = journals[i-1];
        journal.journal.journal.created_on = journal.journal.journal.created_on.replace(/\-/g,"\/").replace(/Z/g," ").replace(/T/g," ") + " UTC";
        for (var j = journal.details.length; j > 0; j--){
            detail = journal.details[j-1];
            if ($.inArray(detail.journal_detail.prop_key, prop_keys) == -1){
                journal.details.splice(j-1,1);
            }
        }
        if (journal.details.length == 0 && journal.note == ""){
            journals.splice(i-1,1);
        }

    }
}

function spent_time(from,to){
    var msPerMin  = 60*1000;
    var msPerHour = 3600 * 1000;
    var msPerDay = 24*msPerHour;
    ms = new Date(to) - new Date(from);
    if (ms < msPerHour){
        str = Math.round(ms/msPerMin).toString() + "M";
    }else if (ms < msPerDay){
        str = Math.round(ms/msPerHour).toString() + "H";
    }else{
        str = Math.round(ms/msPerDay).toString() + "D";
    }
    return str;
}

function cardHint(card,card_journal, journals){
    var id = card_journal.journal_id;

    var desc = ""

    if (id == 0){
        var author = card_journal.author.name;
        desc = "Created by <strong>" + author + "</strong> at " + card_journal.from + "<br/>" + " <strong>Developer: </strong>" + card_journal.developer.name + " <strong>Verifier:</strong>" + card_journal.verifier.name + "<br/>";
    }

    for (var j in journals){
        var journal = journals[j].journal.journal;
        if (journal.id == id){
            var author = journals[j].author;
            var note = journal.notes;
            var desc = journals[j].desc;
            var at = journal.created_on;
            desc = "<strong>"+ author + "</strong> wrote:<br>" + " '" + note + "'<br/>" + "<br/>" + desc + "<br/>" + "at " + at;
        }
    }
    return desc.replace(/\n/g, "<br />");;
}


function initCardJournals(card,sender,journals){
    filterJournals(journals.issue_journals);
    card.data("journals",journals);
    var panes = sender.closest(".kanban-board").find("#kanban-panes-data").data("panes");

    var json = [];
    for (var i = panes.length; i > 0; i--){
        var p = panes[i-1].kanban_pane;
        var data = []
        var journal;

        if (journals.card_journals.length == 0 && sender.attr("id").match(/\d+$/)[0]  == p.id){
            var now = new Date();
            var from = new Date(card.find("#created_on").val()).toString();
            data.push({
                from: from,
                to: now.toString(),
                label: spent_time(from, now.toString()),
                customClass: "ganttRed",
                desc: "No journal",
            });
        }else{
            for (var j = 0; j < journals.card_journals.length; j++){
                journal = journals.card_journals[j];
                if (typeof(journal.pane_id) == "undefined" && sender.attr("id").match(/\d+$/)[0]  == p.id){
                    journal.pane_id = p.id;
                }
                if (journal.pane_id == p.id){
                    data.push({
                        from: journal.from,
                        to: journal.to,
                        label: spent_time(journal.from, journal.to),
                        customClass: "ganttGreen",
                        desc: cardHint(card,journal,journals.issue_journals),
                    });
                }
            }
        }
        json.push({name:p.name, desc:"", values:data});
    }

    return json;
}

/*TODO: take UTC into account */
function renderCardHistory(popup,card,sender,journals)
{
    var json = initCardJournals(card,sender, journals);

    var msPerHour = 3600*1000;
    var msPerDay = 24*msPerHour;
    var msPerWeek = 7*msPerDay;
    var msPerMonth = 30*msPerDay;

    var started_at = new Date(card.find("#start_date").val());
    var due_at = new Date(card.find("#due_date").val());
    var today = new Date();
    var created_at = new Date(card.find("#created_on").val());

    var total_elapsed = today - created_at;
    var scale;
    if (total_elapsed < 1*msPerDay){
        scale = "hours";
    }else if (total_elapsed <= 12*msPerMonth){
        scale = "days";
    }else{
        scale = "weeks";
    }

    $("#card_history.gantt").gantt({
        source:json,
        navigate: "scroll",
        scale: scale,
        //maxScale: scales[1],
        //minScale: scales[0],
        itemsPerPage: 10,
        onItemClick: function(data) {
            alert("Item clicked - show some details");
        },
        onAddClick: function(dt, rowId) {
            alert("Empty space clicked - add an item!");
        },
        onRender: function() {
            if (window.console && typeof console.log === "function") {
                console.log("chart rendered");
            }
        }
    });
    $(".kanban-card-history").show();
}

function status_state_change(element,card){
    value = element.val();
    id = element.attr("id");
    if (id == "kanban_state_id"){
        var el = $("#popupWindow").find("#issue_status_id");
        el.val(kanbanStateToIssueStatus(value));
    }else if (id == "issue_status_id"){
        var el = $("#popupWindow").find("#kanban_state_id");
        var tracker_id = card.find("#tracker_id").val();
        el.val(issueStatusToKanbanState(value,tracker_id));
    }
}

function updateStateSelect(card,popup){
    tracker_id = card.find("#tracker_id").val();
    $.each($("#kanban-data").data("kanban_state_issue_status"), function(index,value){
        if (value.tracker_id != tracker_id){
            popup.find("#kanban_state_id option[value='" + value.kanban_state_id + "']").remove()
        }
    });
}

function renderPopupCard(popup,card,action,sender,receiver){
    $("#popupWindow").find("#errorExplanation").text("").hide();
    $("#popupWindow").find("#kanban_state_id").bind("change", function(){
        status_state_change($(this),card);
    });
    updateStateSelect(card,popup);
    $("#popupWindow").find("#issue_status_id").bind("change", function(){
        status_state_change($(this),card);
    });
    if (action === "new"){
        popup.find("#card-form-header").html("<p>New Issue </p>").show();
    }else{
        var issue_id = card.attr("id");
        kanbanAjaxCall("get",
            "/kanban_apis/kanban_card_journals",{"issue_id":issue_id},
            function(data,result){
                if (result == 0){
                    renderCardHistory(popup,card,sender,data)
                    //console.debug(data);
                }});
        popup.find("#card_form_header").html("<a href='/issues/" + issue_id + "'>#" +  issue_id +"</a>" + ": " + card.find("#subject").val()).show();
        if (action === "edit"){
            popup.find("select#issue_status_id").val(card.find("#issue_status_id").val());
            popup.find("select#kanban_state_id").val(card.find("#kanban_state_id").val());
            var pane_id = sender.attr("id").match(/\d+$/)[0];
            popup.find("#kanban_pane_id").val(pane_id);
        }else if (action == 'drop'){
            // Change the assignee to me
            var pane_id = receiver.attr("id").match(/\d+$/)[0];
            var state_id = receiver.attr("state_id")
            var status_id = kanbanStateToIssueStatus(state_id);
            popup.find("select#issue_status_id").val(status_id);
            popup.find("select#kanban_state_id").val(state_id);
            card.find("#assignee_id").val(myUserID());
            popup.find("#kanban_pane_id").val(pane_id);
            if (hasRole("developer")){
                card.find("#developer_id").val(myUserID());
            }
            if (hasRole("validater")){
                card.find("#verifier_id").val(myUserID());
            }
        }
        var start_date = popup.find("#start_date_");
        start_date.val(card.find("#start_date").val());
        var due_date = popup.find("#due_date_");
        due_date.val(card.find("#due_date").val());
        var today = new Date();
        var m,d,y,date;
        if (start_date.val() == ""){
            m = today.getMonth() + 1;
            d = today.getDate();
            y = today.getFullYear();
            date = y + '/' + (m < 10? '0':'') + m + '/' + (d < 10 ? '0':'') + (d);
            start_date.css("required",true);
            start_date.val(date);
        }
        if (due_date.val() == ""){
            due_date.css("required",true);
            today.setDate(today.getDate()+2);
            m = today.getMonth() + 1;
            d = today.getDate();
            y = today.getFullYear();
            date = y + '/' + (m < 10? '0':'') + m + '/' + (d < 10 ? '0':'') + (d);
            due_date.val(date);
        }

        popup.find("select#assignee_id").val(card.find("#assignee_id").val());
        popup.find("select#developer_id").val(card.find("#developer_id").val());
        popup.find("select#verifier_id").val(card.find("#verifier_id").val());
        popup.find("#issue_id").val(issue_id);
        popup.find("textarea").val("").focus(1);
        popup.find("#indication").hide();
        popup.find("#version_id").val(card.find("#version_id").val());
        popup.find("#est_hours").val(card.find("#est_hours").val());

    }
}

function init_wip(kanban_id,json){
    var panes = json[0];
    var stages = json[1];
    if (typeof(panes[0]) == "undefined") return;
    //table = $("#kanban_" + panes[0].kanban_pane.kanban_id)
    var table = $("#kanban_" + kanban_id);
    for (var i=0; i<stages.length; i++){
        pane_id = panes[i].kanban_pane.id
        if (i > 0 && (stages[i].kanban_stage.id === stages[i-1].kanban_stage.id)){
            wip += $("#pane_"+pane_id).children(":visible").length;
        }else{
            wip = $("#pane_"+pane_id).children(":visible").length;
        }
        var wip_limit = panes[i].kanban_pane.wip_limit;
        table.find("#wip_"+ stages[i].kanban_stage.id).text("(" + wip + ":" +wip_limit +")");
        table.find("#wip_"+ stages[i].kanban_stage.id).data("wip",wip);
        table.find("#wip_"+ stages[i].kanban_stage.id).data("wip_limit",wip_limit);
        //store stage name in each pane's data.
        $("#pane_"+pane_id).data("stage",stages[i].kanban_stage.name);
        $("#pane_"+pane_id).data("stage_id",stages[i].kanban_stage.id);
    }
}

function updatePanesWip(sender, receiver){
    var stage_from = sender.data("stage_id");
    var stage_to   = receiver.data("stage_id");
    var table = sender.parents("table");

    if (stage_from != stage_to){
        var from_wip = table.find("#wip_"+stage_from).data("wip") - 1;
        var to_wip  = table.find("#wip_"+stage_to).data("wip") + 1;
        var from_wip_limit = table.find("#wip_"+stage_from).data("wip_limit");
        var to_wip_limit = table.find("#wip_"+stage_from).data("wip_limit");
        table.find("#wip_"+stage_from).text("(" + from_wip + ":" + from_wip_limit + ")");
        table.find("#wip_"+stage_to).text("(" + to_wip + ":" + to_wip_limit + ")");
        table.find("#wip_"+stage_from).data("wip",from_wip);
        table.find("#wip_"+stage_to).data("wip",to_wip);
        sender.data("wip",from_wip);
        receiver.data("wip",to_wip);
    }
}


function kanbanStateToStage(state_id){
    var stage_id = 9999;
    var t = $("#kanban-data").data("kanban_states").kanban_states;
    for (var i = 0; i < t.length; i++){
        if (t[i].kanban_state.id == state_id){
            stage_id = t[i].kanban_state.stage_id;
            break;
        }
    }
    return stage_id;
}

function myLoginName(){
    return $("#loggedas a").text()
}

function projectID(){
    return $("#project-profile").data("project").project.id;
}

function myUserID(){
    return $("#my-profile").data("user").user.id;
}

function myKanbanId(el){
    return el.closest(".kanban").attr("id").match(/\d+$/)[0];
}

function hasRole(role_name)
{
    var roles = myRoles();
    for (var i=0; i<roles.length;i++){
        if (roles[i].role.name.toLowerCase() == role_name.toLowerCase()){
            return true;
        }
    }
    return false;
}

function hasRoleId(role_id){

    /* "Non-Member" and "Anonymous" is open to anybody */
    if (role_id == 0 || role_id == 1){
        return true;
    }

    var roles = myRoles();
    for (var i=0; i<roles.length; i++){
        if (roles[i].role.id == role_id){
            return true;
        }
    }
    return false;
}

function myRoles()
{
    return $("#my-profile").data("roles");
}

function kanbanPaneRole(pane_id){
    return $("pane_" + pane_id).attr("role_id");
}

function isValidKanbanTransition(kanban_id,from,to){
    if (hasRole("DO")) {return true};
    var t = $("#kanban-data").data("kanban_workflow").kanban_workflow;
    for (var i = 0; i < t.length; i++){
        if (t[i].kanban_workflow.old_state_id == from && to == t[i].kanban_workflow.new_state_id && t[i].kanban_workflow.kanban_id == kanban_id){
            if (t[i].kanban_workflow.check_role){
                //Manager can perform any transition.
                return hasRoleId(t[i].kanban_workflow.role_id) || hasRole("DO");
            }
            return true;
        }
    }
    return false;
}

function isValidIssueTransition(from,to){

}

function updateMyWip(){

}

/* Input:
 *   1. Card -> user/group -> roles.
 *   2. From Pane
 *   3. To Pane
 *
 * Output:
 *   1. true or false
 *   2. error text
 *
 */
function cardIsAccepted(card,sender,receiver){
    var user_id   = card.find("#assignee_id").val();
    var status_id = card.find("#issue_status_id").val();
    var kanban_id = myKanbanId(card);
    table = sender.parents("table");

    var to_state = receiver.attr("state_id");
    var from_state = sender.attr("state_id");
    var to_stage = kanbanStateToStage(to_state);
    var from_stage = kanbanStateToStage(from_state);
    var to_wip = table.find("#wip_"+to_stage).data("wip");
    var to_wip_limit = table.find("#wip_"+to_stage).data("wip_limit");

    var pane_role = receiver.attr("role_id");

    if (to_stage === from_stage && card.find("#assignee_id").val() == myUserID()){
        return {"success":true,"error":"In the same stage"};
    }
    /*
     * 1. non-wip pane -> wip pane.
     * 2. assignee changed in wip_pane.
     */
    if ((sender.attr("check_wip") == "false" && receiver.attr("check_wip") == "true") ||
        (card.find("#assignee_id").val() != myUserID() && receiver.attr("check_wip") == "true")){
        my_wip_limit = $("#my-profile").data("user").wip_limit;
        my_wip = $("#my-profile").data("wip").length;
        if (my_wip >= my_wip_limit){
            return {"success":false,"error":"reach your wip_limit"}
        }
    }

    if (!isValidKanbanTransition(kanban_id,from_state,to_state)){
        return {"success":false,"error":"Invalid state transition"}
    }

    /* Check pane's WIPLimit */
    if (to_wip >= to_wip_limit){
        return {"success":false, "error":"Exeed wip_limit"};
    }
    return {"success":true,"error":"OK"};
}

function close_issues(ids,pane_id){
    kanbanAjaxCall("put",
        "/kanban_apis/close_issues",{"issue_ids":ids, "pane_id":pane_id},
        function(data,result){
            if (result == 0){
                for (var i = 0; i < data.closed_ids.length; i++){
                    $("table").find("#"+data.closed_ids[i].toString()).remove();
                }
            }});
}





// Sprint Create
$(document).on('click', '#new_sprints #new_sprint_submit', function() {
    $.ajax({
        url: "/adsprints/create_sprint?" + $('#new_sprints').serialize(), // Route to the Script Controller method
        type: "POST",
        dataType: "json",
        // This goes to Controller in params hash, i.e. params[:file_name]
        complete: function () {
        },
        success: function (data) {

            console.log(data.errors);
            if(data.errors) {
                $('#sprint_errors #divError').css("display", "block");
                $('#sprint_errors #divError').text(data.errors)
            }
            else
            {
                $("#sprints_sprints").prepend(data.sprintPartial);
                $("#NewsprintpopupWindow").dialog('close');
                $('#ajax-indicator').hide();

            }

        }

    });

});





function find_kanban_state_id()
{
    var issue_status_id= $('form.edit_issue select#issue_status_id').val();
    $.ajax({
        url: "/kanbans/find_kanban_state_id", // Route to the Script Controller method
        type: "GET",
        dataType: "json",
        // This goes to Controller in params hash, i.e. params[:file_name]
        data: {issue_status_id: issue_status_id},

        success: function (data) {

            $('form.edit_issue select#kanban_state_id').val(data.kanban_state_id)
            update_form()
        }
    });
}

function find_issue_status_id()
{
    var kanban_state_id= $('form.edit_issue select#kanban_state_id').val();
    $.ajax({
        url: "/kanbans/find_issue_status_id", // Route to the Script Controller method
        type: "GET",
        dataType: "json",
        // This goes to Controller in params hash, i.e. params[:file_name]
        data: {kanban_state_id: kanban_state_id},

        success: function (data) {
            console.log(data)
            $('form.edit_issue select#issue_status_id').val(data.issue_status_id)
            $('form.edit_issue input#issue_status_id').val(data.issue_status_id)

            console.log($("form.edit_issue select#issue_status_id").val())
            update_form()

        }
    });


}



function update_form(issue_id)

{
   // Sprint Create

    $.ajax({
        url: "/kanbans/update_form?" + $('form#kanban_card_form').serialize(), // Route to the Script Controller method
        type: "POST",
        dataType: "json",
        // This goes to Controller in params hash, i.e. params[:file_name]

        complete: function () {
        },
        success: function (data) {

            console.log(data.errors);
            if(data.errors) {
                $('#issue_errors #divError').css("display", "block");
                $('#issue_errors #divError').text(data.errors)
            }
            else
            {
                $("#popupWindowBody").html(data.editcardPartial)
                $('form.edit_issue select#kanban_state_id').val(data.kanban_status_id);
                $('form.edit_issue select#issue_status_id').val(data.issue_status_id);
                $('#ajax-indicator').hide();


            }

        }

    });





}

//
//function update_form(issue_id)
//
//{
//
//    // Sprint Create
//
//        $.ajax({
//            url: "/kanbans/update_form?" + $('form#kanban_card_form').serialize(), // Route to the Script Controller method
//            type: "POST",
//            dataType: "json",
//            // This goes to Controller in params hash, i.e. params[:file_name]
//
//            complete: function () {
//            },
//            success: function (data) {
//
//                console.log(data.errors);
//                if(data.errors) {
//                    $('#issue_errors #divError').css("display", "block");
//                    $('#issue_errors #divError').text(data.errors)
//                }
//                else
//                {
////                    console.log(data.editcardPartial)
//                    $("#popupWindowBody").html(data.editcardPartial)
////                    $("#popupWindow").dialog('close');
//                    console.log(7777777777777)
//                    console.log(data.kanban_status_id);
//                    console.log(data.issue_status_id)
//                   $('form.edit_issue select#kanban_state_id').val(data.kanban_status_id);
//                    $('form.edit_issue select#issue_status_id').val(data.issue_status_id);
////                    console.log(kanban_state_id)
////                    console.log(issue_status_id)
////                    find_issue_status_id();
//
//                }
//
//            }
//
//        });
//
//
//
//
//
//}

//$(document).ready()
//
//
//$( document ).ready(function() {
////    alert("yes")
//    $("#sidebar").hide();
//
//    if ( $( "#sidebar_btn_left" ).length == 0 ) {
//
//        $("#wrapper3").append( "<div id='sidebar_btn_left'></div>" )
//
//    }
//
////    $("#sidebar").hide();
//       if ($.cookie('hide_header') == 'yes'){
//
//
//           $("#main").css({
//               'margin': '0 3% 0 15px',
//               'padding': '80px 0 0 10px'
//           });
//           $("#sidebar_btn_left").css({
//               'left': '0%'
//           });
//
//           $("#sidebar_btn_left").addClass('sidebar_btn_left');
//           $(".sidebar_btn_left").removeAttr('id');
////            $('#main').toggleClass('nosidebar');
//        }
//    else{
//
//           $( "#header" ).show();
//           $("#main").css({
//               'margin': '0 30px 0 250px',
//               'padding': '80px 0 0 10px'
//           });
//           $("#sidebar_btn_left").css({
//               'left': '17%'
//
//           });
//
//           $(".sidebar_btn_left").attr('id', 'sidebar_btn_left');
//           $("#sidebar_btn_left").removeAttr('class');
//       }
//
//
//
//
//
//});
//
//
//
////    $( "#header" ).toggle("slow");
//    $(document).on('click', '#wrapper3 #sidebar_btn_left', function() {
//        $.cookie('hide_header', 'yes', {path: '/'});
////        $.cookie('hide_header' ,'yes');
////        if ($.cookie('hide_header') == 'yes'){
////            $('#main').toggleClass('nosidebar');
////        }
//
//    $( "#header" ).hide();
//        $("#main").css({
//          'margin': '0 3% 0 15px',
//        'padding': '80px 0 0 10px'
//        });
//        $("#sidebar_btn_left").css({
//            'left': '0%'
//        });
//
//        $("#sidebar_btn_left").addClass('sidebar_btn_left');
//        $(".sidebar_btn_left").removeAttr('id');
//
//
//
//});
//
//    $(document).on('click', '#wrapper3 .sidebar_btn_left', function() {
//
//        $.cookie('hide_header', 'no', {path: '/'});
//        $( "#header" ).show();
//        $("#main").css({
//            'margin': '0 30px 0 250px',
//            'padding': '80px 0 0 10px'
//        });
//        $("#sidebar_btn_left").css({
//            'left': '17%'
//
//        });
//
//        $(".sidebar_btn_left").attr('id', 'sidebar_btn_left');
//        $("#sidebar_btn_left").removeAttr('class');
//
//
//    });

//    $('wheader').toggle(
//
//        function() {
//            $('#header').css('left', '0')
//        }, function() {
//            $('#header').css('left', '200px')
//        });

