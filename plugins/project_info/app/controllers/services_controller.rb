require 'json'
class ServicesController < ApplicationController
  unloadable
  respond_to  :json
  skip_before_filter :verify_authenticity_token
  before_filter :verify_message_api_key
  before_filter :validate_params, :only => :append_members
  before_filter :find_employee, :only => [:get_l1l2_for_employee,:get_subordinates,:get_resource_by_employee_id]
  skip_before_filter :authorize, :check_external_users

  def append_members
    @project = Project.find(params[:projectId])
    p '======ok====='
p    user = UserOfficialInfo.find_by_employee_id(params[:employeeId])
 p   author = UserOfficialInfo.find_by_employee_id(params[:createdBy])
    if params[:employeeId] && user.present?
      #user.id = UserOfficialInfo.find_by_employee_id(params[:user_id]).user_id
      #member = Member.new(:role_ids => [params[:roleId]], :user_id => user.user_id, 
        #:project_id => @project.id,:capacity => params[:capacity], :billable => '1')
      member = Member.find_or_initialize_by_user_id_and_project_id(user.user_id,@project.id)
      member.role_ids=[params[:roleId]]
      member.user_id = user.user_id
      member.project_id=@project.id
      member.capacity=params[:capacity].to_f
      p '===================poarams============'
      p params
      member.billable = params[:billingType]
