module WktimeHelper
  include Redmine::Export::PDF
  include Redmine::Utils::DateCalculation
  require 'nokogiri'

  def options_for_period_select(value)
    options_for_select([[l(:label_all_time), 'all'],
                        [l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_this_month), 'current_month'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_this_year), 'current_year']],
                       value.blank? ? 'current_month' : value)
  end

  def options_wk_status_select(value)
    options_for_select([[l(:label_all), 'all'],
                        [l(:wk_status_new), 'n'],
                        [l(:wk_status_submitted), 's'],
                        [l(:wk_status_approved), 'a'],
                        [l(:wk_status_rejected), 'r']],
                       value.blank? ? 'all' : value)
  end

  def statusString(status)

    statusStr = l(:wk_status_new)
    case status
      when 'a'
        statusStr = l(:wk_status_approved)
      when 'r'
        statusStr = l(:wk_status_rejected)
      when 's'
        statusStr = l(:wk_status_submitted)
      else
        statusStr = l(:wk_status_new)
    end
    return statusStr
  end

  def statusEntry(entry,user_id)


   @admin_user = User.find_by_login("admin")
    startday = entry.spent_on.to_date
    end_day = (startday + 6)
    work_days = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)

      else
        work_days << day
      end
    end
    #end_day = (startday + 6)
    status_l1 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l1",user_id: entry.user_id)
    status_l2 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l2",user_id: entry.user_id)
    status_l3 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l3",user_id: entry.user_id)
    status_n = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "n",user_id: entry.user_id)
    status_r = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "r",user_id: entry.user_id)
    #   if status_l1.present? && work_days.present? && status_l1.length >= work_days.count
    if status_l1.present? && work_days.present? && status_l1.length >= 4
      final_status_l1 = status_l1.map(&:status).uniq
    end
    if status_l2.present? && work_days.present? && status_l2.length >= 4
      final_status_l2= status_l2.map(&:status).uniq
    end
    if status_l3.present? && work_days.present? && status_l3.length >= 4
      final_status_l3= status_l3.map(&:status).uniq
    end
    if final_status_l3.present? && final_status_l3.length==1
      status = "l3"
    elsif final_status_l2.present? && final_status_l2.length==1
      status_admin_l2 = Wktime.where(begin_date: startday.to_date..end_day.to_date,status: "l2",user_id: entry.user_id,:statusupdater_id=>@admin_user.id)
      if status_admin_l2.present?
      status = "sl2"
      else
        status = "l2"
      end

      # status = "l2"
    elsif final_status_l1.present? && final_status_l1.length==1
      status = "l1"
    elsif status_r.present? && status_r.length > 4
      status = "r"
    end


    statusStr = l(:wk_status_new)
    case status
      when 'l1'
        statusStr = l(:wk_status_l1_approved)
      when 'l2'
        statusStr = l(:wk_status_l2_approved)
      when 'sl2'
        statusStr = l(:wk_status_syl2_approved)
      when 'l3'
        statusStr = l(:wk_status_l3_approved)
      when 'r'
        statusStr = l(:wk_status_rejected)
      when 's'
        statusStr = l(:wk_status_submitted)
      else
        statusStr = l(:wk_status_new)
    end
    return statusStr
  end

  # Indentation of Subprojects based on levels
  def options_for_wktime_project(projects, needBlankRow=false)
    projArr = Array.new
    if needBlankRow
      projArr << [ "", ""]
    end

    #Project.project_tree(projects) do |proj_name, level|
    project_tree(projects) do |proj, level|
      indent_level = (level > 0 ? ('&nbsp;' * 2 * level + '&#187; ').html_safe : '')
      sel_project = projects.select{ |p| p.id == proj.id }
      projArr << [ (indent_level + sel_project[0].name), sel_project[0].id ]
    end
    projArr
  end

  # Returns a CSV string of a weekly timesheet
  def wktime_to_csv(entries, user, startday, unitLabel)
    decimal_separator = l(:general_csv_decimal_separator)
    custom_fields = WktimeCustomField.find(:all)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [l(:field_user),
                 l(:field_project),
                 l(:field_issue),
                 l(:field_activity)
      ]
      if !unitLabel.blank?
        headers << l(:label_wk_currency)
      end
      unit=nil

      set_cf_header(headers, nil, 'wktime_enter_cf_in_row1')
      set_cf_header(headers, nil, 'wktime_enter_cf_in_row2')

      hoursIndex = headers.size
      startOfWeek = getStartOfWeek
      for i in 0..6
        #Use "\n" instead of '\n'
        #Martin Dube contribution: 'start of the week' configuration
        headers << (l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + I18n.localize(@startday+i, :format=>:short)) unless @startday.nil?
      end
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(
          c.to_s, l(:general_csv_encoding) )  }
      weeklyHash = getWeeklyView(entries, unitLabel, true) #should send false and form unique rows
      col_values = []
      matrix_values = nil
      totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
      weeklyHash.each do |key, matrix|
        matrix_values, j = getColumnValues(matrix, totals, unitLabel,false,0)
        col_values = matrix_values[0]
        #add the user name to the values
        col_values.unshift(user.name)
        csv << col_values.collect {|c| Redmine::CodesetUtil.from_utf8(
            c.to_s, l(:general_csv_encoding) )  }
        if !unitLabel.blank?
          unit=matrix_values[0][4]
        end
      end
      total_values = getTotalValues(totals, hoursIndex,unit)
      #add an empty cell to cover for the user column
      #total_values.unshift("")
      csv << total_values.collect {|t| Redmine::CodesetUtil.from_utf8(
          t.to_s, l(:general_csv_encoding) )  }
    end
    export
  end


  # Returns a PDF string of a weekly timesheet
  def wktime_to_pdf(entries, user, startday, unitLabel)

    # Landscape A4 = 210 x 297 mm
    page_height   = Setting.plugin_redmine_wktime['wktime_page_height'].to_i
    page_width    = Setting.plugin_redmine_wktime['wktime_page_width'].to_i
    right_margin  = Setting.plugin_redmine_wktime['wktime_margin_right'].to_i
    left_margin  = Setting.plugin_redmine_wktime['wktime_margin_left'].to_i
    bottom_margin = Setting.plugin_redmine_wktime['wktime_margin_bottom'].to_i
    top_margin = Setting.plugin_redmine_wktime['wktime_margin_top'].to_i
    col_id_width  = 10
    row_height    = Setting.plugin_redmine_wktime['wktime_line_space'].to_i
    logo    = Setting.plugin_redmine_wktime['wktime_header_logo']

    if page_height == 0
      page_height = 297
    end
    if page_width == 0
      page_width  = 210
    end
    if right_margin == 0
      right_margin = 10
    end
    if left_margin == 0
      left_margin = 10
    end
    if bottom_margin == 0
      bottom_margin = 20
    end
    if top_margin == 0
      top_margin = 20
    end
    if row_height == 0
      row_height = 4
    end

    # column widths
    table_width = page_width - right_margin - left_margin

    columns = ["#",l(:field_project), l(:field_issue), l(:field_activity)]


    col_width = []
    orientation = "P"
    unit=nil
    # 20% for project, 60% for issue, 20% for activity
    col_width[0]=col_id_width
    col_width[1] = (table_width - (8*10))*0.2
    col_width[2] = (table_width - (8*10))*0.6
    col_width[3] = (table_width - (8*10))*0.2
    title=l(:label_wktime)
    if !unitLabel.blank?
      columns << l(:label_wk_currency)
      col_id_width  = 14
      col_width[0]=col_id_width
      col_width[1] = (table_width - (8*14))*0.20
      col_width[2] = (table_width - (8*14))*0.45
      col_width[3] = (table_width - (8*14))*0.15
      col_width[4] = (table_width - (8*14))*0.20
      title= l(:label_wkexpense)
    end

    set_cf_header(columns, col_width, 'wktime_enter_cf_in_row1')
    set_cf_header(columns, col_width, 'wktime_enter_cf_in_row2')

    hoursIndex = columns.size
    startOfWeek = getStartOfWeek
    for i in 0..6
      #Martin Dube contribution: 'start of the week' configuration
      columns << l('date.abbr_day_names')[(i+startOfWeek)%7] + "\n" + (startday+i).mon().to_s() + "/" + (startday+i).day().to_s()
      col_width << col_id_width
    end

    #Landscape / Potrait
    if(table_width > 220)
      orientation = "L"
    else
      orientation = "P"
    end

    pdf = ITCPDF.new(current_language)

    pdf.SetTitle(title)
    pdf.alias_nb_pages
    pdf.footer_date = format_date(Date.today)
    pdf.SetAutoPageBreak(false)
    pdf.AddPage(orientation)

    if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
      pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-10-20, 10)
    end

    render_header(pdf, entries, user, startday, row_height,title)

    pdf.Ln
    render_table_header(pdf, columns, col_width, row_height, table_width)

    weeklyHash = getWeeklyView(entries, unitLabel, true)
    col_values = []
    matrix_values = []
    totals = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
    grand_total = 0.0
    j = 0
    base_x = pdf.GetX
    base_y = pdf.GetY
    max_height = row_height

    weeklyHash.each do |key, matrix|
      matrix_values, j = getColumnValues(matrix, totals, unitLabel,true, j)
      col_values = matrix_values[0]
      base_x = pdf.GetX
      base_y = pdf.GetY
      pdf.SetY(2 * page_height)

      #write once to get the height
      max_height = wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
      #reset the x and y
      pdf.SetXY(base_x, base_y)

      # make new page if it doesn't fit on the current one
      space_left = page_height - base_y - bottom_margin
      if max_height > space_left
        render_newpage(pdf,orientation,logo,page_width)
        render_table_header(pdf, columns, col_width, row_height,  table_width)
        base_x = pdf.GetX
        base_y = pdf.GetY
      end

      # write the cells on page
      wktime_to_pdf_write_cells(pdf, col_values, col_width, row_height)
      issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, 0, col_width)
      pdf.SetY(base_y + max_height);
      if !unitLabel.blank?
        unit=matrix_values[0][4]
      end
    end

    total_values = getTotalValues(totals,hoursIndex,unit)

    #write total
    #write an empty id

    max_height = wktime_to_pdf_write_cells(pdf, total_values, col_width, row_height)

    pdf.SetY(pdf.GetY + max_height);
    pdf.SetXY(pdf.GetX, pdf.GetY)

    render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
    pdf.Output
  end

  # Renders MultiCells and returns the maximum height used
  def wktime_to_pdf_write_cells(pdf, col_values, col_widths,
                                row_height)
    base_y = pdf.GetY
    max_height = row_height
    col_values.each_with_index do |val, i|
      col_x = pdf.GetX
      pdf.RDMMultiCell(col_widths[i], row_height, val, "T", 'L', 1)
      max_height = (pdf.GetY - base_y) if (pdf.GetY - base_y) > max_height
      pdf.SetXY(col_x + col_widths[i], base_y);
    end
    return max_height
  end
  #new page logo
  def render_newpage(pdf,orientation,logo,page_width)
    pdf.AddPage(orientation)
    if !logo.blank? && (File.exist? (Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo))
      pdf.Image(Redmine::Plugin.public_directory + "/redmine_wktime/images/" + logo, page_width-10-20, 10)
      pdf.Ln
      pdf.SetY(pdf.GetY+10)
    end
  end

  def getKey(entry,unitLabel)
    cf_in_row1_value = nil
    cf_in_row2_value = nil
    if entry.work_location.present? || entry.flexioff_reason.present?
      key = entry.project.id.to_s + (entry.issue.blank? ? '' : entry.issue.id.to_s) +(entry.work_location.nil? ? '' : entry.work_location)+(entry.flexioff_reason.nil? ? '' : entry.flexioff_reason) + entry.activity.id.to_s + (unitLabel.blank? ? '' : entry.currency)
    else
      key = entry.project.id.to_s + (entry.issue.blank? ? '' : entry.issue.id.to_s) + entry.activity.id.to_s + (unitLabel.blank? ? '' : entry.currency)
    end
    entry.custom_field_values.each do |custom_value|
      custom_field = custom_value.custom_field
      if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].blank? &&	Setting.plugin_redmine_wktime['wktime_enter_cf_in_row1'].to_i == custom_field.id)
        cf_in_row1_value = custom_value.to_s
      end
      if (!Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].blank? && Setting.plugin_redmine_wktime['wktime_enter_cf_in_row2'].to_i == custom_field.id)
        cf_in_row2_value = custom_value.to_s
      end
    end
    if (!cf_in_row1_value.blank?)
      key = key + cf_in_row1_value
    end
    if (!cf_in_row2_value.blank?)
      key = key + cf_in_row2_value
    end
    if (!Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].blank? && Setting.plugin_redmine_wktime['wktime_enter_comment_in_row'].to_i == 1)
      if(!entry.comments.blank?)
        key = key + entry.comments
      end
    end
    key
  end

  def getWeeklyView(entries, unitLabel, sumHours = false)
    weeklyHash = Hash.new
    prev_entry = nil
    entries.each do |entry|
      # If a project is deleted all its associated child table entries will get deleted except wk_expense_entries
      # So added !entry.project.blank? check to remove deleted projects
      if !entry.project.blank?
        key = getKey(entry,unitLabel)
        hourMatrix = weeklyHash[key]
        if hourMatrix.blank?
          #create a new matrix if not found
          hourMatrix =  []
          rows = []
          hourMatrix[0] = rows
          weeklyHash[key] = hourMatrix
        end

        #Martin Dube contribution: 'start of the week' configuration
        #wday returns 0 - 6, 0 is sunday
        startOfWeek = getStartOfWeek
        index = (entry.spent_on.wday+7-(startOfWeek))%7
        updated = false
        hourMatrix.each do |rows|
          if rows[index].blank?
            rows[index] = entry
            updated = true
            break
          else
            if sumHours
              tempEntry = rows[index]
              tempEntry.hours += entry.hours
              updated = true
              break
            end
          end
        end
        if !updated
          rows = []
          hourMatrix[hourMatrix.size] = rows
          rows[index] = entry
        end
      end
    end
    return weeklyHash
  end

  def getColumnValues(matrix, totals, unitLabel,rowNumberRequired, j=0)
    col_values = []
    matrix_values = []
    k=0
    unless matrix.blank?
      matrix.each do |rows|
        issueWritten = false
        col_values = []
        matrix_values << col_values
        hoursIndex = 3
        if rowNumberRequired
          col_values[0] = (j+1).to_s
          k=1
        end

        rows.each.with_index do |entry, i|
          unless entry.blank?
            if !issueWritten
              col_values[k] = entry.project.name
              col_values[k+1] = entry.issue.blank? ? "" : entry.issue.subject
              col_values[k+2] = entry.activity.name
              if !unitLabel.blank?
                col_values[k+3]= entry.currency
              end
              custom_field_values = entry.custom_field_values
              set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row1')
              set_cf_value(col_values, custom_field_values, 'wktime_enter_cf_in_row2')
              hoursIndex = col_values.size
              issueWritten = true
              j += 1
            end
            col_values[hoursIndex+i] =  (entry.hours.blank? ? "" : ("%.2f" % entry.hours.to_s))
            totals[i] += entry.hours unless entry.hours.blank?
          end
        end
      end
    end
    return matrix_values, j
  end

  def getTotalValues(totals, hoursIndex,unit)
    grand_total = 0.0
    totals.each { |t| grand_total += t }
    #project, issue, is blank, and then total
    total_values = []
    for i in 0..hoursIndex-2
      total_values << ""
    end
    total_values << "#{l(:label_total)} = #{unit} #{("%.2f" % grand_total)}"
    #concatenate two arrays
    total_values += totals.collect{ |t| "#{unit} #{("%.2f" % t.to_s)}"}
    return total_values
  end


  def render_table_header(pdf, columns, col_width, row_height, table_width)
    # headers
    pdf.SetFontStyle('B',8)
    pdf.SetFillColor(230, 230, 230)

    # render it background to find the max height used
    base_x = pdf.GetX
    base_y = pdf.GetY
    max_height = wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
    #pdf.Rect(base_x, base_y, table_width + col_id_width, max_height, 'FD');
    pdf.Rect(base_x, base_y, table_width, max_height, 'FD');
    pdf.SetXY(base_x, base_y);

    # write the cells on page
    wktime_to_pdf_write_cells(pdf, columns, col_width, row_height)
    issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height,0, col_width)
    pdf.SetY(base_y + max_height);

    # rows
    pdf.SetFontStyle('',8)
    pdf.SetFillColor(255, 255, 255)
  end

  def render_header(pdf, entries, user, startday, row_height,title)
    base_x = pdf.GetX
    base_y = pdf.GetY

    # title
    pdf.SetFontStyle('B',11)
    pdf.RDMCell(100,10, title)
    pdf.SetXY(base_x, pdf.GetY+row_height)

    render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_name), user.name)
    #render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:field_project), entries.blank? ? "" : entries[0].project.name)
    render_header_elements(pdf, base_x, pdf.GetY+row_height, l(:label_week), startday.to_s + " - " + (startday+6).to_s)
    render_customFields(pdf, base_x, user, startday, row_height)
    pdf.SetXY(base_x, pdf.GetY+row_height)
  end

  def render_customFields(pdf, base_x, user, startday, row_height)
    if !@wktime.blank? && !@wktime.custom_field_values.blank?
      @wktime.custom_field_values.each do |custom_value|
        render_header_elements(pdf, base_x, pdf.GetY+row_height,
                               custom_value.custom_field.name, custom_value.value)
      end
    end
  end

  def render_header_elements(pdf, x, y, element, value="")

    pdf.SetXY(x, y)
    unless element.blank?
      pdf.SetFontStyle('B',8)
      pdf.RDMCell(50,10, element)
      pdf.SetXY(x+40, y)
      pdf.RDMCell(10,10, ":")
      pdf.SetFontStyle('',8)
      pdf.SetXY(x+40+2, y)
    end
    pdf.RDMCell(50,10, value)

  end

  def render_signature(pdf, page_width, table_width, row_height,bottom_margin,page_height,orientation,logo)
    base_x = pdf.GetX
    base_y = pdf.GetY

    submissionAck   = Setting.plugin_redmine_wktime['wktime_submission_ack']

    unless submissionAck.blank?
      check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
      #pdf.SetY(base_y + row_height)
      #pdf.SetXY(base_x, pdf.GetY+row_height)
      #to wrap text and to put it in multi line use MultiCell
      pdf.RDMMultiCell(table_width,5, submissionAck)
      submissionAck= nil
    end
    check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)

    pdf.SetFontStyle('B',8)
    pdf.SetXY(page_width-90, pdf.GetY+row_height)
    pdf.RDMCell(50,10, l(:label_wk_signature) + " :")
    pdf.SetXY(page_width-90, pdf.GetY+(2*row_height))
    pdf.RDMCell(100,10, l(:label_wk_submitted_by) + " ________________________________")
    pdf.SetXY(page_width-90, pdf.GetY+ (2*row_height))
    pdf.RDMCell(100,10, l(:label_wk_approved_by) + " ________________________________")
  end
  #check_render_newpage
  def check_render_newpage(pdf,page_height,row_height,bottom_margin,submissionAck,orientation,logo,page_width)
    base_y = pdf.GetY
    if(!submissionAck.blank?)
      space_left = page_height - (base_y+(7*row_height)) - bottom_margin
    else
      space_left = page_height - (base_y+(5*row_height)) - bottom_margin
    end
    if(space_left<0)
      render_newpage(pdf,orientation,logo,page_width)
    end
  end
  def set_cf_header(columns, col_width, setting_name)
    cf_value = nil
    if !Setting.plugin_redmine_wktime[setting_name].blank? && !@new_custom_field_values.blank? &&
        (cf_value = @new_custom_field_values.detect { |cfv|
          cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil

      columns << cf_value.custom_field.name
      unless col_width.blank?
        old_total = 0
        new_total = 0
        for i in 0..col_width.size-1
          old_total += col_width[i]
          if i == 1
            col_width[i] -= col_width[i]*10/100
          else
            col_width[i] -= col_width[i]*20/100
          end
          new_total += col_width[i]
        end
        # reset width 15% for project, 55% for issue, 15% for activity
        #col_width[0] *= 0.75
        #col_width[1] *= 0.9
        #col_width[2] *= 0.75

        col_width << old_total - new_total
      end
    end
  end

  def set_cf_value(col_values, custom_field_values, setting_name)
    cf_value = nil
    if !Setting.plugin_redmine_wktime[setting_name].blank? &&
        (cf_value = custom_field_values.detect { |cfv|
          cfv.custom_field.id == Setting.plugin_redmine_wktime[setting_name].to_i }) != nil
      col_values << cf_value.value
    end
  end

  def getTimeEntryStatus(spent_on,user_id)
    result = Wktime.find(:all, :conditions => [ 'begin_date = ? AND user_id = ?', getStartDay(spent_on), user_id])
    return result[0].blank? ? 'n' : result[0].status
  end

  def time_expense_tabs
    tabs = [
        {:name => 'wktime', :partial => 'wktime/tab_content', :label => :label_wktime},
        {:name => 'wkexpense', :partial => 'wktime/tab_content', :label => :label_wkexpense}
    ]
  end

  #change the date to first day of week
  def getStartDay(date)
    startOfWeek = getStartOfWeek
    #Martin Dube contribution: 'start of the week' configuration
    unless date.nil?
      #the day of calendar week (0-6, Sunday is 0)
      dayfirst_diff = (date.wday+7) - (startOfWeek)
      date -= (dayfirst_diff%7)
    end
    date
  end

  #Code snippet taken from application_helper.rb  - include_calendar_headers_tags method
  def getStartOfWeek
    start_of_week = Setting.start_of_week
    start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?
    start_of_week = start_of_week.to_i % 7
  end

  def sendNonSubmissionMail
    startDate = getStartDay(Date.today)
    deadline = Date.today
    #No. of working days between startOfWeek and submissionDeadline
    diff = working_days(startDate,deadline + 1)
    countOfWorkingDays = 7 - (Setting.non_working_week_days).size
    if diff != countOfWorkingDays
      startDate = startDate-7
    end

    queryStr =  "select distinct u.* from projects p" +
        " inner join members m on p.id = m.project_id and p.status not in (#{Project::STATUS_CLOSED},#{Project::STATUS_ARCHIVED})"  +
        " inner join member_roles mr on m.id = mr.member_id" +
        " inner join roles r on mr.role_id = r.id and r.permissions like '%:log_time%'" +
        " inner join users u on m.user_id = u.id" +
        " left outer join wktimes w on u.id = w.user_id and w.begin_date = '" + startDate.to_s + "'" +
        " where (w.status is null or w.status = 'n')"

    users = User.find_by_sql(queryStr)
    users.each do |user|
      WkMailer.nonSubmissionNotification(user,startDate).deliver
    end
  end


  def send_l1_non_approve_notification(user_id)
    user = User.where(:user_id=> user_id).last
    body +="\n #{l(:field_name)} : #{user.firstname} #{user.lastname} \n #{total}"
    body +="\n #{l(:label_wk_rejected_days)} : #{dates}"
    body +="\n #{l(:label_wk_rejectedby)} : #{current_user.firstname} #{current_user.lastname}"
    body +="\n #{l(:label_wk_rejectedon)} : #{set_time_zone(Time.now)}"
    body +="\n"
    mail :from => current_user.mail,:to => user.mail, :subject => subject,:body => body
    mail :from => Setting.mail_from ,:to => user.mail, :subject => subject,:body => body
  end

  # check the log duration days includes any weekends if exists than we go for a previous day
  def confirm_with_weekends(dead_line, log_duration, today)
    range = dead_line...today
    range.collect do |day|
      if day.wday == 6 || day.wday == 0
        log_duration = log_duration.to_i + 1
      end
    end
    day = (today - 1 - log_duration.to_i).wday
    if day == 0 || day == 6
      log_duration = log_duration.to_i + 1
    end
    return log_duration, day
  end

  # check the log duration days includes any holidays if exists than we go for a previous day
  def confirm_with_holidays(log_duration, dead_line, today, holidays)
    weekend = []
    new_range = ((today - 1 - log_duration.to_i)...today)
    new_range.each {|d| weekend << d if d.wday == 6 || d.wday==0}
    week_holidays = []
    new_range.each do|weekday|
      holidays.each { |day| week_holidays << day if day.to_date ==weekday.to_date }
    end
    final_dead_line =  dead_line - weekend.size - week_holidays.size
    holidays_list = holidays.include? (Date.today).strftime '%Y-%m-%d'
    return final_dead_line, holidays_list
  end


  #Update the record if user TimeEntry is not exist in the day.
  def lock_user_timesheet(today, final_dead_line, holidays_list, day)
    nonloged_users = []
    if today.wday != 6 || today.wday != 0 || holidays_list
      if !day === today.strftime('%Y-%m-%d') || today.wday != 6 || today.wday != 0
        User.active.all.collect do |user|
          # other_entries = TimeEntry.where(:user_id=> user.id).where("spent_on > ? ", (final_dead_line-30).strftime('%Y-%m-%d'))
          rec = TimeEntry.where(:user_id=> user.id, :spent_on => final_dead_line)
          if rec == []
            nonloged_users << user
          end
        end
        nonloged_users.collect do |user|
          #LockUserEntry.create(:user_id => user.id, :due_date => final_dead_line.to_datetime, :lock => true)
          log_rec = LockUserEntry.find_or_create_by_user_id_and_due_date(:user_id=> user.id,:due_date=>final_dead_line)
          log_rec.update_attributes(:lock=>true)
          WkMailer.missingLogNotification(user,final_dead_line).deliver
        end
      end
    end
  end


  def getDateSqlString(dtfield)
    startOfWeek = getStartOfWeek
    # postgre doesn't have the weekday function
    # The day of the week (0 - 6; Sunday is 0)
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      sqlStr = dtfield + " - ((cast(extract(dow from " + dtfield + ") as integer)+7-" + startOfWeek.to_s + ")%7)"
    elsif ActiveRecord::Base.connection.adapter_name == 'SQLite'
      sqlStr = "date(" + dtfield  + " , '-' || ((strftime('%w', " + dtfield + ")+7-" + startOfWeek.to_s + ")%7) || ' days')"
    elsif ActiveRecord::Base.connection.adapter_name == 'SQLServer'
      sqlStr = "DateAdd(d, (((((DATEPART(dw," + dtfield + ")-1)%7)-1)+(8-" + startOfWeek.to_s + ")) % 7)*-1," + dtfield + ")"
    else
      # mysql - the weekday index for date (0 = Monday, 1 = Tuesday, � 6 = Sunday)
      sqlStr = "adddate(" + dtfield + ",mod(weekday(" + dtfield + ")+(8-" + startOfWeek.to_s + "),7)*-1)"
    end
    sqlStr
  end

  def getHostAndDir(req)
    "#{req.url}".gsub("#{req.path_info}","").gsub("#{req.protocol}","")
  end

  def getNonWorkingDayColumn(startDate)
    startOfWeek = getStartOfWeek
    ndays = Setting.non_working_week_days
    columns =''
    ndays.each do |day|
      columns << ',' if !columns.blank?
      columns << ((((day.to_i +7) - startOfWeek ) % 7) + 1).to_s
    end
    publicHolidayColumn = getPublicHolidayColumn(startDate)
    publicHolidayColumn = publicHolidayColumn.join(',') if !publicHolidayColumn.nil?
    columns << ","  if !publicHolidayColumn.blank? && !columns.blank?
    columns << publicHolidayColumn if !publicHolidayColumn.blank?
    columns
  end

  def settings_tabs
    tabs = [
        {:name => 'general', :partial => 'settings/tab_general', :label => :label_general},
        {:name => 'display', :partial => 'settings/tab_display', :label => :label_display},
        {:name => 'wktime', :partial => 'settings/tab_time', :label => :label_wktime},
        {:name => 'wkexpense', :partial => 'settings/tab_expense', :label => :label_wkexpense},
        {:name => 'approval', :partial => 'settings/tab_approval', :label => :label_wk_approval_system},
        {:name => 'publicHoliday', :partial => 'settings/tab_holidays', :label => :label_wk_public_holiday}
    ]
  end

  def getPublicHolidays()
    holidays = nil
    publicHolidayList = Setting.plugin_redmine_wktime['wktime_public_holiday']
    if !publicHolidayList.blank?
      holidays = Array.new
      publicHolidayList.each do |holiday|
        holidays << holiday.split('|')[0].strip rescue nil
      end
    end
    holidays
  end

  def checkHoliday(timeEntryDate,publicHolidays)
    isHoliday = false
    if !publicHolidays.nil?
      isHoliday = true if publicHolidays.include? timeEntryDate
    end
    isHoliday
  end

  def getPublicHolidayColumn(date)
    columns =nil
    startDate = getStartDay(date.to_date)
    publicHolidays = getPublicHolidays()
    if !publicHolidays.nil?
      columns = Array.new
      for i in 0..6
        columns << (i+1).to_s if checkHoliday((startDate.to_date + i).to_s,publicHolidays)
      end
    end
    columns
  end

  # Returns week day of public holiday
  # mon - sun --> 1 - 7
  def getWdayForPublicHday(startDate)
    pHdays = getPublicHolidays()
    wDayOfPublicHoliday = Array.new
    if !pHdays.blank?
      for i in 0..6
        wDayOfPublicHoliday << ((startDate+i).cwday).to_s if checkHoliday((startDate + i).to_s,pHdays)
      end
    end
    wDayOfPublicHoliday
  end

  def checkViewPermission
    ret =  false
    if User.current.logged?
      viewProjects = Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :view_time_entries ))
      loggableProjects ||= Project.find(:all, :conditions => Project.allowed_to_condition(User.current, :log_time))
      ret = (!viewProjects.blank? && viewProjects.size > 0) || (!loggableProjects.blank? && loggableProjects.size > 0)
    end
    ret
  end

  def is_number(val)
    true if Float(val) rescue false
  end


  # Lock Unlocking Methods And L1 L2 approval

  def lock_unlock_users
    @unlocks = LockUserEntry.where(:lock=>false)
    if @unlocks.present?
      @unlocks.each do |unlock_rec|
        find_rec = TimeEntry.where(:user_id=> unlock_rec.user_id, :spent_on => unlock_rec.due_date)
        if !find_rec.present?
          unlock_rec.update_attributes(:lock=> true)
        else
          unlock_rec.delete
        end
      end
    end
  end
  def user_permission_list(projects)
    project = projects.last.member_principals.find_by_user_id(User.current.id)
    if project.present?
      project.member_roles.last.role.permissions
    else
      []
    end
  end


