
//.unbind()
$(document).on('change', '#user_billable', function(event) {
    event.stopImmediatePropagation();
    // code here
    
    var thi = $(this)

    member_id = $(this).attr("member_id");
    supportTypename =  $(':selected', this).text();
    supportTypeId = $(':selected', this).val();
    
    $('<input>').attr({
        type: 'hidden',
        id: 'member_billable_'+member_id,
        name: 'billable_type_id',
        value: supportTypeId
    }).appendTo('#member-'+member_id+'-roles-form');
    $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", false);

    $.ajax({
        url: "/employee_info/check_member_contributable", // Route to the Script Controller method
        type: "GET",
        dataType: "json",
        data: {id:supportTypeId},

        success: function (data) {
            
            if (data == false){
            
                $("table.memberships #div_member_capacity_slider").slider('value', 0);
                thi.parent().parent().find("#div_member_capacity_slider").slider('value', 0);
                $("#member_capacity_"+$('#user_billable').attr("member_id")).val(0);
                 
            
                var options = {
                    width: 200,
                    height: 150,
                    backgroundColor: "#ffffdd",
                    pieHole: 0.4,
                    pieSliceText: "value",
                    text: "value",
                    tooltip: { isHtml: true },
                    tooltip: {text: "percentage"},
                    pieSliceTextStyle: {
                        color: 'black',
                        bold: true,
                        italic: true,
                        alignment: "center"
                            },
                    colors: ['#FF9933', '#E82D2D', '#006600'],
                    legend: {
                        alignment: 'center', textStyle: {color: 'blue', fontSize: 8}
                    }
                };
                var current_capacity = thi.closest('tr').find("input#current_capacity").val();
                var available_capacity = thi.closest('tr').find("input#available_capacity").val();
                var other_capacity = thi.closest('tr').find("input#other_capacity").val();
             
                var data1 = google.visualization.arrayToDataTable([
                    ['Type', 'Value'],
                    ['Available',     parseInt(available_capacity) + parseInt(current_capacity) ],
                    ['Other',     parseInt(other_capacity)],
                    ['Assigned',     0],
                ]);
                var chart = new google.visualization.PieChart($("#capacity_chart_"+member_id)[0]);
               // alert(data)
                chart.draw(data1 ,options);
            }
        }
    });
});


$(document).on('click','table.memberships .icon-edit', function(event) {
    
    if ($(this).closest('tr').find('#user_billable').attr('billable_admin')){
      $(this).closest('tr').find('#user_billable').attr('disabled', false)
    }

    var disabled_values = $('#disabled_option').val()
    // console.log(disabled_values)
    var arr = JSON.parse('['+disabled_values+']');
    console.log(arr)
    for(i in arr) {
        $(".user_billable_options").find("option[value="+arr[i]+"]").prop("disabled", true) 
    }
    event.stopImmediatePropagation();

    var billable_status = $(this).closest('tr').find("#member_billable_status").val();
    var capacity = $(this).closest('tr').find("input#current_capacity").val();
    var member_id = $(this).closest('tr').find("#member_billable_status").attr("member_id");
    $('#member-'+member_id+'-roles-form').find('a').attr('id', 'cancel_member');
    $('#member-'+member_id+'-roles-form').find('a').attr('member_id', member_id);
//   
    $(this).closest('tr').find("#div_member_capacity_slider").show();
    supportTypeId = $(':selected', '#user_billable').val();
    supportTypename =  $(':selected','#user_billable' ).text();
  
    if (billable_status == supportTypeId) {
    
        billable_status = supportTypeId
    }
       
    $('<input>').attr({
        type: 'hidden',
        id: 'member_billable_'+member_id,
        name: 'billable_type_id',
        value: billable_status
    }).appendTo('#member-'+member_id+'-roles-form');

    $('<input>').attr({
        type: 'hidden',
        id: 'member_capacity_'+member_id,
        name: 'capacity',
        value: capacity
    }).appendTo('#member-'+member_id+'-roles-form');
    var dis = $(this).closest('tr').find("#member_billable_status").val();
    var thi = $(this)
    $.ajax({
        url: "/employee_info/check_member_contributable", // Route to the Script Controller method
        type: "GET",
        dataType: "json",
        data: {id:dis},

        success: function (data) {
            if (data == true){
                thi.closest('tr').find('#user_billable').attr('disabled', true)
                thi.closest('tr').find("#div_member_capacity_slider").hide();        
            }else{thi.closest('tr').find('#user_billable').attr('disabled', false)}
        }
    });
});

$(document).on('click', '#cancel_member', function(event) {
    event.stopImmediatePropagation();
    var billable_status = $(this).closest('tr').find("#member_billable_status").val();
    
    var member_id = $(this).attr("member_id");
     $(this).closest('tr').find("#user_billable").attr("disabled", true);

    // console.log($(this).closest('tr').find("#div_member_capacity_slider"))
    $(this).closest('tr').find("#div_member_capacity_slider").slider('disable');
    return false;

});