p     billable = BillableType.where('lower(name) = ?', params[:billingType].downcase).first
      member.billable_type_id= billable.id rescue nil      
    end
    if user.present? && member.save
      mem = MemberHistory.find_or_initialize_by_user_id_and_project_id(user.user_id,@project.id)
      mem.capacity = params[:capacity].to_f
      billable = BillableType.where('lower(name) = ?', params[:billingType].downcase).first
      mem.billable = params[:billingType]# params[:billingType].present? && params[:billingType]=='billable' ? params[:billingType] : 'shadow'
      mem.billable_type_id = billable.id rescue nil
      mem.start_date = params[:fromDate]
      mem.end_date = params[:toDate]
      mem.created_by = author.user_id
      mem.member_id=member.id
      mem.save
      render json: {:member_id=>member.id} , :layout => nil and return true
    else
      errors = user.present? ? member.errors : 'OK'
      render :json => errors,  :layout => nil and return true
    end
  end

  def billable_statuses
    p BillableType.count
    if params[:name].present?
      name = params[:oldName].present? ? params[:oldName] : params[:name]
      bt = BillableType.find_or_initialize_by_name(name)
      bt.name = params[:name]
      bt.is_billable = params[:isBillable]
      bt.can_contributable = params[:canContributable]
      bt.is_active = params[:isActive]
      if bt.save
        render :json => {:status => "Success"}
      else
        render :json => {:status => "Failed to save"}
      end
    else
      render :json => {:status => "Invalid parameter"}
    end
    p BillableType.count
  end

  def billingtype
    bt = BillableType.find_by_name(params[:name])
    mem_count = Member.where(:billable_type_id => bt.id).count rescue 0
    render :json => {:count => mem_count}
    
  end

  def employee_cost_report
    inia =  ActiveRecord::Base.establish_connection(:development).connection
    usersCost = inia.execute("CALL getCostOfEmployeeProjectInfo()")
    emp_cost = []
    details =  usersCost.each(:as => :hash)
    details.each do |rec|
      projects = rec['details'].split('!')
      project_details = []
      projects.each do|rec|
        data = rec.split(',')
        project_details << {
            :client => data[0],
            :project => data[1],
            :manager => data[2] != '-NA-' ? data[2] : '' ,
            :accountability => data[3]
        }
      end
      emp_cost << {
          :employeeId => rec['employee_id'],
          :firstName => rec['firstname'],
          :lastName => rec['lastname'],

          :projects => project_details
      }
      ActiveRecord::Base.connection.reconnect!
    end
    render :json => emp_cost, :status => 200, :layout => nil
  end

  def flexi_off_report
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    if params[:employeeId].present? && params[:startDate].present? && params[:endDate].present?
      flexi = inia.execute("CALL getlmsFlexiReport('#{params[:employeeName]}','#{params[:employeeId]}','#{params[:projectName]}','#{params[:startDate]}','#{params[:endDate]}')")
      flexireport = []
      flexidata = flexi.each(:as => :hash)
      flexidata.each do |fr|
              flexireport << {
            :employeeId => fr['employee_id'],
            :employeeName => fr['firstname'] + ' ' + fr['lastname'],
            :loginId => fr['login'],
            :flexiOffDate => fr['spent_on'],
            :flexiOffMonth => fr['months'],
            :flexiOffHours => fr['flexihours'],
            :flexiOffCategory => fr['flexioff_reason'],
            :projectName => fr['project_name']
          }
          ActiveRecord::Base.connection.reconnect!
      end
      ActiveRecord::Base.connection.reconnect!
      render :json => flexireport, :status => 200, :layout => nil
    else
      render :json => "Employee_id,startDate and endDate is required"
    end
  end

  def get_project_flexi_hours
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    if params[:projectName].present? && params[:startDate].present? && params[:endDate].present?
      flexi = inia.execute("CALL getProjectFlexiHours('#{params[:projectName]}','#{params[:startDate]}','#{params[:endDate]}')")
      flexidata = flexi.each(:as => :hash)
      reports = []
      flexis =  flexidata.group_by(&:first).map { |c, xs| [c, xs] }
      flexis.each_with_index do |rec,i|
        total_flexi = 0
        date_hours = []
        rec[1].each do |fr|
        total_flexi = total_flexi+fr["flexihours"].round(2)
        date_hours << {:date => fr["spent_on"], :hours => fr['flexihours'].round(2)}
        ActiveRecord::Base.connection.reconnect!
        end
        reports << {:project => rec.first[1], :totalFlexiHours => total_flexi.round(2), :flexiData => date_hours }
        ActiveRecord::Base.connection.reconnect!
      end
      # flexidata.each do |fr|
      #   total_flexi = total_flexi+fr["flexihours"]
      #   date_hours << {:date => fr["spent_on"], :hours => fr['flexihours']}
      #   ActiveRecord::Base.connection.reconnect!
      # end
      ActiveRecord::Base.connection.reconnect!
      # report = {:project => project_name, :totalFlexiHours => total_flexi, :flexiData => date_hours }
      render :json => reports, :status => 200, :layout => nil
    else
      render :json => "Project Name,startdate and endDate is required."
    end    
  end

  def get_l1l2_for_employee
    inia = ActiveRecord::Base.establish_connection(:production).connection
    if @employee.present? 
      approvers = inia.execute("CALL getiNiaL1L2L3ForEmployee('#{params[:employeeId]}')")
      render :json => approvers, :status => 200, :layout => nil
    else
      render :json => "Employee not found..!"
    end
  end

  def get_subordinates
    inia = ActiveRecord::Base.establish_connection(:production).connection
    if @employee.present?
      subordinates = inia.execute("CALL getSubordinates('#{params[:employeeId]}')")
      ActiveRecord::Base.connection.reconnect!
      render :json => subordinates, :status => 200, :layout => nil
    else
      render :json => "Employee not found..!"
    end
  end

  def get_resource_by_employee_id
    inia = ActiveRecord::Base.establish_connection(:production).connection
    if @employee.present?
      resource = inia.execute("CALL getResourceInfoByEmpid('#{params[:status]}','#{params[:firstName]}','#{params[:client]}','#{params[:employeeId]}','#{params[:page]}','#{params[:count]}','#{params[:billingType]}','#{params[:project]}','#{params[:department]}')")
      resources = []
      resource_info = resource.each(:as => :hash)
      resource_details = get_resource_hash(resource_info)
      
      ActiveRecord::Base.connection.reconnect!
      render :json => resource_details, :status => 200, :layout => nil
    else
      render :json => "Employee not found..!"
    end
  end

  def get_resource_info
    inia = ActiveRecord::Base.establish_connection(:production).connection
    resource = inia.execute("CALL getResourcesInfo('#{params[:status]}','#{params[:firstName]}','#{params[:client]}','#{params[:employeeId]}','#{params[:page]}','#{params[:count]}','#{params[:billingType]}','#{params[:project]}','#{params[:department]}')")
    resource_data = resource.each(:as => :hash)
    resource_results = []
    tmp_arr = []
    resource_data.each do |resource_info|
      tmp_arr << resource_info
      resource_results << get_resource_hash(tmp_arr)
      tmp_arr.clear
    end
    ActiveRecord::Base.connection.reconnect!
    render :json => resource_results, :status => 200, :layout => nil
  end


  def get_resource_hash(resource_info)
    resource_details = []
    project_details = []
    project_data =  resource_info[0]["engagement_name"].present? ? resource_info[0]["engagement_name"].split(',') : []
    if project_data.present?
      project_data.each do |pro|
        project_info = pro.split('!')
        project_details << {:client => project_info[0],
                            :project => project_info[1],
                            :accountability => project_info[2],
                            :utilization => project_info[3],
                            :startDate => project_info[4],
                            :endDate => project_info[5],
                            :status => project_info[6],
                            :role => project_info[7],
                            :coEmployeeId => project_info[8],
                            :doEmployeeId => project_info[9],
                            :l1EmployeeId => project_info[10]
        }
      end
    end
   
    resource_details << {:employeeId => resource_info[0]["employee_id"],
                         :firstName => resource_info[0]["firstname"],
                         :lastName => resource_info[0]["lastname"],
                         :emailId => resource_info[0]["mail"],
                         :loginId => resource_info[0]["login"],
                         :visa => resource_info[0]["visa"].present? ? resource_info[0]["visa"] : "null",
                         :status =>resource_info[0]["status"].present? ? resource_info[0]["status"] : "null",
                         :projects => project_details

    }
    return resource_details
  end

  def get_project_list
    inia = ActiveRecord::Base.establish_connection(:production).connection
    projects = inia.execute("CALL get_project_list('#{params[:isDelivery]}','#{params[:searchString]}')")
    project_list = []
    if projects.present?
      projects.each do |project|
        project_list << {:id => project[0],
                         :name => project[1],
                         :code => project[2]
        }
      end
      ActiveRecord::Base.connection.reconnect!
      render :json => project_list, :status => 200, :layout => nil
    else
      render :json => "No projects available..!"
    end
  end
  def get_all_projects
    inia = ActiveRecord::Base.establish_connection(:production).connection
    projects = inia.execute("CALL getAllProjects('#{params[:searchString]}', '#{params[:departmentCode]}')")
    if projects.present?
      render :json => projects, :status => 200, :layout => nil
      ActiveRecord::Base.connection.reconnect!
    else
      render :json => "No projects available..!"
    end
  end




  def epup_dashboard
    # version = Version.find_by_sql("select v.id as id from versions v, projects p where CURDATE() BETWEEN v.ir_start_date and v.ir_end_date and v.project_id=p.id and p.id=221 order by id desc limit 1").map(&:id).last
    # issue_ids = Issue.find_by_sql("select s.id from issues s where fixed_version_id=#{version}").map(&:id)
    # issues_count, estimate_times = Issue.find_by_sql("select count(*) as issues_count, sum(s.estimated_hours) as estimated_hours from issues s where s.id in (#{issue_ids.join(', ')})").map{|x|[x.issues_count, x.estimated_hours]}.flatten
    # total_spent_times = TimeEntry.find_by_sql("SELECT SUM(time_entries.hours) as hours FROM time_entries WHERE time_entries.issue_id in (#{issue_ids.join(', ')})").map(&:hours).last
    # story = CustomField.find_by_name('Story Point')
    # story_points = Issue.find_by_sql("select sum(value) as count from issues INNER JOIN custom_values on issues.id=custom_values.customized_id WHERE custom_values.custom_field_id=#{story.id} and issues.fixed_version_id IN (#{version})").map(&:count).last
    # @statuses = IssueStatus.where(:name=>["Resolved","Closed","Ready For Code Review"])
    # cr_issues =   Issue.find_by_sql("select id from issues where id in (#{issue_ids.join(',')}) and status_id  in (#{@statuses.map(&:id).join(',')})").map(&:id)
    # unit_test = Issue.find_by_sql("select count(cv.id) as issue_count from custom_values cv where cv.customized_type='Issue' and custom_field_id in(select id from custom_fields where name='Unit test result') and cv.customized_id in (#{cr_issues.map(&:id).join(',')}) and cv.value !='' ")
    # code_review = Issue.find_by_sql("select count(cv.id) issue_count from custom_values cv where cv.customized_type='Issue' and custom_field_id in(select id from custom_fields where name='Code review result') and cv.customized_id in (#{cr_issues.map(&:id).join(',')}) and cv.value !='' ")
    # engagement = Project.find(params[:engagement])
    engagement = Project.find_by_name(params['engagement'])
    if engagement.present?
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    objects = inia.execute("CALL `epubdashboard`('#{engagement.name}')")
    details =  objects.each(:as => :hash)
    dashboards = []
    details.each do |rec|
      ev = rec['estimated_hours'].to_f > 0 ? ((rec['spenthours'].to_f - rec['estimated_hours'].to_f) / rec['estimated_hours'].to_f * 100).round(2) : 0
      ut =  rec['totalunittestissue'].to_f > 0 ? ((rec['unittestcount'].to_f * 100) / rec['totalunittestissue'].to_f).round(2) : 0
      cr = rec['totalcrissue'].to_f > 0 ? ((rec['crcount'].to_f * 100) / rec['totalcrissue'].to_f).round(2) : 0
      total_story = rec['totalstory'].to_i
      p dc = (rec['startdate'].to_date..(Date.today))
      closed_story = rec['totalclstory'].to_i
      idle_issues_devide = (total_story/dc.count) rescue 0
      idle_issues_count = []
      issues_count_array = []
      dc.to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          idle_issues_count << total_story
        else
          idle_issues_count << (total_story -= idle_issues_devide).round
        end
        issues_count = (total_story-closed_story.to_i)
        issues_count_array << issues_count rescue 0
      end
      count =  (idle_issues_count.last - issues_count_array.last) rescue 0
      sp_res = (((count.to_f/idle_issues_count.last.to_f).to_f rescue 0) * 100).round(2)
      spc = sp_res.nan? ? 0 : sp_res

      #===========================================
      dashboards << {:project => rec['name'], :sprint => rec['sprint_name'], :delivery => {:ev => ev, :spc => spc, :impediment => rec['totalimpediment']},
       :quality => {:ut => ut, :code_coverage => cr, :bugs => rec['totalbug']}, :projectrisk => {:risk_score => rec['scorecount'], :risk => rec['totalrisk'], :pci => '100'} }
      ActiveRecord::Base.connection.reconnect!
    end
    render :json => {:list => dashboards}, :status => 200, :layout => nil
    else
      render :json => {:error => "Please provide valid Engagement name."}, :status => 200, :layout => nil
    end

  end

  # def flexi_off
  #   clients, employeeIds, projects, fromDate, toDate = params['clients'], params['employeeIds'], params['projects'], params['fromDate'], params['toDate']
  #
  #     inia =  ActiveRecord::Base.establish_connection(:production).connection
  #     objects = inia.execute("CALL `inia_qc`.`epubdashboard`(#{clients}, #{employeeIds}, #{projects}, #{fromDate}, #{toDate})")
  #     details =  objects.each(:as => :hash)
  #     flexi = []
  #     details.each do |rec|
  #       ev = rec['firstname'].to_f > 0 ? ((rec['spenthours'].to_f - rec['estimated_hours'].to_f) / rec['estimated_hours'].to_f * 100) : 0
  #       ut =  rec['totalunittestissue'].to_f > 0 ? ((rec['unittestcount'].to_f * 100) / rec['totalunittestissue'].to_f) : 0
  #       cr = rec['totalcrissue'].to_f > 0 ? ((rec['crcount'].to_f * 100) / rec['totalcrissue'].to_f) : 0
  #
  #       flexi << {:firstname => rec['firstname'], :lastname => rec['lastname'],
  #                      :employee_id => rec['employee_id'], :months => rec['months'], :project_id => rec['project_id'], :spent_on => rec['spent_on'], :flexioff_reason => rec['flexioff_reason'] }
  #       ActiveRecord::Base.connection.reconnect!
  #     end
  #     render :json => flexi, :status => 200, :layout => nil
  # end


  def inia_access_for_users
    if params[:employeeId].present?
      user_access = AccessRestriction.find_or_initialize_by_employee_id(params[:employeeId])
      user_access.time_entry_process = 1
      if user_access.save
        render :json => {:status => "Success"}, :status => 200, :layout => nil
      else
        render :json => {:status => "User Not updated."}
      end
    else
      render :json => {:status => "Employee ID mandatory."}
    end
  end


  private

  def verify_message_api_key
    if request.present? && request.headers["key"].present?
        find_valid_key = Redmine::Configuration['nalan_api_key'] || File.join(Rails.root, "files")
       (find_valid_key == request.headers["key"].to_s) ? true : render_json_errors("Key Invalid.")
    else
      render_json_errors("Key not found in Url.")
    end
  end


  def validate_params
    errors=[]
    if params[:employeeId].present?
       find_user = UserOfficialInfo.find_by_employee_id(params[:employeeId])
       if find_user.present?
       user_for_member = User.find(find_user.user_id)
        if !user_for_member.present?
          errors << "employeeId not valid..!"
        end
       else
         errors << "employeeId not valid..!"
         end
    else
      errors << "employeeId required..!"
    end
    if params[:createdBy].present?
      p find_user = UserOfficialInfo.find_by_employee_id(params[:createdBy])
      p user_for_created_by = User.find(find_user.user_id) rescue nil
      if !user_for_created_by.present?
        errors << "createdBy not valid..!"
      end
    else
      errors << "createdBy required..!"
    end
    if params[:projectId].present?
    find_project = Project.find(params[:projectId])
    else
      errors << "projectId required..!"
    end

    if params[:capacity].present?
      if params[:capacity].to_f <= 0
        errors << "capacity should be greater than 0..!"
      end

      if params[:capacity].to_f > 1
        errors << "capacity should not be greater than 1..!"
      end
    else
      errors << "capacity required..!"
    end
    if params[:roleId].present?
   
    find_role = Role.where(:id=> params[:roleId])
  
      if !find_role.present?
        errors << "roleId not valid.!"
      end
    else
      errors << "roleId required..!"
    end

    # if !params[:fromDate].present?
    #   # find_role = Role.find(params[:roleId])
    #   errors << "fromDate required..!"
    # end
    # if !params[:toDate].present?
    #   errors << "toDate required..!"
    #   # find_role = Role.find(params[:roleId])
    # end

    # if user_for_member.present? && find_project.present?
    #  find_member = Member.find_by_user_id_and_project_id(user_for_member.id,find_project.id)
    #   if find_member.present?
    #     errors << "Member already exist..!"
    #   end
    # end


    if errors.present?
      render :json => errors,:errors=>errors, :layout => nil and return true
    end


  end

  def find_employee
     if params[:employeeId].present?
      @employee = UserOfficialInfo.find_by_employee_id(params[:employeeId])
     else
      render :json => "Employee_id required..!"
    end
  end

  def render_json_errors(errors)
    render :json => errors,:errors=>errors, :layout => nil and return true
  end

  def render_json_ok(issue)
    render_json_head(issue,"ok")
  end


  def render_json_head(issue,status)
    render :json => {:ticket_id=>issue}, :status => 200, :layout => nil
  end


end