# check permissions for L1 and L1 Approval
  def check_permission_list(l,first_entry)
    @user = User.current
    log_projects = Project.find(:all, :order => 'name',:conditions => Project.allowed_to_condition(@user, :log_time))

    members = []
    permissions = []
    log_projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  }
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end

    if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
      return true
    else
      return false
    end

    p '----'

  end

  # check other manager accpet the log hours
  def check_other_projects(rec, role)
    members = []
    permissions = []

    project = Project.find(rec.project_id)
    members << project.member_principals.find_by_user_id(User.current.id)
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    wk = Wktime.where(:project_id => project.id, :statusupdater_id => User.current.id)
    if permissions.flatten.present? && permissions.flatten.include?(role)
      return true
    else
      return false
    end
  end

# check L2 status for the day
  def check_l2_status(user_id,date)
    status_l2 =Wktime.where(:user_id=>user_id,:begin_date=>date,:status=>'l2')
    l2_entry = TimeEntry.where(:spent_on=> date,:user_id=>user_id)
    if  status_l2.present?
      return true
    else
      return false
    end
  end

# check time log entry for the day
#   def check_time_log_entry(select_time,current_user)
#     days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
#     setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
#     setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
#     current_time = set_time_zone(Time.now)
#     expire_time = return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
#     #deadline_date = (Date.today-days.to_i).strftime('%Y-%m-%d').to_date
#     date = UserUnlockEntry.dead_line
#
#    # p "+++++++++dead date +++++"
#    #  p date
#    #  p "+++++++++++"
#     if date.present?
#       deadline_date = date.to_date.strftime('%Y-%m-%d').to_date
#     end
#     lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
#     if lock_status.present?
#       lock_status_expire_time = lock_status.last.expire_time
#       if lock_status_expire_time.to_date <= expire_time.to_date
#         lock_status.delete_all
#       end
#     end
#     entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
#     #lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
#     permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
#     p "++++++++deadline_date++++++"
#     p deadline_date
#     p "+++++++++++++selec"
#     p select_time.to_date
#     p "++++++++expire+++++++"
#     p expire_time
#     p "++++++current++"
#     p current_time
#     p "+++++++++++end ++++++++++++"
#     if (select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)
#       return true
#     elsif (select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)
#       return true
#     else
#       return false
#     end
#   end

  def check_time_log_entry(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    if lock_status.present?
      lock_status_expire_time = lock_status.last.expire_time
      if lock_status_expire_time.to_date <= expire_time.to_date
        lock_status.delete_all
      end
    end
    entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
    wiki_status_l1=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l1")
    wiki_status_l2=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l2")
    wiki_status_l3=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l3")
    permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
    if ((select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)) && (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)
      return true
    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)) && ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))
      return true
    else
      return false
    end

  end


  def check_week_log_entry(select_time,current_user, wk)
    result = []
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
  p  expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
     lock_status1 = UserUnlockEntry.where(:user_id=>current_user.id)
  p  expire_time.to_date
    if lock_status1.present?
      lock_status_expire_time = lock_status1.last.expire_time
      if lock_status_expire_time.to_date <= expire_time.to_date
        lock_status1.delete_all
      end
    end
   
    permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
    #wk = Wktime.find_by_sql("select status from wktimes where user_id=#{current_user.id} and DATE(begin_date)=#{select_time.strftime("%Y-%m-%d")}").map(&:status).last
    time1 = Time.now