$(document).on('change', '#billable', function(event) {

    event.stopImmediatePropagation();
    
    var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
    member_id = $('#user_billable').attr("member_id");
    supportTypeId = $(':selected', '#billable').val();
    // console.log(supportTypeId)

    $('<input>').attr({
        type: 'hidden',
        id: 'member_billable_'+member_id,
        name: 'billable_type_id',
        value: supportTypeId
    }).appendTo('#member-'+member_id+'-roles-form');
    $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", false);



    var bill = function () {
        var tmp = null
        $.ajax({
            async: false,
            global: false,
            url: "/employee_info/check_member_contributable", // Route to the Script Controller method
            type: "GET",
            dataType: "json",
            data: {id:supportTypeId},

            success: function (data) {
                // console.log('data=====')
                // console.log(data)
                tmp = data;
            }
        });
        return tmp;
        // console.log(tmp)
    }();

    if (bill == false){
            
        $('#billable').parent().parent().find("#div_member_capacity_slider").slider('value', 0);
        $("form#user_new_membership #member_capacity").val(other_capacity)
    }
});


$(function() {
   $( "#slider" ).slider();
});


/* Loading chart Handile bar */

$( document ).ready(function() {
    // Handler for .ready() called.

    $(".list.memberships #member_capacity").each(function() {

        var current_capacity = $(this).find("input#current_capacity").val();
        var available_capacity = $(this).find("input#available_capacity").val();
        var other_capacity = $(this).find("input#other_capacity").val();
        var element = $(this);
        var member_id= $(this).find("input#member_id").val();
/* slider tooltip */
        var tooltip = $('<div id="tooltip" />').css({
            position: 'absolute',
            top: -25,
            left: -10
        }).hide();

/* Google chart options */
        var options = {
            width: 200,
            height: 150,
            backgroundColor: "#ffffdd",
            pieHole: 0.4,
            pieSliceText: "value",
            text: "value",
            tooltip: { isHtml: true },
            tooltip: {text: "percentage"},
            pieSliceTextStyle: {
                color: 'black',
                bold: true,
                italic: true,
                alignment: "center"
                    },
            colors: ['#FF9933', '#E82D2D', '#006600'],
            legend: {
                alignment: 'center', textStyle: {color: 'blue', fontSize: 8}
            }
        };

        $(this).find("#div_member_capacity_slider").slider({

            range: "min",
            step: 5,
            value: current_capacity,
            min: 0,
            max: 100,
            slide: function( event, ui ) {

                var billable_value = $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").val();

                 supportTypeId = $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").val();//$(':selected', '#user_billable').val();
               var bill = function () {
                    var tmp = null
                    $.ajax({
                        async: false,
                        global: false,
                        url: "/employee_info/check_member_contributable", // Route to the Script Controller method
                        type: "GET",
                        dataType: "json",
                        data: {id:supportTypeId},

                        success: function (data) {
                            // console.log('data=====')
                            // console.log(data)
                            tmp = data;
                        }
                    });
                    return tmp;
                    // console.log(tmp)
                }();

               // console.log(bill)
                if(bill == true)
                {
                  if(ui.value < 5 )
                    {
                        return false;
                    }

                }
                else{
                    return false
                }

                if(ui.value > (100-other_capacity) )
                {
                    return false;
                }
                $(element).find("span#selected_capacity" ).text( "Selected: " + ui.value+"%" );
                $(element).find("input#selected_capacity" ).val(ui.value);
                $(element).find("#tooltip").text(ui.value);
                $('#member-'+member_id+'-roles-form').find('#member_capacity_'+member_id).val(ui.value);
                var current_capacity=ui.value;
                var available_capacity= (100-(parseInt(current_capacity)+parseInt(other_capacity)));
                var data = google.visualization.arrayToDataTable([
                    ['Type', 'Value'],
                    ['Available',     parseInt(available_capacity)],
                    ['Other',     parseInt(other_capacity)],
                    ['Assigned',     parseInt(current_capacity)],
                ]);
                var chart = new google.visualization.PieChart($("#capacity_chart_"+member_id)[0]);
                chart.draw(data, options);

            },
            change: function(event, ui) {}
        }).find(".ui-slider-handle").append(tooltip).hover(function() {

                tooltip.show();

                $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
            }, function() {
                tooltip.hide();
            }
        );
        var data = google.visualization.arrayToDataTable([
            ['Type', 'Value'],
            ['Available',     parseInt(available_capacity)],
            ['Other',     parseInt(other_capacity)],
            ['Assigned',     parseInt(current_capacity)],
        ]);
/* Google chart draw */
        if(member_id) {
            var chart = new google.visualization.PieChart($("#capacity_chart_" + member_id)[0]);
            chart.draw(data, options);
            google.visualization.events.addListener(chart, 'click', function(e) {
                var match_sting = e.targetID.match(/slice#/g);
                if(match_sting)
                {
                    var position = e.targetID.split("#").last
                }
                 if(e.targetID.split("#")[1]==1)
                 {
                    var position = e.targetID.split("#").last
                    $.ajax({
                         url: "/employee_info/get_capacity_details_of_other_project", // Route to the Script Controller method
                         type: "POST",
                         dataType: "json",
                         data: {member_id:member_id},
                         // This goes to Controller in params hash, i.e. params[:file_name]
                         complete: function () {
                         },
                         success: function (data) {
                             if($("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "isOpen" ))
                                {
                                    $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "close" );
                                    $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").remove();
                                }
                                 $("#member-"+data.member_id+" td").last().append(data.CapacityDetailsPartial);

                             $( "#OtherCapacitypopupWindow" ).dialog({
                                 resizable: false,
                                 width:600,

                                 modal: true,
                                 buttons: {

                                     Close: function() {
                                         $( this ).dialog( "close" );
                                     }
                                 }
                             });
                         }

                     });
                 }

           });
            google.visualization.events.addListener(chart, 'onmouseover', barMouseOver);
            google.visualization.events.addListener(chart, 'onmouseout', barMouseOut);

        }

        function barMouseOver(e) {
            if(e.row == 1)
            {
                $("#capacity_chart_"+member_id).css('cursor','pointer');
            }
        }

        function barMouseOut(e) {
            if(e.row == 1)
            {
                $("#capacity_chart_"+member_id).css('cursor','');
            }

        }
        $(element).find("span#selected_capacity" ).text( "Selected" + $(element).find("#div_member_capacity_slider").slider( "value" )+"%" );
        //$(element).find("#div_member_capacity_slider").slider('disable');
        if ($(element).closest('tr').find("#user_billable").attr('billbable_admin')=='false'){
         $(element).find("#div_member_capacity_slider").slider('disable');      
        }

    });


});



/* membership checkbox */



$( document ).ready(function() {
    var tooltip = $('<div id="tooltip" />').css({
        position: 'absolute',
        top: -25,
        left: -10
    }).hide();


    var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
    var available_capacity = $("form#user_new_membership").find("input#available_capacity").val();

    $("form#user_new_membership #div_member_capacity_slider").slider({
        range: "min",
        step: 05,
        value: other_capacity,
        min: 0,
        max: 100,
        slide: function (event, ui) {
            tooltip.text(ui.value);
            $(this).find("input#member_capacity" ).val(ui.value);

            var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
            var available_capacity = $("form#user_new_membership").find("input#available_capacity").val();

            $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
            $(this).find("input#member_capacity" ).val(ui.value);

            var billable_value = $('form#user_new_membership select#billable').val();
            supportTypeId = $(':selected', '#billable').val();//$(':selected', 'form#user_new_membership select#billable').val();
                var bill = function () {
                    var tmp = null
                    $.ajax({
                        async: false,
                        global: false,
                        url: "/employee_info/check_member_contributable", // Route to the Script Controller method
                        type: "GET",
                        dataType: "json",
                        data: {id:supportTypeId},

                        success: function (data) {
                            console.log('data=====')
                            console.log(data)
                            tmp = data;
                        }
                    });
                    return tmp;
                    // console.log(tmp)
                }();
            
            if(bill == true)
            {
                if(ui.value < other_capacity )
                {
                    return false;
                }

            }
            else{
                $("form#user_new_membership #member_capacity").val(other_capacity)
                return false

            }
            $("form#user_new_membership #member_capacity").val($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0])



            var current_selected_capacity=($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]-other_capacity);

            $("form#user_new_membership #capacity").val(current_selected_capacity);

        },
        change: function (event, ui) {
        }
    }).find(".ui-slider-handle").append(tooltip).hover(function () {
            tooltip.show();
            $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);

        }, function () {
            tooltip.hide();
        }
    );
});


$( document ).ready(function() {
    // GET CO DO ROle

    var co_do_role = $("#get_co_do_role").val();
    if(co_do_role=="false")
    {
        $("#tab-content-members .splitcontentright").hide();
        $(".buttons").hide();
    }

    // $("form#user_new_membership #div_member_capacity_slider").slider('disable');
// Hiding the roles

    $("input[name='membership[role_ids][]']").each( function () {

        console.log($("#get_internal_role").val())

        if($("#get_internal_role").val() && $.inArray( parseInt($(this).val()), $("#get_internal_role").val().split(',').map(Number) ) == -1 )
        {
            $(this).hide();
        }
        else
        {

            $(this).prop("disabled", false);
        }

    });

});
