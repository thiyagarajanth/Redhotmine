module IniaServiceHelper



  def create_ptos_from_mq(params)
    p '====='
    p params
    find_project_user(params)
    errors=[]
    p params['fromDate'].present? , params['toDate'].present? , @find_activity_id.present? , @find_issue_id.present? , (params['leaveCategory']=="Leave" || params['leaveCategory']=="OnDuty" )
    if params['fromDate'].present? && params['toDate'].present? && @find_activity_id.present? && @find_issue_id.present? && (params['leaveCategory']=="Leave" || params['leaveCategory']=="OnDuty" )
      (params['fromDate'].to_date..params['toDate'].to_date).each do |each_day|
        @time_entry = TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(@project.first.id,@author.id,@find_activity_id,each_day,@find_issue_id )
        @time_entry.issue_id=@find_issue_id
        @time_entry.comments=  params['leaveStatus'].present?  && params['leaveStatus']=="Approved" ? params['leaveDescription'] : ""
        if params['leaveDuration'].present?
          if params['leaveDuration'] == "Full day"
            @time_entry.hours = params['leaveStatus'].present?  && params['leaveStatus']=="Approved"  ? 8 : 0
          elsif params[:leaveDuration] == "Half day"
            @time_entry.hours = params['leaveStatus'].present?  && params['leaveStatus']=="Approved"  ? 4 : 0
          elsif params['leaveDuration'] == "Hours"
            if params['leaveHours'].present?
              hours = params['leaveHours'].to_s
              f = hours.to_s.split(':').first
              s = hours.to_s.split(':').last
              @total_hrs=(f.to_i*60+s.to_i).to_f/60.to_f
            end
            @time_entry.hours = params['leaveStatus'].present?  && params['leaveStatus']=="Approved"  ? "%.2f" % @total_hrs : 0
          end
        end
        if !errors.present? && @time_entry.save
          if params['leaveCategory'] != "OnDuty"
            find_leave_type = Project.find_by_sql("select id from custom_fields where type='TimeEntryCustomField' and name='type'")
            if find_leave_type.present?
              cv = CustomValue.find_or_initialize_by_custom_field_id_and_customized_id_and_customized_type(find_leave_type.first.id,@time_entry.id,"TimeEntry")
              cv.value=params['leaveStatus'].present?  && params['leaveStatus']=="Approved"  ? params['leaveType'] : ""
              cv.save
            end
          end
        end
        if @time_entry.present? && @time_entry.hours.to_i <= 0
          @time_entry.delete
        end
      end
    else
      errors << " Leave can not create for the category..!"
    end
    p '==================================response==================='
    if errors.present?
      p errors.join(',')
      #render_json_errors(errors.join(','))
    else
      p '====ok'
      #render_json_ok(TimeEntry.last)
    end
  end



  def find_project_user(params)
    errors=[]
    if !params['employeeId'].blank?
      p '==================1=================='
      p author = UserOfficialInfo.find_by_employee_id(params['employeeId'])
      if author.present?
        p @author = author.user
        if @author.present?
          p @project = Project.find_by_sql("select p.id,p.name from projects p join members m on m.project_id=p.id where m.user_id in ('#{@author.id}') and m.capacity > 0  group by project_id order by capacity desc limit 1")
        end
      else
        errors << "Employee Id Not found"
      end
    else
      errors << "Employee Id required..!"
    end
    errors << "From date required..!" if params['fromDate'].blank?
    errors << "To date required..!" if params['toDate'].blank?
    errors << "Leave Reason required..!" if params['leaveDescription'].blank?
    errors << "leaveStatus required..!" if params['leaveStatus'].blank?
    errors << "Leave Category required..!" if params['leaveCategory'].blank?
    errors << "Leave Type required..!" if params['leaveCategory'] == "Leave" && params['leaveType'].blank?
    errors << "Full Day Or Half Day Type required..!" if params['leaveDuration'].blank?

    if @author.present? && @project.present? && params['fromDate'].present? && params['toDate'].present?
      find_tracker = Tracker.where(:name=>'support')
      if find_tracker.present?
        @find_tracker_id = find_tracker.first.id
      else
        errors << "Unable apply for Leave, PTO Activity Not Found .!"
      end
      if params['leaveDuration'].present?
        p '======'
        if params['leaveCategory'] != "OnDuty"
          find_activity = Enumeration.where(:name=>'PTO')
          if find_activity.present?
            p @find_activity_id = find_activity.last.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_issue = Issue.where(:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:subject=>'PTO')
          if find_issue.present?
            @find_issue_id = find_issue.first.id
          else
            l2_mems = Member.find_by_sql("select * from members m join member_roles mr on mr.member_id=m.id join roles r on r.id=mr.role_id where m.project_id=#{@project.first.id}  and r.permissions like '%l2%'")
            if l2_mems.present?
              find_issue = Issue.new(:subject=>"PTO",:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:author_id=>l2_mems.first.user_id,:assigned_to_id=>@author.id)
              if find_issue.save(validate: false)
                @find_issue_id = find_issue.id
              end
            else
              errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name},L2 not found for in #{@project.first.name}"
            end
          end
        else
          find_activity = Enumeration.where(:name=>'OnDuty')
          if find_activity.present?
            @find_activity_id = find_activity.last.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_issue = Issue.where(:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:subject=>'OnDuty')
          if find_issue.present?
            @find_issue_id = find_issue.first.id
          else
            l2_mems = Member.find_by_sql("select * from members m join member_roles mr on mr.member_id=m.id join roles r on r.id=mr.role_id where m.project_id=#{@project.first.id}  and r.permissions like '%l2%'")
            if l2_mems.present?
              find_issue = Issue.new(:subject=>"OnDuty",:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:author_id=>l2_mems.first.user_id,:assigned_to_id=>@author.id)
              if find_issue.save(validate: false)
                @find_issue_id = find_issue.id
              end
            else
              errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name},L2 not found for in #{@project.first.name}"
            end
          end
        end
      else
        errors << "Leave Duration required..!"
      end
    else
      errors << "Requested person can not apply for leave,Please contact to respective manager..!"
    end
    true
    if errors.present?
      false
      #render_json_errors(errors.join(','))
    end
  end

end