# p    wk = Wktime.where(:user_id=>current_user.id,:begin_date=>select_time).group('begin_date').order('begin_date').map{|x|[x.begin_date, x.status]}
    p '=====time==='
    p Time.now-time1
    p '===========dsoo============='
    p wk
     select_time.each do |date|
      color_status = ''
      state = wk.select{ |date1, state|  state  if date1.to_date == date   }
      if state.present?
        status = state.flatten.last
      else
        status = 'n'
      end

      # wkt = wk.find_by_begin_date(date)
      # if wkt.present?
      #   status = wkt.status
      # else
      #   status = 'n'
      # end
   
      lock_status =  check_toady_wk_status(permanent_unlock,date,deadline_date,expire_time,current_time,lock_status1,status)
      if !lock_status.present? && lock_status == false
        color_status = ['background-color:gray', true]
      else
        color_status = [ '',false]
      end

      case status
        when 'l1'
          color_status = ['background-color:#D8D830', true]
        when 'l2'
          color_status = ['background-color:#ff9900', true]
        when 'l3'
          color_status = ['background-color:#6EC16E',true]
        when 'r'
          color_status = [ 'background-color:#FF5959',false]
        # else
        #   color_status = [ '',false]
      end if status.present?
      result << color_status
    end
    # p cod1 = (select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present?
    # p cod2 = ( permanent_unlock.present? && permanent_unlock.last.status == true)
    #
    # p cod4 = wk.present? && (wk.status=='n' || wk.status=='r')
    # p [ (cod1 || cod2), cod4 && (cod1 || cod2)]
    # case wk
    #   when !cod4 && (cod1 || cod2)
    #     true
    #   when cod4 && (cod1 || cod2)
    #     true
    #   else
    #     false
    # end

# true
# if ((select_time.to_date > deadline_date.to_date || lock_status.present?) ||
#     ( permanent_unlock.present? && permanent_unlock.last.status == true)) &&
#     (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)
#
#   return true
#
# elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) ||
#     lock_status.present? ||
#     (permanent_unlock.present? && permanent_unlock.last.status == true)) &&
#     ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))
#
#   return true
# else
#
#   return false
# end
    p result
    return result
  end

  def check_toady_wk_status(permanent_unlock,select_time,deadline_date,expire_time,current_time,lock_status,status)
    if ((select_time.to_date > deadline_date.to_date || lock_status.present?) || ( permanent_unlock.present? && permanent_unlock.last.status == true)) && (status=='r' || status=='n')
      return true
    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? || (permanent_unlock.present? && permanent_unlock.last.status == true)) && (status=='r' || status=='n')
      return true
    else
      return false
    end
  end


  def check_time_log_entry_payroll(select_time)
    days = 0
    setting_hr= Setting.plugin_redmine_wktime['wktime_payroll_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_payroll_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    # week_current_time = wktime_helper.set_time_zone(Time.now)
    # week_day = DateTime.parse(Setting.plugin_redmine_wktime['wktime_payroll_day'])
    week_day = Date.new(Date.today.year,Date.today.month,Setting.plugin_redmine_wktime['wktime_payroll_day'].to_i)

    # week_expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    expire_time = wktime_helper.return_time_zone.parse("#{week_day.year}-#{week_day.month}-#{week_day.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method_l2
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end



    if  expire_time > current_time

      return true
    else

      return false
    end

  end


  def check_expire_date_payroll
    days = 0
    setting_hr= Setting.plugin_redmine_wktime['wktime_payroll_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_payroll_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    # week_current_time = wktime_helper.set_time_zone(Time.now)
    # week_day = DateTime.parse(Setting.plugin_redmine_wktime['wktime_payroll_day'])
    week_day = Date.new(Date.today.year,Date.today.month,Setting.plugin_redmine_wktime['wktime_payroll_day'].to_i)

    # week_expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    expire_time = wktime_helper.return_time_zone.parse("#{week_day.year}-#{week_day.month}-#{week_day.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method_l2
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end

    return expire_time

  end

  def check_expire_date_payroll_notification
    days = 0
    setting_hr= Setting.plugin_redmine_wktime['wktime_payroll_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_payroll_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    # week_current_time = wktime_helper.set_time_zone(Time.now)
    # week_day = DateTime.parse(Setting.plugin_redmine_wktime['wktime_payroll_day'])
    week_day = Date.new(Date.today.year,Date.today.month,Setting.plugin_redmine_wktime['wktime_payroll_day'].to_i)

    # week_expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    expire_time = wktime_helper.return_time_zone.parse("#{week_day.year}-#{week_day.month}-#{week_day.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method_l2
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end

    return (expire_time-2.days)

  end






  def check_time_log_entry_l1(select_time)
    days = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l1'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l1'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l1'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method_l1
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end



    if ((select_time.to_date > deadline_date.to_date ) )

      return true

    elsif (select_time.to_date == deadline_date.to_date && expire_time > current_time)

      return true
    else

      return false
    end

  end



  def check_time_log_entry_l2(select_time)
    days = 0
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l2'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l2'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    # week_current_time = wktime_helper.set_time_zone(Time.now)
    week_day = DateTime.parse(Setting.plugin_redmine_wktime['wktime_nonapprove_day_l2'])
    p "++++++++=week_day+++++++++"
    p week_day
    p "++++++++++++"
    # week_expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    expire_time = wktime_helper.return_time_zone.parse("#{week_day.year}-#{week_day.month}-#{week_day.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method_l2
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end



    if  expire_time > current_time

      return true
    else

      return false
    end

  end


  def check_time_log_entry_l3(select_time)
    days = 0
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l3'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l3'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    # week_current_time = wktime_helper.set_time_zone(Time.now)
    week_day = DateTime.parse(Setting.plugin_redmine_wktime['wktime_nonapprove_day_l3'])
    p "++++++++=week_day+++++++++"
    p week_day
    p "++++++++++++"
    # week_expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")

    expire_time = wktime_helper.return_time_zone.parse("#{week_day.year}-#{week_day.month}-#{week_day.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end



    if  expire_time > current_time

      return true
    else

      return false
    end

  end

  def check_time_log_entry_for_approve(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    #current_time = Time.now
    #expire_time = Time.new(current_time.year, current_time.month, current_time.day,setting_hr,setting_min,1, "+05:30")
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    # deadline_date = (current_time.to_date-days.to_i).strftime('%Y-%m-%d').to_date
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      #date = date - days.to_i
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    # lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    # if lock_status.present?
    #   lock_status_expire_time = lock_status.last.expire_time
    #   if lock_status_expire_time.to_date <= expire_time.to_date
    #     lock_status.delete_all
    #   end
    # end
    entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
    wiki_status_l1=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l1")
    wiki_status_l2=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l2")
    wiki_status_l3=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l3")
    #lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    # permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)
    if ((select_time.to_date > deadline_date.to_date )) && (!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?)

      return true

    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) ) && ((!wiki_status_l1.present? && !wiki_status_l2.present? && !wiki_status_l3.present?))

      return true
    else

      return false
    end

  end



# check l1 status for the week
  def check_l1_status_for_week(select_time,user)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l1_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l1_date  = Wktime.where(begin_date: day,status: "l1",:user_id=>user)
        if l1_date.present?
          l1_dates << day
        end
      end
    end
    if l1_dates.present?
      return true
    else
      return  false
    end
  end
# check working days for the week

  def check_work_days_for_week(select_time,user)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l1_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l1_date  = TimeEntry.where(spent_on: day,:user_id=>user)
        if l1_date.present?
          l1_dates << day
        end
      end
    end
    if l1_dates.present?
      return true
    else
      return  false
    end
  end
# check l2 status for week; Note : We drop this method due to performance to hit the wktime in a loop
  def check_l2_status_for_week(select_time,user, role)
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l2_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l2_date  = Wktime.where(begin_date: day,status: role,:user_id=>user)
        if l2_date.present?
          l2_dates << day
        end
      end
    end
    #status = Wktime.where(begin_date: startday..end_day,status: "l1",:user_id=>user)
    if l2_dates.present? && work_days.present? && l2_dates.count >=work_days.count
      return true
    else
      return  false
    end
  end


  # Performance issue fixed and got input of l2 & L3 as params based on this we check the condition
  def check_l2_status_for_week_with_value(select_time, l2_data)
     p '===dadsa======'
    p l2_date = l2_data.map {|el| el[1]}
    startday = select_time.to_date
    end_day = (select_time.to_date + 6)
    work_days = []
    l2_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l2_data
        #l2_date  = Wktime.where(begin_date: day,status: role,:user_id=>user)
        if l2_date.include?(day.strftime('%Y-%m-%d'))
          l2_dates << day
        end
      end
    end
    #status = Wktime.where(begin_date: startday..end_day,status: "l1",:user_id=>user)
    if l2_dates.present? && work_days.present? && l2_dates.count >=work_days.count
      return true
    else
      return  false
    end
  end

  def check_time_entry_for_week(select_time,user)
    startday = select_time.to_date
    check_status=[]
    end_day = (startday+6)
    (startday..end_day).each do |day|
      #status = check_time_log_entry(day,user)
      date1_time_entry = TimeEntry.where(:spent_on=> day.to_date,:user_id=>user)
      if date1_time_entry.present?
        check_status << true
      else
        check_status << false
      end
    end
    if check_status.present? &&  !check_status.include?(false)
      return true
    end

  end


  def check_lock_status_for_week(startday,id)
    user = User.where(:id=>id).last
    check_status=[]
    end_day = (startday+6)
    (startday..end_day).each do |day|
      status = check_time_log_entry(day,user)
      check_status << status
    end
    if check_status.present? && !check_status.include?(false)
      return true
    end
  end


  def set_time_zone(time)
    return_time_zone
    Time.zone.at(time)
  end
  def return_time_zone
    current_zone = User.current.pref.time_zone.present? ? User.current.pref.time_zone :  "Chennai"
    Time.zone = current_zone
    Time.zone
  end

# L3 approval

  def check_permission_list_project_id(l,project_2)

    project = Project.where(id:project_2).last if project_2.present?
    logtime_projects = User.current.roles_for_project(project)
    if project.present? && logtime_projects.present?
      if (l == "l1")
        check_l1 = logtime_projects.last.permissions.include? l.to_sym
        check_l2 = logtime_projects.last.permissions.include? "l2".to_sym
        if check_l1.present? && !check_l2.present?
          return true
        end
      elsif(l == "l2")
        if logtime_projects.last.permissions.include? l.to_sym
          return true
        end
      elsif(l == "l3")
        if logtime_projects.last.permissions.include? l.to_sym
          return true
        end
      end
    else
    end
  end

  def getStartOfMonth(date)
    week_day = date.strftime("%w").to_i

    # start_of_week = Setting.start_of_week
    # start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?
    # start_of_week = start_of_week.to_i % 30
    return week_day
  end

  def getMonthlyView(entries, unitLabel, sumHours = false,end_date)
    weeklyHash = Hash.new
    prev_entry = nil
    entries.each do |entry|

      # If a project is deleted all its associated child table entries will get deleted except wk_expense_entries
      # So added !entry.project.blank? check to remove deleted projects
      if !entry.project.blank?

        key = getKey(entry,unitLabel) rescue nil

        hourMatrix = weeklyHash[key]

        if hourMatrix.blank?
          #create a new matrix if not found
          hourMatrix =  []
          rows = []
          hourMatrix[0] = rows
          weeklyHash[key] = hourMatrix
        end

        #Martin Dube contribution: 'start of the week' configuration
        #wday returns 0 - 6, 0 is sunday
        startOfWeek = getStartOfWeek

        # index = (entry.spent_on.wday+7-(startOfWeek))%7
        index = (entry.spent_on.to_date - end_date.to_date).to_i
        updated = false
        hourMatrix.each do |rows|
          if rows[index].blank?
            rows[index] = entry
            updated = true
            break
          else
            if sumHours
              tempEntry = rows[index]
              tempEntry.hours += entry.hours
              updated = true
              break
            end
          end
        end
        if !updated
          rows = []
          hourMatrix[hourMatrix.size] = rows
          rows[index] = entry
        end
      end
    end
    return weeklyHash
  end


  def check_l3_status_for_month_project(select_time,user,project_id,startday,end_day)
    # startday = select_time.to_date.beginning_of_month
    # end_day = select_time.to_date.end_of_month
    work_days = []
    l3_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l3_date  = Wktime.where(begin_date: day,status: "l3",:user_id=>user,:project_id=> project_id)
        if l3_date.present?
          l3_dates << day
        end
      end
    end
    # if l3_dates.present? && l3_dates.count >= work_days.count
    #   return true
    # else
    #   return  false
    # end
    if l3_dates.present? && l3_dates.count >= 1 && l3_dates.count != work_days.count
      return "true_false"
    elsif l3_dates.present? && l3_dates.count == work_days.count
      return  true
    else
      return false
    end
  end

  def check_box_status(user,project_id,startday,end_day)
    approve_l2_dates = Wktime.where(begin_date: (startday..end_day),status: "l2",:user_id=>user,:project_id=> project_id)
    approve_l3_dates = Wktime.where(begin_date: (startday..end_day),status: "l3",:user_id=>user,:project_id=> project_id)
    if approve_l2_dates.present? && approve_l2_dates.count == ((end_day-startday).to_i + 1)
      return "home_l2"
    elsif approve_l3_dates.present? && approve_l3_dates.count == ((end_day-startday).to_i + 1)
      return "l3"
    end
  end

  def check_box_status_with_group(user,project_id,startday,end_day)
    approve_l2_dates = Wktime.where(begin_date: (startday..end_day),status: "l2",:user_id=>user)
    approve_l3_dates = Wktime.where(begin_date: (startday..end_day),status: "l3",:user_id=>user)
    if approve_l2_dates.present? && approve_l2_dates.count == ((end_day-startday).to_i + 1)
      return "home_l2"
    elsif approve_l3_dates.present? && approve_l3_dates.count == ((end_day-startday).to_i + 1)
      return "l3"
    end
  end

  def check_l2_status_for_month_project(select_time,user,project_id,startday,end_day)
    work_days = (startday..end_day).count
    #l2_approve_count = []
    #(startday..end_day).each do |day|
      #if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      #else
        # work_days << day
        l2_date  = Wktime.where(begin_date: (startday..end_day),status: "l2",:user_id=>user,:project_id=> project_id)
        #if l2_date.present?
          l2_approve_count =  l2_date.count
        #end
      #end
    #end
    if l2_approve_count.present? && l2_approve_count >= 1 && l2_approve_count != work_days
      return "true_false"
    elsif l2_approve_count.present? && l2_approve_count == work_days
      return  true
    else
      return false
    end

  end


  def get_user_name(user_id)
    user = User.find(user_id)
    if user.present?
      return user.firstname
    end
  end

  def get_emp_id(user_id)
    user = User.find(user_id)
    # user.custom_field_values.each_with_index do |c,index|
    #   custom_field =CustomField.where(:id=>c.custom_field_id)
    #   if custom_field.present? && (custom_field.last.name=="Emp_code")
    #     p user.custom_field_values[index]
    #     p user.custom_field_values[index].to_s
    #   end
    # end
    if user.user_official_info.present? && user.user_official_info.employee_id.present?
        user.user_official_info.employee_id.to_s
    end

  end

  def check_l2_status_for_month(select_time,user)
    startday = select_time.to_date.beginning_of_month
    end_day = select_time.to_date.end_of_month
    work_days = []
    l2_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l2_date  = Wktime.where(begin_date: day,status: "l2",:user_id=>user)
        if l2_date.present?
          l2_dates << day
        end
      end
    end
    if l2_dates.present?
      return true
    else
      return  false
    end
  end
  def check_l3_status_for_month(select_time,user,project_id)
    startday = select_time.to_date.beginning_of_month
    end_day = select_time.to_date.end_of_month
    work_days = []
    l3_dates = []
    (startday..end_day).each do |day|
      if Setting.plugin_redmine_wktime['wktime_public_holiday'].present? && Setting.plugin_redmine_wktime['wktime_public_holiday'].include?(day.to_date.strftime('%Y-%m-%d').to_s) || (day.to_date.wday == 6) || (day.to_date.wday == 0)
      else
        work_days << day
        l3_date  = Wktime.where(begin_date: day,status: "l3",:user_id=>user,:project_id=> project_id)
        if l3_date.present?
          l3_dates << day
        end
      end
    end
    if l3_dates.present? && l3_dates.count >= work_days.count
      return true
    else
      return  false
    end
  end

  def check_project_permission(ids, l)
    projects = Project.find(ids)
    members = []
    permissions = []
    projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  } if projects.kind_of?(Array)
    members << projects.member_principals.find_by_user_id(User.current.id) if !projects.kind_of?(Array)
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
      return true
    else
      return false
    end
  end



  # def check_group_permission(ids, l)
  #   # projects = Project.find(ids)
  #   # members = []
  #   # permissions = []
  #   # projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  } if projects.kind_of?(Array)
  #   # members << projects.member_principals.find_by_user_id(User.current.id) if !projects.kind_of?(Array)
  #   # members.flatten.each do |rec|
  #   #   rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
  #   # end
  #   # if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
  #   #   return true
  #   # else
  #   #   return false
  #   # end
  #   return true
  # end

  def check_group_permission(ids, l)

p "+++++++++++++++++++++ids +++++++++++++="
    p ids
    p "+++++++++++++++++++end +++++++++++++++==="
      if ids.present?
        @group = Group.find(ids)
        if @group.present?
         if @group.users.present?
          if @group.users.map(&:id).include?(User.current.id)
            check_permission_sql =  "select u.login,r.permissions from users u
join members m on m.user_id=u.id
join member_roles mr on mr.member_id = m.id
join roles r on r.id= mr.role_id
where u.id=#{User.current.id}  and r.permissions like '%#{l}%'"
p "+++++++++++=check_permission_sql++++++++++++++++++"
            p check_permission_sql
            p "++++++++++++++++++end ++++++++++++++"
            permission = User.find_by_sql(check_permission_sql)
            if permission.present?

              return true
            end

          end

        end

      end

      end



    # projects = Project.find(ids)
    # members = []
    # permissions = []
    # projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  } if projects.kind_of?(Array)
    # members << projects.member_principals.find_by_user_id(User.current.id) if !projects.kind_of?(Array)
    # members.flatten.each do |rec|
    #   rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    # end
    # if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
    #   return true
    # else
    #   return false
    # end
  end

  def accessable_projects(ids, l)
    projects = Project.find(ids)
    ids = []
    members = []
    permissions = []
    projects.each { |project| members << project.member_principals.find_by_user_id(User.current.id)
    members.flatten.each do |rec1|
      rec1.member_roles.each { |rec| permissions << rec.role.permissions
      if permissions.flatten.present? && (permissions.flatten.include?(l.to_sym) || permissions.flatten.include?(l.to_sym))
        ids << project.id
      end
      } if rec1.present?
    end
    }
    ids
  end


  # def get_emmetric_hours(user_id,date)
  #   @user_emp_code=''
  #   user = User.find(user_id)
  #   user.custom_field_values.each_with_index do |c,index|
  #     custom_field =CustomField.where(:id=>c.custom_field_id)
  #     if custom_field.present? && (custom_field.last.name=="Emp_code")
  #       @user_emp_code = user.custom_field_values[index].to_s
  #     end
  #   end
  #   user_date = date.to_date.strftime('%d%m%Y')
  #   bio_user="inia"
  #   bio_password="4plgI}1P"
  #   url = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id="+@user_emp_code+";range=user;date-range="+user_date+"-"+user_date+";field-name=WORKTIME_HHMM;format=xml"
  #   #url1 = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id=1104;date-range=17112014-17112014;range=user;format=text"

  #   #url1 = "http://biometrics.objectfrontier.com/cosec/api.svc/attendance-daily?action=get;id=1104;date-range=17112014-17112014;field-name=WORKTIME_HHMM;range=user;format=xml"
  #   if @user_emp_code.present?
  #     response = RestClient::Request.new(:method => :get,:url => url,:user => bio_user,:password => bio_password).execute
  #     #response1 = RestClient::Request.new(:method => :get,:url => url1,:user => bio_user,:password => bio_password).execute
  #     nokogiri_xml1 =Nokogiri::HTML::Document.parse(response.body)

  #     if response.present?
  #       nokogiri_xml =Nokogiri::HTML::Document.parse(response.body)
  #       nokogiri_xml_attendance = nokogiri_xml.css('attendance-daily') if nokogiri_xml.present?
  #       nokogiri_xml_attendance.map(&:text)[0]
  #       result=nokogiri_xml_attendance.map(&:text)[0] if nokogiri_xml_attendance.map(&:text)[0].present?
  #       return result
  #     end
  #   end
  # end

  def get_biometric_hours_per_month(users,date,enddate,month_or_week)
    user_emp_code = []
     users = users.kind_of?(Array) ? users : [users]
     emp_info = Redmine::Plugin.registered_plugins.keys.include?(:employee_info)
     users.flatten.each do |user|
       if emp_info && user.user_official_info.present? && user.user_official_info.employee_id.present?
         user_emp_code << user.user_official_info.employee_id
       else
         user_emp_code << ""
       end
    #   user.custom_field_values.each_with_index do |c,index|
    #     custom_field =CustomField.where(:id=>c.custom_field_id)
    #     if custom_field.present? && (custom_field.last.name=="Emp_code")
    #       user_emp_code << user.custom_field_values[index].to_s
    #     end
    #   end
     end

    user_emp_code.delete('')
    user_emp_code.delete(0)
    user_emp_code = user_emp_code.uniq.join(",")
    if month_or_week == "from_to_end"
      start_date = date.to_date.strftime('%Y-%m-%d')
      end_date = enddate.to_date.strftime('%Y-%m-%d')
    elsif month_or_week=="week"
      start_date = date.to_date.strftime('%Y-%m-%d')
      end_date = (date + 6).to_date.strftime('%Y-%m-%d')
    end

    user_array = user_emp_code.split(',')
    my_arrays = {}
    result =[]
    # {}
    user_array = user_emp_code.split(',')
    my_arrays = {}
    result =[]

    if user_emp_code.present?
      key = Redmine::Configuration['iserv_api_key']
      url = Redmine::Configuration['iserv_base_url']
      # key = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB"
      url1 = "#{url}/services/employees/dailyattendance/#{user_emp_code}?fromDate=#{start_date}&toDate=#{end_date}"
      begin
      response = RestClient::Request.new(:method => :get,:url => url1, :headers => {:"Auth-key" => key},:verify_ssl => false).execute
      rescue
      end
      # raise
      user_array = user_emp_code.split(',')
      my_arrays = {}
      result =[]
      if !response.include?('failed') && !response.include?('No records found') && response.present?
        data = JSON.parse(response)
        user_array.each_with_index { |name, index| my_arrays[name] = {}   }
        if data['attendance-daily'].count > 1
          user_array.each_with_index  do |id, index|
            data['attendance-daily'].each do |rec|
              if rec['userid'] == id
                my_arrays[id].merge!(rec['processdate'] => rec['worktime_hhmm'])
              end
            end
          end
          p my_arrays
          return my_arrays
        else
          {}
        end
      end
    end
  end


  def all_users_get_biometric_hours_per_month(start_date,end_date)
    user_emp_code = []
    start_date = start_date.to_date.strftime('%Y-%m-%d')
    end_date = end_date.to_date.strftime('%Y-%m-%d')
    # if user_emp_code.present?
      key = Redmine::Configuration['iserv_api_key']
      url = Redmine::Configuration['iserv_base_url']
       url1 = "#{url}/services/employees/dailyattendance?fromDate=#{start_date}&toDate=#{end_date}"
      response = RestClient::Request.new(:method => :get,:url => url1, :headers => {:"Auth-key" => key},:verify_ssl => false).execute
      # raise
      my_arrays = {}
      data = JSON.parse(response)

  end



  def get_new_attendance(start_date,end_date)


    # @total_user_hours =  wktime_helper.all_users_get_biometric_hours_per_month(bio_user,@startday,@endday,"from_to_end")

    require 'writeexcel'
    wktime_helper = Object.new.extend(WktimeHelper)

    start_date1 =start_date.to_date.strftime("%F")
    end_date1 = end_date.to_date.strftime("%F")
    result1 = wktime_helper.all_users_get_biometric_hours_per_month(start_date1,end_date1)
    sql="call getAttendenceReport('#{start_date1}','#{end_date1}')"

    # sql="call getAllocationUsersReports('181','2056','2016-02-17','2016-03-01')"
    connection = ActiveRecord::Base.connection
    begin
      result = connection.select_all(sql)
    rescue NoMethodError
    ensure
      connection.reconnect! unless connection.active?
    end

    result2=[]
    result3=[]
    result1.present? && result1['attendance-daily'].each do |each_rec|



       if result.select {|h| h["day"].to_date.strftime("%F") == each_rec["processdate"].to_date.strftime("%F") && h["employee_id"].to_s == each_rec["userid"].to_s}.present?
        get_result = result.select {|h| h["day"].to_date.strftime("%F") == each_rec["processdate"].to_date.strftime("%F") && h["employee_id"].to_s == each_rec["userid"].to_s}.first
        get_result["bio_hours"]= each_rec["worktime_hhmm"]
        result2 << get_result
       else
         # check_valid_emp = is_employee_id_valid?(each_rec["userid"].to_i)
         if  check_valid_emp = is_employee_id_valid?(each_rec["userid"].to_i).present? && each_rec["userid"].to_i > 0
        s={}

        s["employee_id"]=each_rec["userid"].to_i
        s["day"]=each_rec["processdate"].to_date
        s["login"]=each_rec["username"]
        s["approval_status"]="n"
        s["spent_hours"]=0
        s["bio_hours"]=each_rec["worktime_hhmm"]
        s["department"]= get_department(each_rec["userid"].to_i)

        result3 << s
        end
      end

    end

    result = result3 + result2
    result= result.sort_by { |hsh| hsh["employee_id"].to_i }
    # start_date = Date.today-3
    # end_date = Date.today

    workbook = WriteExcel.new('ruby.xls')
    worksheet  = workbook.add_worksheet
    format = workbook.add_format
    format.set_bold
    format.set_color('red')
    format.set_align('right')

    spent_exced_format = workbook.add_format
    spent_exced_format.set_bold
    spent_exced_format.set_bg_color('orange')
    spent_exced_format.set_color('blue')
    format.set_align('right')

    spent_pto_format = workbook.add_format
    spent_pto_format.set_bold
    spent_pto_format.set_bg_color('yellow')
    spent_pto_format.set_color('blue')
    spent_pto_format.set_align('right')

    bio_format = workbook.add_format
    bio_format.set_color('red')
    bio_format.set_bold
    bio_format.set_align('right')

    worksheet.write(0,0,"User")
    worksheet.write(0,1,"Project Name")
    worksheet.write(0,2,"Client Name")
    worksheet.write(0,3,"Employee Id")
    worksheet.write(0,4,"Department")
    worksheet.write(0,5,"Approved Status")
    worksheet.write(0,6,"Approved By")
    # worksheet.write(0,6,"CL(Hours)")
    # worksheet.write(0,7,"PL(Hours)")
    # worksheet.write(0,8,"DL(Hours)")

    i=0

    format = workbook.add_format
    format.set_bold
    format.set_color('red')
    format.set_align('right')
    j=''

    a=(start_date1.to_date..end_date1.to_date).to_a+(start_date1.to_date..end_date1.to_date).to_a

    a.sort_by{|d| m,d,y=d.to_date.strftime("%F").split("-");[y,m,d]}.each_with_index do |each_result,index |

      worksheet.write(0,7+index,each_result.to_date.strftime("%d/%m/%Y"))
    end
    title_format = workbook.add_format
    format.set_bold
    format.set_align('left')
    format = workbook.add_format
    format.set_bold
    format.set_align('right')

    # worksheet.write(0,1,"PTO HOURS")
    worksheet.write(0,a.count+7,"PTO HOURS")
    worksheet.write(0,a.count+7+1,"Non Approve Hours")
    worksheet.write(0,a.count+7+2,"Flexi Off")
    worksheet.write(0,a.count+7+3,"CL(Hours)")
    worksheet.write(0,a.count+7+4,"PL(Hours)")
    worksheet.write(0,a.count+7+5,"DL(Hours)")



    k=0
    m=0
    result.each_with_index do |each_rec,index1|
      if index1==0
        k=index1
      end
      if each_rec["employee_id"]==j
        title_format = workbook.add_format
        title_format.set_bold
        title_format.set_align('left')
        worksheet.write(k,0,each_rec["login"],title_format)
        worksheet.write(k,1,each_rec["project_name"],title_format)
        worksheet.write(k,2,each_rec["client_name"],title_format)
        worksheet.write(k,3,each_rec["employee_id"],title_format)
        worksheet.write(k,4,each_rec["department"],title_format)
        worksheet.write(k,5,each_rec["approver_status"],title_format)
        worksheet.write(k,6,each_rec["approved_by"],title_format)

        worksheet.write(k,a.count+7,each_rec["pto_hours"].present? ? each_rec["pto_hours"].to_f.round(2) : "0",format )
        worksheet.write(k,a.count+7+1,each_rec["non_approve_hours"].present? ? each_rec["non_approve_hours"].to_f.round(2) : "0",format )
        worksheet.write(k,a.count+7+2,each_rec["flexi_off"].present? ? each_rec["flexi_off"].to_f.round(2) : "0",format )
        worksheet.write(k,a.count+7+3,each_rec["total_spent_of_cl"].present? ? each_rec["total_spent_of_cl"].to_f.round(2) : "0",format )
        worksheet.write(k,a.count+7+4,each_rec["total_spent_of_pl"].present? ? each_rec["total_spent_of_dl"].to_f.round(2) : "0",format )
        worksheet.write(k,a.count+7+5,each_rec["total_spent_of_dl"].present? ? each_rec["total_spent_of_pl"].to_f.round(2) : "0",format )
        # worksheet.write(k,a.count+7+6, each_rec["department"],format )
        check_date='2016-01-01'.to_date
        a.sort_by{|d| m,d,y=d.to_date.strftime("%F").split("-");[y,m,d]}.each_with_index do |each_result,index|

          if check_date.present? && check_date.to_date.strftime("%F") != each_result.to_date.strftime("%F") && each_rec["day"].to_date.strftime("%F")==each_result.to_s
            # worksheet.write(k,index+1,each_rec["spent_hours"])
            f = each_rec["bio_hours"].to_s.split(':').first
            s = each_rec["bio_hours"].to_s.split(':').last
            total=(f.to_i*60+s.to_i).to_f/60.to_f

            if each_rec["spent_hours"].to_f > total.to_f
             
              if each_rec["pto_status"].present?
               worksheet.write(k,index+7,each_rec["spent_hours"].to_f.round(2),spent_pto_format)
               else
               worksheet.write(k,index+7,each_rec["spent_hours"].to_f.round(2),spent_exced_format)

              end
            else
              if each_rec["pto_status"].present?
                worksheet.write(k,index+7,each_rec["spent_hours"].to_f.round(2),spent_pto_format)
              else
                worksheet.write(k,index+7,each_rec["spent_hours"].to_f.round(2),format)
              end

              
            end
            # worksheet.write(k,index+6+1,each_rec["bio_hours"].to_f.round(2),bio_format)
            worksheet.write(k,index+1+7,total.to_f.round(2),bio_format)
            #
            # hrs = each_rec["bio_hours"].to_f.to_s.split(':').first
            # min = each_rec["bio_hours"].to_f.to_s.split(':').last
            # total=((hrs.to_i*60+min.to_i*10).to_f/60.to_f)
            #
            # worksheet.write(k,index+1+6,total.to_f.round(2),bio_format)
          else
            # p  worksheet.get_cell(k,index+1)
            # worksheet.write(k+1,index+1,0)
            # worksheet.write(k+1,index+1+1,"0")
            # worksheet.write(k,index+1,0)
            # worksheet.write(k,index+1,each_rec["bio_hours"])
          end
          check_date = each_result

        end

        # k=index1
      else
        worksheet.write(k+1,0,each_rec["login"],title_format)
        worksheet.write(k+1,1,each_rec["project_name"],title_format)
        worksheet.write(k+1,2,each_rec["client_name"],title_format)
        worksheet.write(k+1,3,each_rec["employee_id"],title_format)
        worksheet.write(k+1,4,each_rec["department"],title_format)
        worksheet.write(k+1,5,each_rec["approver_status"],title_format)
        worksheet.write(k+1,6,each_rec["approved_by"],title_format)
        # worksheet.write(k+1,a.count+1,each_rec["pto_hours"])
        worksheet.write(k+1,a.count+7,each_rec["pto_hours"].present? ? each_rec["pto_hours"].to_f.round(2) : "0",format )
        worksheet.write(k+1,a.count+7+1,each_rec["non_approve_hours"].present? ? each_rec["non_approve_hours"].to_f.round(2) : "0",format )
        worksheet.write(k+1,a.count+7+2,each_rec["flexi_off"].present? ? each_rec["flexi_off"].to_f.round(2) : "0",format )
        worksheet.write(k+1,a.count+7+3,each_rec["total_spent_of_cl"].present? ? each_rec["total_spent_of_cl"].to_f.round(2) : "0",format )
        worksheet.write(k+1,a.count+7+4,each_rec["total_spent_of_pl"].present? ? each_rec["total_spent_of_dl"].to_f.round(2) : "0",format )
        worksheet.write(k+1,a.count+7+5,each_rec["total_spent_of_dl"].present? ? each_rec["total_spent_of_pl"].to_f.round(2) : "0",format )



        check_date='2016-01-01'.to_date
        a.sort_by{|d| m,d,y=d.to_date.strftime("%F").split("-");[y,m,d]}.each_with_index do |each_result,index|
          if check_date.present? && check_date.to_date.strftime("%F") != each_result.to_date.strftime("%F") && each_rec["day"].to_date.strftime("%F") == each_result.to_s

            f = each_rec["bio_hours"].to_s.split(':').first
            s = each_rec["bio_hours"].to_s.split(':').last
            total=(f.to_i*60+s.to_i).to_f/60.to_f

            if each_rec["spent_hours"].to_f > total.to_f
              if each_rec["pto_status"].present?
               worksheet.write(k+1,index+7,each_rec["spent_hours"].to_f.round(2),spent_pto_format)

             else
                worksheet.write(k+1,index+7,each_rec["spent_hours"].to_f.round(2),spent_exced_format)
              end


              
            else

              if each_rec["pto_status"].present?
              worksheet.write(k+1,index+7,each_rec["spent_hours"].to_f.round(2),spent_pto_format)
              else
              worksheet.write(k+1,index+7,each_rec["spent_hours"].to_f.round(2),format)
              end


              
            end
            # worksheet.write(k,index+6+1,each_rec["bio_hours"].to_f.round(2),bio_format)

           worksheet.write(k+1,index+1+7,total.to_f.round(2),bio_format)

          else

          end
          check_date = each_result
        end
        k=k+1

      end
      j=each_rec["employee_id"]
    end
    if workbook.close
    WkMailer.send_attendance_report(start_date,end_date).deliver
    end

  end

  def get_department(emp_id)
    user_info = UserOfficialInfo.where(:employee_id=>emp_id)
    if user_info.present?
     return user_info.first.department
    else
     return ""
    end
  end


  def check_bio_permission_list_user_id_project_id(l,user_id,project_ids,start_date)

    @all_roles=[]

    #user = User.find_by_id(user_id)
    if !project_ids.present?
      project_ids = [User.current.projects.first.id]
    end
    #project = Project.where(id:project_2).last

    project_ids.each do |project_id|
      project = Project.find_by_id(project_id)
      p project
      logtime_projects = User.current.roles_for_project(project)
      if logtime_projects.present?
        logtime_projects.each do |each_role|
          if !@all_roles.present? && each_role.permissions.index(l.to_sym)

            @all_roles << each_role.permissions
          end
        end

      end
    end

    @all_roles = @all_roles.flatten! if @all_roles.present?


    if (user_id.to_i == User.current.id && (l == "l1" || l == "l2" || l == "l3" ) && Setting.plugin_redmine_wktime[:wktime_own_approval].blank? )
      @all_roles =[]
    end

    if @all_roles.present?
      if (l == "l1") && check_expire_for_payroll(start_date)
      # if (l == "l1")
        check_l1 = @all_roles.include? l.to_sym
        check_l2 = @all_roles.include? "l2".to_sym
        # if check_l1.present? && !check_l2.present?
        if check_l1.present?
          return true
        end
      elsif(l == "l2")  && check_expire_for_payroll(start_date)==true && check_expire_for_l2(start_date)==true
      # elsif(l == "l2")
        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "l3") && is_l2?(user_id,project_ids) && check_expire_for_l3(start_date) &&  check_expire_for_payroll(start_date)
      # elsif(l == "l3")

        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "bio_hours_display")


        if @all_roles.include? l.to_sym
          return true
        end
      end
    else
    end
  end


  def check_bio_permission_list_user_id_project_id1(l,user_id,project_ids,start_date)

    @all_roles=[]

    #user = User.find_by_id(user_id)
    if !project_ids.present?
      project_ids = [User.current.projects.first.id]
    end
    #project = Project.where(id:project_2).last
    project_ids = Member.where(:user_id=>User.current.id).map(&:project_id)
    if project_ids.present?
      project_ids =Project.where(:id=>project_ids)

    end
    project_ids.each do |project_id|
      project = Project.find_by_id(project_id)
      p project
      logtime_projects = User.current.roles_for_project(project)
      if logtime_projects.present?
        logtime_projects.each do |each_role|
          if !@all_roles.present? && each_role.permissions.index(l.to_sym)

            @all_roles << each_role.permissions
          end
        end

      end
    end

    @all_roles = @all_roles.flatten! if @all_roles.present?


    # if (user_id.to_i == User.current.id && (l == "l1" || l == "l2" || l == "l3" ) && Setting.plugin_redmine_wktime[:wktime_own_approval].blank? )
    #   @all_roles =[]
    # end

    if @all_roles.present?
      if (l == "l1") && check_expire_for_payroll(start_date)
        check_l1 = @all_roles.include? l.to_sym
        check_l2 = @all_roles.include? "l2".to_sym
        if check_l1.present? && !check_l2.present?
          return true
        end
      elsif(l == "l2")
        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "l3")

        if @all_roles.include? l.to_sym
          return true
        end
      elsif(l == "bio_hours_display")


        if @all_roles.include? l.to_sym
          return true
        end
      end
    else
    end
  end







  def is_l2?(user_id,project_ids)

   p sql =  "select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id in (#{user_id}) and r.permissions like '%l2%' and m.project_id in (#{project_ids.join(',')}) limit 1"
   member =  Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id in (#{user_id}) and r.permissions like '%l2%' and m.project_id in (#{project_ids.join(',')}) limit 1")

    if member.present?

      return true
    end
  end

  def check_expire_for_l1(user_id,date)
    p "+++++++++++++++++l111111111111111+++++++++++++++=="
    if check_time_log_entry_l1(date) == false
         return true
    end
    # return false

  end


  def check_expire_for_payroll(date)
    # To check the Payroll deadline condition please enable the below lines

    # if check_time_log_entry_payroll(date) == true
    #        return true
    # end
    true
  end


  def check_expire_for_l12(user_id,date)

    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    expire_time = expire_time+7*60*60


    if date.to_time > expire_time

      return true

    else
      return false
    end

  end





  def check_expire_for_l2(date)
    #
    current_start_date=Date.today.at_beginning_of_week
    current_end_date=Date.today.at_end_of_week
    if check_time_log_entry_l2(Date.today) == true || (current_start_date..current_end_date).to_a.include?(date.to_date+1)
      pre_start_date=(Date.today-6).at_beginning_of_week
      pre_end_date=Date.today
      current_start_date=Date.today.at_beginning_of_week
      current_end_date=Date.today.at_end_of_week

      if (pre_start_date..pre_end_date).to_a.include?(date.to_date+1) || (current_start_date..current_end_date).to_a.include?(date.to_date+1)
               return true
          else
              return false

      end
    else
     
      return false
    end
    # return true
  end


  def check_expire_for_l3(date)
    #
    current_start_date=Date.today.at_beginning_of_week
    current_end_date=Date.today.at_end_of_week
    if check_time_log_entry_l3(Date.today) == true || (current_start_date..current_end_date).to_a.include?(date.to_date+1)
      pre_start_date=(Date.today-4).at_beginning_of_week
      pre_end_date=Date.today
      current_start_date=Date.today.at_beginning_of_week
      current_end_date=Date.today.at_end_of_week

      if (pre_start_date..pre_end_date).to_a.include?(date.to_date+1) || (current_start_date..current_end_date).to_a.include?(date.to_date+1)
        return true

      end
    end
  end


  def found_issues(current_issues,entry)

    curr_issue_found = false
    issues = Array.new
    if !Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? &&
        Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 1
      # add an empty issue to the array
      issues << [ "", ""]
    end
    allIssues = current_issues
    unless allIssues.blank?
      allIssues.each do |i|
        #issues << [ i.id.to_s + ' - ' + i.subject, i.id ]
        #issues << [ i.to_s , i.root_id ]
        issues << [ i.tracker.name + " #"+i.root_id.to_s+': ' + i.subject, i.root_id ]
        curr_issue_found = true if !entry.nil? && i.root_id == entry.issue_id
      end
    end
    #check if the issue, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    if !curr_issue_found
      if !entry.nil?
        if !entry.issue_id.nil?
          # issues.unshift([ entry.issue_id, entry.issue_id ])
          issues << [ entry.issue.tracker.name + " #"+entry.issue.root_id.to_s+': ' + entry.issue.subject, entry.issue.root_id ]
        else
          if Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
              Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0
            # add an empty issue to the array, if it is not already there
            issues.unshift([ "", ""])
          end
        end
      end
    end

    return issues
  end

 def found_activities(projActList,entry)

    activity = nil
    activities = nil
    #projActList = @projActivities[project_id]
    #activities = activities.sort_by{|name, id| name} unless activities.blank?
    unless projActList.blank?
      projActList = projActList.sort_by{|name| name}

      activity = projActList.detect {|a| a.id == entry.activity_id} unless entry.nil?
      #check if the activity, which was previously reported time, is still visible
      #if it is not visible, just show the id alone

      activities = projActList.collect {|a| [a.name, a.id]}
      activities.unshift( [ entry.activity_id, entry.activity_id ] )if !entry.nil? && activity.blank?

    end

    return activities

  end


  def get_project_id(entry)
    entry.nil? ? (@logtime_projects.blank? ? 0 : @logtime_projects[0].id) : entry.project_id
  end
  # def find_projects(entry)
  #   projects.detect {|p| p[1].to_i == entry.project_id} unless entry.nil?
  #
  # end
  def find_projects(entry)
    projects = options_for_wktime_project(@logtime_projects)
    project = projects.detect {|p| p[1].to_i == entry.project_id} unless entry.nil?
    #check if the project, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    projects.unshift( [ entry.project_id, entry.project_id ] ) if !entry.nil? && project.blank?
    return projects
  end


  def find_current_issues(entry,projectissues,project_id)
    curr_issue_found = false
    issues = Array.new
    if !Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? &&
        Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 1
      # add an empty issue to the array
      issues << [ "", ""]
    end
    allIssues = projectissues[project_id]
    unless allIssues.blank?
      allIssues.each do |i|
        #issues << [ i.id.to_s + ' - ' + i.subject, i.id ]
        issues << [ i.to_s , i.id ]
        curr_issue_found = true if !entry.nil? && i.id == entry.issue_id
      end
    end
    #check if the issue, which was previously reported time, is still visible
    #if it is not visible, just show the id alone
    if !curr_issue_found
      if !entry.nil?
        if !entry.issue_id.nil?
          issues.unshift([ entry.issue_id, entry.issue_id ])
        else
          if Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? ||
              Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 0
            # add an empty issue to the array, if it is not already there
            issues.unshift([ "", ""])
          end
        end
      end
    end
    return issues

  end

  def find_current_activities(entry,projActivities,project_id)
    activity = nil
    activities = nil
    projActList = projActivities[project_id]
    #activities = activities.sort_by{|name, id| name} unless activities.blank?
    unless projActList.blank?
      projActList = projActList.sort_by{|name| name}

      activity = projActList.detect {|a| a.id == entry.activity_id} unless entry.nil?
      #check if the activity, which was previously reported time, is still visible
      #if it is not visible, just show the id alone

      activities = projActList.collect {|a| [a.name, a.id]}
      activities.unshift( [ entry.activity_id, entry.activity_id ] )if !entry.nil? && activity.blank?
    end
    return activities
  end

  def get_project_ids(entries)
    entries.present? ? entries.map(&:project_id).uniq : [@logtime_projects.first.id]
  end

  def synch_database

    connection1 = ActiveRecord::Base.establish_connection(
        :adapter  => "mysql2",
        :host     => "192.168.9.104",
        :username => "root",
        :password => "root",
        :database => "redmine_synch_from"
    ).connection

    tables = connection1.tables

    @errors=[]
    @errors1=[]
    want_tables = ["projects"]

    if tables.present?
      # tables = skip_tables - tables
      tables.each do |each_table|
        begin
          connection1.execute("REPLACE into redmine_synch_to.#{each_table} select * from redmine_synch_from.#{each_table} ")
          p "++++++table name +++"
          p each_table
        rescue Exception => e
          @errors<< each_table
          @errors1<< {each_table=> e}
          next
        end
      end

    end

  end



  def remove_duplicates(entry)
    find_entries = TimeEntry.where(:project_id=>entry.project_id,:user_id=>entry.user_id,:issue_id=>entry.issue_id,:activity_id=>entry.activity_id,:spent_on=>entry.spent_on)
    sum = find_entries.map{|a| a.hours }.sum.to_i
    concat_comments = find_entries.collect(&:comments).uniq.join(' ')
    find_entries.shift.update_attributes(:hours=>sum,:comments=> concat_comments)
    find_entries.map{|entry| entry.delete } if find_entries.present?
  end

  def set_approved_color(wkts, th, user_id)
    state = ''
    wkts.select{ |date, flag| 
      case flag
        when 'l3'
         state =  'l3_approved'
        when 'l2'
         state =  'l2_approved'
        when 'l1'
         state =  'l1_approved'
        when 'r'
          state = 'reject_approval'
      end if date == th.to_date.strftime("%Y-%m-%d")
    }
    state
  end


  def is_pto_activity_edit_issues2(entry)

    if entry.present?
      find_entry = TimeEntry.find(entry.id)
      if find_entry.activity.name=="PTO" || find_entry.activity.name=="OnDuty"
        return true
      else
        return false
      end
    else
      return false
    end


    return false

  end

  def is_pto_activity(entry)

    if entry.present?
      find_entry = TimeEntry.find(entry.id)
      if (find_entry.activity.name=="PTO" || find_entry.activity.name=="OnDuty") && find_entry.hours > 0
        return true
      else
        return false
      end
    else
      return false
    end


    return false

  end

  def get_perm_for_project(project,perm)
   arry_per=[]
    if project.present? && project.members.present?
      project.members.each do |each_mem|
        if each_mem.roles.present?
          each_mem.roles.each do |each_role|
            if each_role.permissions.present?
              if each_role.permissions.include?(perm.to_sym)
                arry_per << each_mem.user_id

              end
            end
          end
        end

      end

    end

    if arry_per.present?
      p "+++++++++++arry_perarry_per+++++++++"
      return arry_per.first

    end

  end


  def get_perm_for_project_multiple(project,perm)
    arry_per=[]
    if project.members.present?
      project.members.each do |each_mem|
        if each_mem.roles.present?
          each_mem.roles.each do |each_role|
            if each_role.permissions.present?
              if each_role.permissions.include?(perm.to_sym)
                arry_per << each_mem.user_id

              end
            end
          end
        end

      end

    end

    if arry_per.present?
      p "+++++++++++arry_perarry_per+++++++++"
      return arry_per

    end

  end

  def create_nc_for_time_entry(date)

    User.active.each do |each_user|

        find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
        if !find_entry.present?
          find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
          master_id = NcMaster.find_by_name('TimeEntry')
          nc_history = NcHistory.find_or_initialize_by_employee_id_and_date(each_user.employee_id,date)
          nc_history.employee_id = each_user.employee_id
          nc_history.employee_name = each_user.full_name
          nc_history.user_id = each_user.id
          nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
          nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
          nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
          nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
          nc_history.date = date
          nc_history.reason = "TimeEntry Not Done..!"
          nc_history.nc_master_id = master_id.present? ? master_id.id : ""
          nc_history.save

        end

      # nc_history.

    end

  end


  # def create_nc_for_approve(date)
  #
  #   User.active.each do |each_user|
  #
  #     find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
  #     if !find_entry.present?
  #       find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
  #       master_id = NcMaster.find_by_name('TimeEntry')
  #       nc_history = NcHistory.find_or_initialize_by_employee_id_and_date(each_user.employee_id,date)
  #       nc_history.employee_id = each_user.employee_id
  #       nc_history.employee_name = each_user.full_name
  #       nc_history.user_id = each_user.id
  #       nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
  #       nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
  #       nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
  #       nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
  #       nc_history.date = date
  #       nc_history.reason = "TimeEntry Not Done..!"
  #       nc_history.nc_master_id = master_id.present? ? master_id.id : ""
  #       nc_history.save
  #
  #     end
  #
  #     # nc_history.
  #
  #   end
  #
  # end







  def create_nc_for_employee_within_sla(date)
id="TEP_NC_004"
    User.active.each do |each_user|

      find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
      if !find_entry.present?
        find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        if !find_user_project.present?

          find_user_project= Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like '%l2%' limit 1")

        end
        if find_user_project.present?
          master_id = NcMaster.find_by_nc_id("#{id}")
          nc_history = NcHistory.find_or_initialize_by_employee_id_and_project_id_and_date_and_nc_master_id(each_user.employee_id,find_user_project.first.project_id,date,master_id.nc_id)
          nc_history.employee_id = each_user.employee_id
          nc_history.employee_name = each_user.full_name
          nc_history.user_id = each_user.id
          nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
          nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
          nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
          nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
          nc_history.date = date
          nc_history.reason = "Employee fails to record time entry within the SLA"
          p '======================= id ================='
          p master_id
          nc_history.nc_master_id = master_id.present? ? master_id.nc_id : ""
          nc_history.save


        end
      end

      # nc_history.

    end

  end

  def create_nc_for_employee_within_unlock_sla(date,id,user_id)

    User.where(:id=>user_id).each do |each_user|

      find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
      if !find_entry.present?
        find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        if !find_user_project.present?

          find_user_project= Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like '%l2%' limit 1")

        end
        if find_user_project.present?
          master_id = NcMaster.find_by_nc_id("#{id}")
          nc_history = NcHistory.find_or_initialize_by_employee_id_and_project_id_and_date_and_nc_master_id(each_user.employee_id,find_user_project.first.project_id,date,master_id.nc_id)
          nc_history.employee_id = each_user.employee_id
          nc_history.employee_name = each_user.full_name
          nc_history.user_id = each_user.id
          nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
          nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
          nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
          nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
          nc_history.date = date
          nc_history.reason = "Employee fails to correct and updatethe time entry within the defined timeline"
          nc_history.nc_master_id = master_id.present? ? master_id.nc_id : ""
          nc_history.save

        end
      end

      # nc_history.

    end

  end


  def create_nc_for_l1_within_sla(date)
id="TEP_NC_007"
    User.active.each do |each_user|
      find_wktime = Wktime.where(:user_id=>each_user.id,:begin_date=>date,:status=>"l1")
      # find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
      if !find_wktime.present?
        # find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)

        p '===='
        p each_user
        con = "select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.name like '%Contributor%' order by max(m.capacity) DESC"

        p con
        p '====== con------------------'
        find_user_project=  Member.find_by_sql(con)
        p "++++++++find_user_project++++"
        p find_user_project
        p "++++++++++"

        if find_user_project.present? && find_user_project.first.id > 0
          master_id = NcMaster.find_by_nc_id("#{id}")
          if get_perm_for_project(find_user_project.first.project,'l1').present? && get_perm_for_project(find_user_project.first.project,'l1').present? && get_perm_for_project(find_user_project.first.project,'l1') != each_user.id
            find_user = User.find(get_perm_for_project(find_user_project.first.project,'l1'))
            nc_history = NcHistory.find_or_initialize_by_employee_id_and_project_id_and_date_and_nc_master_id(each_user.employee_id,find_user_project.first.project_id,date,master_id.nc_id)

            nc_history.employee_id = find_user.employee_id
            nc_history.employee_name = find_user.full_name
            nc_history.user_id = find_user.id
            nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
            nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
            nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
            nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
            nc_history.date = date
            nc_history.reason = master_id.description
            nc_history.nc_master_id = master_id.present? ? master_id.nc_id : ""
            nc_history.nc_create_for = each_user.id
            nc_history.save
          end
        end
      end
      # nc_history.

    end

  end




  def create_nc_for_l1_within_unlock_sla(date)
    a = []
    nc_id = "TEP_NC_014"

    User.active.each do |each_user|

      # find_wktime = Wktime.where(:user_id=>each_user.id,:begin_date=>date,:status=>"l1")
      # TimeEntry.where(:user_id=>each_user.id,:spent_on=>date).sum(:hours)
      lock_status = UserUnlockEntry.where(:user_id=>each_user.id)
      find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
      if  lock_status.present? && find_entry.sum(:hours) < Setting.plugin_redmine_wktime['wktime_max_hour_day'].to_i
        # find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        find_user_project=  Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.name like '%Contributor%' order by max(m.capacity) DESC limit 1")


#         if !find_user_project.present?
#
#           find_user_project= Member.find_by_sql("select * from members m
# join member_roles mr on mr.member_id=m.id
# join projects p on p.id=m.project_id
# join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like '%l2%' limit 1")
#
#         end
        if find_user_project.present? && find_user_project.first.id > 0 && get_perm_for_project(find_user_project.first.project,'l1').present? && get_perm_for_project(find_user_project.first.project,'l1') != each_user.id
          nc_history_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
          if nc_history_l1.present?
            find_user = User.find(get_perm_for_project(find_user_project.first.project,'l1'))
            master_id = NcMaster.find_by_nc_id("#{nc_id}")
            nc_history = NcHistory.find_or_initialize_by_employee_id_and_project_id_and_date_and_nc_master_id(each_user.employee_id,find_user_project.first.project_id,date,master_id.nc_id)
            nc_history.employee_id = find_user.employee_id
            nc_history.employee_name = find_user.full_name
            nc_history.user_id = find_user.id
            nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""

            nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
            nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
            nc_history.date = date
            nc_history.reason = "L1 fails to ensure that the respective employee fails to correct the time entry within the defined timeline."
            nc_history.nc_master_id = master_id.present? ? master_id.nc_id : ""
            nc_history.nc_create_for = each_user.id
            nc_history.save
          end

        end

      end



    end
    a
  end


  def create_nc_for_l2_within_sla(date)
    nc_id = "TEP_NC_016"
    start_date=(date.to_date-3).at_beginning_of_week
    end_date=start_date.at_end_of_week

    User.active.each do |each_user|
      find_wktime = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>"l2")

      # find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)
      if !find_wktime.present?
        find_user_project=  Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions REGEXP 'l0|l1' order by max(m.capacity) DESC limit 1")
        # find_user_project= Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        #         if !find_user_project.present?
        #
        #           find_user_project= Member.find_by_sql("select * from members m
        # join member_roles mr on mr.member_id=m.id
        # join projects p on p.id=m.project_id
        # join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like '%l2%' limit 1")
        #         end



        if find_user_project.present?  && find_user_project.first.id > 0 && get_perm_for_project(find_user_project.first.project,'l2').present? && get_perm_for_project(find_user_project.first.project,'l2') != each_user.id
          p "++++++++++++++=get_perm_for_project(find_user_project.first.project,'l2')++++++++=="
          p get_perm_for_project(find_user_project.first.project,'l2')
          p "++++End ++++++++++"

          find_user = User.find(get_perm_for_project(find_user_project.first.project,'l2'))
          master_id = NcMaster.find_by_nc_id("#{nc_id}")
          nc_history = NcHistory.find_or_initialize_by_employee_id_and_project_id_and_date_and_nc_master_id(each_user.employee_id,find_user_project.first.project_id,date,master_id.nc_id)
          nc_history.employee_id = find_user.employee_id
          nc_history.employee_name = find_user.full_name
          nc_history.user_id = find_user.id
          nc_history.project_id= find_user_project.present? ? find_user_project.first.project_id : ""
          nc_history.project_l1= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l1') : ""
          nc_history.project_l2= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l2') : ""
          nc_history.project_l3= find_user_project.present? ? get_perm_for_project(find_user_project.first.project,'l3') : ""
          nc_history.date = date
          nc_history.reason = "L2 fails to validate and approve  the time entry within the defined timeline."
          nc_history.nc_master_id = master_id.present? ? master_id.nc_id : ""
          nc_history.nc_create_for = each_user.id
          nc_history.save

        end
      end
      # nc_history.
    end
  end

  def weekly_approve_notifications(date)

    start_date=(Date.today-3).at_beginning_of_week
    end_date=start_date.at_end_of_week

    User.active.each do |each_user|

      find_l2_entries = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>'l2')
      if !find_l2_entries.present?
        p 111111111111111
       p find_user_project = Member.where(:user_id=>each_user.id).order('m
ax(capacity) DESC').limit(1)
        if !find_user_project.present?


          find_user_project= Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like ''%l2%'' limit 1")

        end
        l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
        l1_user_id = get_perm_for_project(find_user_project.first.project,'l3')

        if l2_user_id.present?
          p "++++++++++l2 user ++++++"
         p User.find(l2_user_id)
          p "============="
           WkMailer.send_l2_notification(l2_user_id,each_user.id,start_date,end_date).deliver
        end
        if l1_user_id.present?
          p "++++++++++l2 user ++++++"
          p User.find(l1_user_id)
          p "============="
          WkMailer.send_l2_notification(l1_user_id,each_user.id,start_date,end_date).deliver
        end

      end

    end

  end


  def weekly_approve_l2_l3_notifications(start_date,end_date)

    # start_date=(Date.today-3).at_beginning_of_week
    # end_date=start_date.at_end_of_week

    User.active.each do |each_user|

      find_l2_entries = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>'l2')
      if !find_l2_entries.present?

         find_user_project = Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        if !find_user_project.present?

          find_user_project= Member.find_by_sql("select * from members m
join member_roles mr on mr.member_id=m.id
join projects p on p.id=m.project_id
join roles r on r.id=mr.role_id where m.user_id=#{each_user.id} and r.permissions like ''%l2%'' limit 1")

        end
        l2_user_id = get_perm_for_project_multiple(find_user_project.first.project,'l2')
        l3_user_id = get_perm_for_project_multiple(find_user_project.first.project,'l3')

        if !find_l2_entries.present?
        if l2_user_id.present?

          l2_user_id.each do |each_l2|
          WkMailer.send_l2_l3_notification(each_l2,each_user.id,start_date,end_date).deliver
            end
        end
        if l3_user_id.present?

          l3_user_id.each do |each_l3|
            WkMailer.send_l2_l3_notification(each_l3,each_user.id,start_date,end_date).deliver
          end
        end

        end

        end

      end

    end





  def weekly_approve_pending_notifications_on_23

    start_date=(Date.today+2)
    if start_date.wday == 6 || start_date.wday==0

      start_date=(Date.today-30)
      end_date=Date.today
      weekly_approve_l2_l3_notifications(start_date,end_date)

    else

      # start_date=(Date.today-30)
      # end_date=Date.today

    end


  end




  def weekly_approve_l1_notifications(date)

    start_date=(Date.today-3).at_beginning_of_week
    end_date=start_date.at_end_of_week

    User.active.each do |each_user|

      find_l1_entries = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>'l1')
      if !find_l1_entries.present?
        p 111111111111111
        p find_user_project = Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1);

        l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
        # l1_user_id = get_perm_for_project(find_user_project.first.project,'l3')

        if l2_user_id.present?

          WkMailer.send_l2_notification(l2_user_id,each_user.id,date,date).deliver
        end
        # if l1_user_id.present?
        #
        #   WkMailer.send_l2_notification(l1_user_id,each_user.id,start_date,end_date).deliver
        # end

      end

    end

  end


  def weekly_approve_l2_notifications(date)

    start_date=(Date.today-5).at_beginning_of_week
    end_date=start_date.at_end_of_week

    User.active.each do |each_user|

      find_l2_entries = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>'l2')
      if !find_l2_entries.present? || (find_l2_entries.count > (start_date..end_date).count)
        p 111111111111111
        p find_user_project = Member.where(:user_id=>each_user.id).order('capacity DESC').limit(1)
        # l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
        l3_user_id = get_perm_for_project((find_user_project.first.project rescue nil),'l3')

        # if l2_user_id.present?
        #   p "++++++++++l2 user ++++++"
        #   p User.find(l2_user_id)
        #   p "============="
        #   WkMailer.send_l2_notification(l2_user_id,each_user.id,start_date,end_date).deliver
        # end
        if l3_user_id.present?
          p "++++++++++l2 user ++++++"
          p User.find(l3_user_id)
          p "============="
          WkMailer.send_l2_notification(l3_user_id,each_user.id,start_date,end_date).deliver
        end

      end

    end

  end


  def monthly_auto_approve(date)

     start_date = (date.to_date-1.month)
     end_date = (start_date)
    # start_date = (date.to_date).at_beginning_of_week
    # end_date = date.to_date
    # if date.to_date < Date.today
    #
    #   start_date = (date.to_date).at_beginning_of_week
    #   end_date = date
    # end


      errors=[]

# p sql = "select * from users u join user_official_infos uo uo.employee_id in (#{params[:employeeIds]})"
#       users = User.find_by_sql("select u.id,u.login,u.firstname,u.lastname from users u
#   join user_official_infos uo on u.id=uo.user_id where uo.employee_id in (#{params[:employeeIds]})")

    @admin_user = User.find_by_login("Admin")
    # User.active
      User.active.each do |each_user|

        find_l2_entries = Wktime.where(:user_id=>each_user,:begin_date=>start_date..end_date,:status=>'l2')
        if !find_l2_entries.present? || (find_l2_entries.count < (start_date..end_date).count)
          find_user_project = Member.find_by_sql("select m.user_id,m.project_id from members m where m.user_id=#{each_user.id} and m.project_id is not null order by m.capacity DESC limit 1 ")

          if find_user_project.present?
          # l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
          # l1_user_id = get_perm_for_project(find_user_project.first.project,'l3')

          find_activity = Enumeration.where(:name=>'PTO')
          if find_activity.present?

            @find_activity_id = find_activity.last.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_tracker = Tracker.where(:name=>'support')
          if find_tracker.present?

            @find_tracker_id = find_tracker.first.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end

          find_issue = Issue.where(:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:subject=>'PTO')
          if find_issue.present?
            @find_issue_id = find_issue.first.id
          else
            find_issue = Issue.new(:subject=>"PTO",:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:author_id=>each_user.id,:assigned_to_id=>each_user.id)
            if find_issue.save
              @find_issue_id = find_issue.id
            end
            # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
          end

          (start_date..end_date).to_a.each do |each_date|

            @time_entry =  TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(find_user_project.first.project_id,each_user.id,@find_activity_id,each_date,@find_issue_id)
            if @time_entry.present? && @time_entry.id.blank?
              @time_entry.project_id = find_user_project.first.project_id
              @time_entry.activity_id = @find_activity_id
              @time_entry.issue_id = @find_issue_id
              @time_entry.hours = 0.00
              @time_entry.save
            end
            @wktime = Wktime.find_or_initialize_by_user_id_and_begin_date(each_user.id,each_date)
            @wktime.project_id = find_user_project.first.project_id
            @wktime.status="l2"
            @wktime.pre_status=@wktime.status.present? ? @wktime.status : "n"
            @wktime.hours = @wktime.hours.to_f
            @wktime.statusupdate_on = Date.today
            @wktime.statusupdater_id =@admin_user.id rescue ""
            @wktime.notes="System Approved"
            @wktime.save
            # if @wktime.save

            #   # @wktime = wktime
            #   find_time_entry_hours = TimeEntry.find_by_sql("select sum(hours) as hours from time_entries where spent_on in ('#{each_date}') and user_id in (#{each_user.id})")


end
            #   # url = Redmine::Configuration['iserv_base_url']
            #   # key = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB"
            #   # url1 = "#{url}/services/employees/dailyattendance/#{user_emp_code}?fromDate=#{start_date}&toDate=#{end_date}"
            #   # response = RestClient::Request.new(:method => :get,:url => url1, :headers => {:"Auth-key" => key},:verify_ssl => false).execute


            #   # url = Redmine::Configuration['iserv_base_url']
            #   url = "#{Redmine::Configuration['iserv_base_url']}/services/employees/autoleaves?"
            #   key = Redmine::Configuration['iserv_api_key']
            #   if find_time_entry_hours.present?
            #     if  find_time_entry_hours.first.hours.to_f < 4
            #       # lop_request = RestClient.post 'https://iservstaging.objectfrontier.com/services/employees/autoleaves?',:headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'}, :param1 => 'one', :content_type => 'application/json'
            #       # lop_request
            #       # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"
            #       # response = RestClient::Request.new(:method => :post,:url => url, :headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :content_type => 'application/json').execute

            #       # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"

            #       # RestClient.post(url, { 'x' => 1 }.to_json, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},:verify_ssl => false)

            #       # RestClient.post(url, { 'x' => 1 }.to_json,:verify_ssl=>false ,:content_type => :json, :accept => :json)

            #       response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
            #       )


            #     elsif find_time_entry_hours.first.hours.to_f < 8

            #       # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload =>  {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate =>each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half Day"}
            #       # )

            #       response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half day"}.to_json
            #       )

            #     end

            #   else

            #     # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload => {:employeeId => '1144', :fromDate => each_day.to_date,:toDate =>each_day.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full Day"}
            #     # )
            #     response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
            #     )



            #   end


            # else
            #   errors << @wktime.errors.messages
            # end
          end

        end


      end
      # params[:employeeId].each do |each_emp|
      #
      #
      # end




    # p "++++++++++++=@wktime@wktime@wktime+++++++++"
    # p @wktime
    # p "++++end +_+++++++++++++="
    # if errors.present?
    #   render_json_errors(errors.join(','))
    # else
    #   render_json_ok(Wk)
    # end

  end

  def weekly_auto_approve (date)

    start_date = ((date.to_date-5).at_beginning_of_week-1)
    end_date = (start_date+6)
    # start_date = (date.to_date).at_beginning_of_week
    # end_date = date.to_date
    # if date.to_date < Date.today
    #
    #   start_date = (date.to_date).at_beginning_of_week
    #   end_date = date
    # end


    errors=[]

# p sql = "select * from users u join user_official_infos uo uo.employee_id in (#{params[:employeeIds]})"
#       users = User.find_by_sql("select u.id,u.login,u.firstname,u.lastname from users u
#   join user_official_infos uo on u.id=uo.user_id where uo.employee_id in (#{params[:employeeIds]})")

    @admin_user = User.find_by_login("Admin")
# User.active
    User.active.each do |each_user|

      find_l2_entries = Wktime.where(:user_id=>each_user,:begin_date=>start_date..end_date,:status=>'l2')
      if !find_l2_entries.present? || (find_l2_entries.count < (start_date..end_date).to_a.count)
        find_user_project = Member.find_by_sql("select m.user_id,m.project_id from members m where m.user_id=#{each_user.id} and m.project_id is not null order by m.capacity DESC limit 1 ")

        if find_user_project.present?
          # l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
          # l1_user_id = get_perm_for_project(find_user_project.first.project,'l3')

          find_activity = Enumeration.where(:name=>'PTO')
          if find_activity.present?

            @find_activity_id = find_activity.last.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_tracker = Tracker.where(:name=>'support')
          if find_tracker.present?

            @find_tracker_id = find_tracker.first.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end

          find_issue = Issue.where(:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:subject=>'PTO')
          if find_issue.present?
            @find_issue_id = find_issue.first.id
          else
            find_issue = Issue.new(:subject=>"PTO",:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:author_id=>each_user.id,:assigned_to_id=>each_user.id)
            if find_issue.save
              @find_issue_id = find_issue.id
            end
            # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
          end

          (start_date..end_date).to_a.each do |each_date|

            @time_entry =  TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(find_user_project.first.project_id,each_user.id,@find_activity_id,each_date,@find_issue_id)
            if @time_entry.present? && @time_entry.id.blank?
              @time_entry.project_id = find_user_project.first.project_id
              @time_entry.activity_id = @find_activity_id
              @time_entry.issue_id = @find_issue_id
              @time_entry.hours = 0.00
              @time_entry.save
            end
            @wktime = Wktime.find_or_initialize_by_user_id_and_begin_date(each_user.id,each_date)
            @wktime.project_id = find_user_project.first.project_id
            @wktime.status="l2"
            @wktime.pre_status=@wktime.status.present? ? @wktime.status : "n"
            @wktime.hours = @wktime.hours.to_f
            @wktime.statusupdate_on = Date.today
            @wktime.statusupdater_id =@admin_user.id rescue ""
            @wktime.notes="System Approved"
            @wktime.save
            # if @wktime.save

            #   # @wktime = wktime
            #   find_time_entry_hours = TimeEntry.find_by_sql("select sum(hours) as hours from time_entries where spent_on in ('#{each_date}') and user_id in (#{each_user.id})")


          end
          #   # url = Redmine::Configuration['iserv_base_url']
          #   # key = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB"
          #   # url1 = "#{url}/services/employees/dailyattendance/#{user_emp_code}?fromDate=#{start_date}&toDate=#{end_date}"
          #   # response = RestClient::Request.new(:method => :get,:url => url1, :headers => {:"Auth-key" => key},:verify_ssl => false).execute


          #   # url = Redmine::Configuration['iserv_base_url']
          #   url = "#{Redmine::Configuration['iserv_base_url']}/services/employees/autoleaves?"
          #   key = Redmine::Configuration['iserv_api_key']
          #   if find_time_entry_hours.present?
          #     if  find_time_entry_hours.first.hours.to_f < 4
          #       # lop_request = RestClient.post 'https://iservstaging.objectfrontier.com/services/employees/autoleaves?',:headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'}, :param1 => 'one', :content_type => 'application/json'
          #       # lop_request
          #       # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"
          #       # response = RestClient::Request.new(:method => :post,:url => url, :headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :content_type => 'application/json').execute

          #       # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"

          #       # RestClient.post(url, { 'x' => 1 }.to_json, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},:verify_ssl => false)

          #       # RestClient.post(url, { 'x' => 1 }.to_json,:verify_ssl=>false ,:content_type => :json, :accept => :json)

          #       response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
          #       )


          #     elsif find_time_entry_hours.first.hours.to_f < 8

          #       # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload =>  {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate =>each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half Day"}
          #       # )

          #       response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half day"}.to_json
          #       )

          #     end

          #   else

          #     # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload => {:employeeId => '1144', :fromDate => each_day.to_date,:toDate =>each_day.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full Day"}
          #     # )
          #     response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => key},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
          #     )



          #   end


          # else
          #   errors << @wktime.errors.messages
          # end
        end

      end


    end
    # params[:employeeId].each do |each_emp|
    #
    #
    # end




    # p "++++++++++++=@wktime@wktime@wktime+++++++++"
    # p @wktime
    # p "++++end +_+++++++++++++="
    # if errors.present?
    #   render_json_errors(errors.join(','))
    # else
    #   render_json_ok(Wk)
    # end

  end

  def lms_request
    url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"

    # RestClient.post(url, { 'x' => 1 }.to_json, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},:verify_ssl => false)

    # RestClient.post(url, { 'x' => 1 }.to_json,:verify_ssl=>false ,:content_type => :json, :accept => :json)

    response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false,:payload => {:employeeId => '1144', :fromDate => '2016-05-30',:toDate => "2016-05-30", :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full Day"}.to_json
        )
    # response = RestClient::Request.new(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false,:employee_id=>"564646").execute
    p "++++++++++response+++++++++++++++"
    p response.inspect
    # p response.errors
    p response.code
    p "+++++++++=end ++++++++++"

    # url = 'https://iservstaging.objectfrontier.com/services/employees/autoleaves?'
    # header = {'Accept' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB',:verify_ssl => false}
    # response = RestClient.post url, {:verify_ssl => false}, header


  end



  def monthly_approve_notifications(date)

    User.active.each do |each_user|

      find_entry = TimeEntry.where(:user_id=>each_user.id,:spent_on=>date)



    end

  end

  def unlock_types
      [ ['Failed to enter time within SLA','1'], ['Informed/Uninformed Leave','2'],
        ['Task not created/assigned','3'], ['Access not provided',4],
        ['Recorded in wrong task','5'],['System/Application  down','6'], ['Others','0']
      ]

  end

  def flexioff_reasons
    [ [ 'Birthday(Self)','Birthday(Self)'],['Birthday (Spouse or Kids)','Birthday (Spouse or Kids)'],['Anniversary (Self)','Anniversary (Self)'],
      ['No Work','No Work'],['Employee welfare activity','Employee welfare activity'],['Others','Others']
    ]
  end
  def timeEntry_location
    [[ 'In Office','In Office'], [ 'Out Of Office','Out Of Office']]
  end


  def expire_unlock_history

    UserUnlockEntry.delete_all

  end



  def monthly_approve_l2_notifications(date)

    start_date=(date.to_date).at_beginning_of_week
    end_date=date.to_date.at_end_of_week

    User.active.each do |each_user|

      find_l1_entries = Wktime.where(:user_id=>each_user.id,:begin_date=>start_date..end_date,:status=>'l2')
      if !find_l1_entries.present? || (find_l1_entries.count < (start_date..end_date).count )
        p 111111111111111
        p find_user_project = Member.where(:user_id=>each_user.id).order('max(capacity) DESC').limit(1)
        # l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
        if find_user_project.first.id > 0
        l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
        end

        # if l2_user_id.present?
        #   p "++++++++++l2 user ++++++"
        #   p User.find(l2_user_id)
        #   p "============="
        #   WkMailer.send_l2_notification(l2_user_id,each_user.id,start_date,end_date).deliver
        # end
        if l2_user_id.present?
          p "++++++++++l2 user ++++++"
          p User.find(l2_user_id)
          p "============="
          WkMailer.send_l2_month_notification(l2_user_id,each_user.id,start_date,end_date).deliver
        end

      end

    end

  end

def week_approve_update(date)
  @admin_user = User.find_by_login("Admin")

 start_date = (date.to_date).at_beginning_of_week
    end_date = date.to_date

User.active.each do |each_user|
  (start_date..end_date).to_a.each do |each_date|
    wktimes = Wktime.where(:user_id=>each_user.id,:begin_date=>each_date)
    wktimes.each do |each_time|
each_time.delete
    end

@wktime = Wktime.find_or_initialize_by_user_id_and_begin_date(each_user.id,each_date)
            
            @wktime.status="n"
            @wktime.pre_status=@wktime.status.present? ? 'n' : "n"
            @wktime.hours = TimeEntry.where(:user_id=>each_user.id,:spent_on=>each_date).sum(&:hours)
            @wktime.statusupdate_on = Date.today
            @wktime.statusupdater_id =@admin_user.id rescue ""
            @wktime.notes=""
            if @wktime.save
            end
            p 11111111111111111111111111111111111
            p @wktime
            p TimeEntry.where(:user_id=>each_user.id,:spent_on=>each_date).sum(&:hours)
            p 222222222222222222222222
          end
end

end




end
