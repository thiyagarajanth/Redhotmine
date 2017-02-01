require 'redmine'
require_dependency 'custom_fields_helper'
require_dependency 'timelog_controller_patch'
require_dependency 'settings_controller_patch'
require_dependency 'context_menus_controller_patch'


module WktimeHelperPatch
  def self.included(base)
    CustomFieldsHelper::CUSTOM_FIELDS_TABS << {:name => 'WktimeCustomField', :partial => 'custom_fields/index', :label => :label_wk_time}
  end
end


RedmineApp::Application.config.after_initialize do
  require_dependency 'redmine_wktime/infectors'
end

CustomFieldsHelper.send(:include, WktimeHelperPatch)
TimelogController.send(:include, TimelogControllerPatch)
SettingsController.send(:include, SettingsControllerPatch)
ContextMenusController.send(:include, ContextMenusControllerPatch)

Redmine::Plugin.register :redmine_wktime do
  name 'Time & Expense'
  author 'Adhi Software Pvt Ltd'
  description 'This plugin is for entering Time & Expense'
  version '1.7'
  url 'http://www.redmine.org/plugins/wk-time'
  author_url 'http://www.adhisoftware.co.in/'

  settings(:partial => 'settings',
           :default => {
               'wktime_project_dd_width' => '150',
               'wktime_issue_dd_width' => '250',
               'wktime_actv_dd_width' => '75',
               'wktime_closed_issue_ind' => '0',
               'wktime_restr_min_hour' => '0',
               'wktime_min_hour_day' => '0',
               'wktime_restr_max_hour' => '0',
               'wktime_max_hour_day' => '8',
               'label_wk_logtime_deadline' => '0',
               'wktime_nonlog_mail' => '0',
               'wktime_nonlog_day' => '2',
               'wktime_nonlog_hr' => '11',
               'wktime_nonlog_min' => '15',

               'wktime_nonapprove_day_l3' => '2',
               'wktime_nonapprove_hr_l3' => '11',
               'wktime_nonapprove_min_l3' => '15',
               'wktime_nonapprove_day_l2' => '2',
               'wktime_nonapprove_hr_l2' => '11',
               'wktime_nonapprove_min_l2' => '15',
               'wktime_nonapprove_day_l1' => '2',
               'wktime_nonapprove_hr_l1' => '11',
               'wktime_nonapprove_min_l1' => '15',
               'wktime_payroll_day' => '2',
               'wktime_payroll_hr' => '11',
               'wktime_payroll_min' => '15',

               'wktime_nonlog_mail_message' => 'You are receiving this notification for missing timesheet log',
               'wktime_page_width' => '250',
               'wktime_page_height' => '297',
               'wktime_margin_top' => '20',
               'wktime_margin_bottom' => '20',
               'wktime_margin_left' => '10',
               'wktime_margin_right' => '10',
               'wktime_line_space' => '4',
               'wktime_header_logo' => 'logo.jpg',
               'wktime_work_time_header' => '0',
               'wktime_allow_blank_issue' => '0',
               'wktime_enter_comment_in_row' => '1',
               'wktime_use_detail_popup' => '0',
               'wktime_use_approval_system' => '0',
               'wktime_uuto_approve' => '0',
               'wktime_submission_ack' => 'I Acknowledge that the hours entered by the candidate are accurate to the best of my knowledge',
               'wktime_enter_cf_in_row1' => '0',
               'wktime_enter_cf_in_row2' => '0',
               'wktime_enter_issue_as' =>'0',
               'wktime_own_approval' => '0',
               'wktime_previous_template_week' => '1',
               'wkexpense_issues_filter_tracker' => ['0'],
               'wktime_issues_filter_tracker' => ['0'],
               'wktime_allow_user_filter_tracker' => '0',
               'wktime_nonsub_mail_notification' => '0',
               'wktime_nonsub_mail_message' => 'You are receiving this notification for timesheet non submission',
               'wktime_submission_deadline' => '1',
               'wktime_nonsub_sch_hr' => '23',
               'wktime_nonsub_sch_min' => '0',
               'wkexpense_projects' => [''],
               'wktime_allow_filter_issue' => '0',
                'wktime_country' => '0'
           })

  menu :top_menu, :wkTime, { :controller => 'wktime', :action => 'index' }, :caption => :label_te, :if => Proc.new { Object.new.extend(WktimeHelper).checkViewPermission }
  project_module :time_tracking do
    permission :approve_time_entries,  {:wktime => [:update]}, :require => :member
    permission :l0,  {:wktime => [:update]}, :require => :member
    permission :l1,  {:wktime => [:update]}, :require => :member
    permission :l2,  {:wktime => [:update]}, :require => :member
    permission :l3,  {:wktime => [:update]}, :require => :member
    permission :unlock_users,  {:wktime => [:unlock_users]},:public => true
    permission :unlock_permanent,  {:wktime => [:lock_permanent]},:public => true
    permission :bio_hours_display,  {:wktime => [:update]}, :require => :member
  end
end


Rails.configuration.to_prepare do
  if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
    if (!Setting.plugin_redmine_wktime['wktime_nonsub_mail_notification'].blank? && Setting.plugin_redmine_wktime['wktime_nonsub_mail_notification'].to_i == 1)
      require 'rufus/scheduler'
      if (!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? && Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1)
        submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        hr = Setting.plugin_redmine_wktime['wktime_nonsub_sch_hr']
        min = Setting.plugin_redmine_wktime['wktime_nonsub_sch_min']
        scheduler = Rufus::Scheduler.new #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if hr == '0' && min == '0'
          cronSt = "0 * * * #{submissionDeadline}"
        else
          cronSt = "#{min} #{hr} * * #{submissionDeadline}"
        end
        scheduler.cron cronSt do
          begin
            Rails.logger.info "==========Scheduler Started=========="
            wktime_helper = Object.new.extend(WktimeHelper)
            wktime_helper.sendNonSubmissionMail()
          rescue Exception => e
            Rails.logger.info "Scheduler failed: #{e.message}"
          end
        end
      end
    end
  end
end




Rails.configuration.to_prepare do
  require 'rufus/scheduler'


  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      scheduler = Rufus::Scheduler.new
      if forked && Redmine::Configuration['cron_job_server'].present?
        count = 0


        # scheduler.cron '0 02,03,04 *   *   * ' do
        #   helper.retry_remainder
        # end
        # scheduler.every '1m' do
        #   count = count + 1
        #   Sync.sync_sql
        #   Rails.logger.info "---------#{Time.now}--------------#{count}-------------"
        # end


        # month_time = '0 22 26 * *'
        # # month_time = '06 18 6 * *'
        # scheduler.cron  month_time do
        #   # do something every day, five minutes after midnight
        #   # (see "man 5 crontab" in your terminal)
        #   Rails.logger.info "==========Scheduler Started for attendance report month========="
        #   wktime_helper = Object.new.extend(WktimeHelper)
        #   start_date=(Date.today - 1.month)-1
        #   end_date=Date.today
        #   wktime_helper.get_new_attendance(start_date,end_date)
        #   Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
        # end

        # week_time = '0 22 * * 2'
        # # week_time = '13 18 6 * *'
        # scheduler.cron  week_time do
        #   # do something every day, five minutes after midnight
        #   # (see "man 5 crontab" in your terminal)
        #   Rails.logger.info "==========Scheduler Started for attendance report week=========="
        #   wktime_helper = Object.new.extend(WktimeHelper)
        #   start_date=(Date.today-3).at_beginning_of_week
        #   end_date=start_date.at_end_of_week-2
        #   wktime_helper.get_new_attendance(start_date,end_date)
        #   Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
        #
        # end





        # Employee timeentry nc creation.



        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonlog_day']
        hr = Setting.plugin_redmine_wktime['wktime_nonlog_hr']
        min = Setting.plugin_redmine_wktime['wktime_nonlog_min']
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if day.present? && hr.present? && min.present?
        if hr == '0' && min == '0'
          cronSt = "0 * * * *"
        else
          cronSt = "#{min} #{hr} * * *"
        end
        # cronSt= "45 23 * * *"
        scheduler.cron cronSt do

          wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.create_nc_for_employee_within_sla(Date.today-day.to_i)
          # wktime_helper.expire_unlock_history

        end

        end


        # L1 approval nc creation



        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l1']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l1']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l1']
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if day.present? && hr.present? && min.present?
        if hr == '0' && min == '0'
          cronSt = "0 * * * *"
        else
          cronSt = "#{min} #{hr} * * *"
        end
        # cronSt= "12 19 * * *"
        scheduler.cron cronSt do

          # wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.expire_unlock_history
          # wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
          # wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
          # wktime_helper.expire_unlock_history
          # wktime_helper.weekly_approve_l1_notifications(Date.today)

        end
        end


        #L2 approval nc creation



        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l2']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l2']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l2']
        if day.present? && hr.present? && min.present?
        date = Date.parse(day)
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if hr == '0' && min == '0'
          cronSt = "0 * * * *"
        else
          cronSt = "#{min} #{hr} * * #{date.wday}"
        end
        # cronSt= "45 23 * * *"
        scheduler.cron cronSt do
          # wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.create_nc_for_l2_within_sla(Date.today)
          # wktime_helper.expire_unlock_history
          # wktime_helper.weekly_approve_l1_notifications(Date.today)


        end

        end



        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l2']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l2']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l2']
        if day.present? && hr.present? && min.present?
        date = Date.parse(day)
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if hr == '0' && min == '0'
          cronSt = "0 * * * *"
        else
          cronSt = "#{min} #{hr} * * #{date.wday}"
        end

        # cronSt= "45 23 * * *"
        scheduler.cron cronSt do
          wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.weekly_auto_approve(Date.today)
          # wktime_helper.expire_unlock_history
          # wktime_helper.weekly_approve_l2_notifications(Date.today)
          # wktime_helper.expire_unlock_history

        end

        end

        # scheduler.at '2014/12/24 2000' do
        #   puts "merry xmas!"
        # end
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_payroll_day']
        hr = Setting.plugin_redmine_wktime['wktime_payroll_hr']
        min = Setting.plugin_redmine_wktime['wktime_payroll_min']
        scheduler = Rufus::Scheduler.new #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3

        if day.present? && hr.present? && min.present?
        if hr == '0' && min == '0'
          cronSt = "0 * * * *"
        else
          cronSt = "#{min} #{hr} * * *"
        end
        wktime_helper = Object.new.extend(WktimeHelper)
       # expire_time = wktime_helper.check_expire_date_payroll
       # cronSt = "#{expire_time.min} #{expire_time.hour} * * #{expire_time.to_date.wday}"
        # cronSt= "12 19 * * *"
        scheduler.cron cronSt do
          # wktime_helper.weekly_auto_approve(expire_time)
          # wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
          # wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
          # wktime_helper.expire_unlock_history
          # wktime_helper.weekly_approve_l1_notifications(Date.today)

        end
        end


        # scheduler.at '2014/12/24 2000' do
        #   puts "merry xmas!"
        # end
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_payroll_day']
        hr = Setting.plugin_redmine_wktime['wktime_payroll_hr']
        min = Setting.plugin_redmine_wktime['wktime_payroll_min']
        if day.present? && hr.present? && min.present?
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
      #  wktime_helper = Object.new.extend(WktimeHelper)

       # expire_time = wktime_helper.check_expire_date_payroll
        # cronSt= "12 19 * * *"
       # cronSt = "#{expire_time.min} #{expire_time.hour} * * #{(expire_time-2.day).to_date.wday}"
        scheduler.cron cronSt do
          # wktime_helper.weekly_auto_approve(expire_time)
          # wktime_helper.monthly_approve_l2_notifications(expire_time)
          # wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
          # wktime_helper = Object.new.extend(WktimeHelper)
          # wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
          # wktime_helper.expire_unlock_history
          # wktime_helper.weekly_approve_l1_notifications(Date.today)

        end
        end

      end
    end
  else
    scheduler = Rufus::Scheduler.new
    scheduler.every '2m' do
      # count = count + 1
      # p "============  ---------#{Time.now}---"
      # Sync.sync_sql
    end
  end



  #
  # scheduler = Rufus::Scheduler.new
  # time="0 22 * * 2"
  # time1 = "59 16 * * 3 *"
  # time="*/5 * * * *"
  # scheduler.cron time do
  #   begin
  #     Rails.logger.info "==========Scheduler Started for attendance report=========="
  #
  #     wktime_helper = Object.new.extend(WktimeHelper)
  #     start_date=(Date.today-3).at_beginning_of_week
  #     end_date=start_date.at_end_of_week-2
  #     wktime_helper.get_new_attendance(start_date,end_date)
  #
  #   rescue Exception => e
  #     Rails.logger.info "Scheduler failed for attendance report: #{e.message}"
  #   end
  # end


  # scheduler.every '1s' do
  #   puts "change the oil filter!"
  # end

end



# Rails.configuration.to_prepare do
#
#
#
#
#
#
#
#
#
#
#
#
#
#   require 'rufus/scheduler'
#   scheduler = Rufus::Scheduler.new
#   time="0 22 * * 2"
#   time1 = "59 16 * * 3 *"
#   # time="*/5 * * * *"
#   # scheduler.cron time do
#   #   begin
#   #     Rails.logger.info "==========Scheduler Started for attendance report=========="
#   #
#   #     wktime_helper = Object.new.extend(WktimeHelper)
#   #     start_date=(Date.today-3).at_beginning_of_week
#   #     end_date=start_date.at_end_of_week-2
#   #     wktime_helper.get_new_attendance(start_date,end_date)
#   #
#   #   rescue Exception => e
#   #     Rails.logger.info "Scheduler failed for attendance report: #{e.message}"
#   #   end
#   # end
#
#   require 'rufus/scheduler'
#   scheduler = Rufus::Scheduler.new
#   month_time = '0 22 26 * *'
#   # month_time = '06 18 6 * *'
#   scheduler.cron  month_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     p "==========Scheduler Started for attendance report month========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today - 1.month)-1
#     end_date=Date.today
#     wktime_helper.get_new_attendance(start_date,end_date)
#     p "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#
#   week_time = '0 22 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     p "==========Scheduler Started for attendance report week111111111=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     wktime_helper.get_new_attendance(start_date,end_date)
#     p "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#   week_time = '25 12 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report 111111111111=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#   week_time = '20 13 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report week2222222222222222=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#   week_time = '20 14 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report week333333333333333333=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#   week_time = '20 15 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report week4444444444444444444=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#
#   week_time = '20 15 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report week55555555555555555555=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#   week_time = '20 16 * * 2'
#   # week_time = '13 18 6 * *'
#   scheduler.cron  week_time do
#     # do something every day, five minutes after midnight
#     # (see "man 5 crontab" in your terminal)
#     Rails.logger.info "==========Scheduler Started for attendance report week66666666666666666=========="
#     wktime_helper = Object.new.extend(WktimeHelper)
#     start_date=(Date.today-3).at_beginning_of_week
#     end_date=start_date.at_end_of_week-2
#     # wktime_helper.get_new_attendance(start_date,end_date)
#     Rails.logger.info "+++++++++++++++++++++++Scheduler Ended ++++++++++++++++++"
#   end
#
#
#
#
#
#
#
# #
# #   Rails.configuration.to_prepare do
# #     if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
# #         require 'rufus/scheduler'
# #
# #           # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
# #           day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l1']
# #           hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l1']
# #           min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l1']
# #           scheduler = Rufus::Scheduler.new #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
# #           if hr == '0' && min == '0' && day== '0'
# #             cronSt = "0 * * * *"
# #           else
# #             cronSt = "#{min} #{hr} #{day} * *"
# #           end
# #           cronSt= "43 23 * * *"
# #           scheduler.cron cronSt do
# #
# # p 55555555555555555555555555555555555555555555555555555555
# #
# #           end
# #
# #
# #     end
# #   end
# #
# #
# #
# #
# #   Rails.configuration.to_prepare do
# #     if ActiveRecord::Base.connection.table_exists? "#{Setting.table_name}"
# #       require 'rufus/scheduler'
# #
# #       if (!Setting.plugin_redmine_wktime['wktime_use_approval_system'].blank? && Setting.plugin_redmine_wktime['wktime_use_approval_system'].to_i == 1)
# #         # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
# #
# #       end
# #
# #
# #     end
# #   end
#
#
#
#   # scheduler.every '1s' do
#   #   puts "change the oil filter!"
#   # end
#
# end



class WktimeHook < Redmine::Hook::ViewListener
  def controller_timelog_edit_before_save(context={ })
    if !context[:time_entry].hours.blank? && !context[:time_entry].activity_id.blank?
      wktime_helper = Object.new.extend(WktimeHelper)
      status= wktime_helper.getTimeEntryStatus(context[:time_entry].spent_on,context[:time_entry].user_id)
      if !status.blank? && ('a' == status || 's' == status)
        # raise "#{l(:label_warning_wktime_time_entry)}"
        false
      end
    end
  end

  def view_layouts_base_html_head(context={})
    javascript_include_tag('wkstatus', :plugin => 'redmine_wktime') + "\n" +
        stylesheet_link_tag('lockwarning', :plugin => 'redmine_wktime')
  end

  def view_timelog_edit_form_bottom(context={ })
    showWarningMsg(context[:request])
  end

  def view_issues_edit_notes_bottom(context={})
    showWarningMsg(context[:request])
  end

  def showWarningMsg(req)
    wktime_helper = Object.new.extend(WktimeHelper)
    host_with_subdir = wktime_helper.getHostAndDir(req)
    "<div id='divError'><font color='red'>#{l(:label_warning_wktime_time_entry)}</font>
      <input type='hidden' id='getstatus_url' value='#{url_for(:controller => 'wktime', :action => 'getStatus',:host => host_with_subdir)}'>  
    </div>"
  end

  # Added expense report link in redmine core 'projects/show.html' using hook
  def view_projects_show_sidebar_bottom(context={})
    if !context[:project].blank?
      wktime_helper = Object.new.extend(WktimeHelper)
      host_with_subdir = wktime_helper.getHostAndDir(context[:request])
      project_ids = Setting.plugin_redmine_wktime['wkexpense_projects']
      if project_ids.blank? || (!project_ids.blank? && (project_ids == [""] || project_ids.include?("#{context[:project].id}"))) && User.current.allowed_to?(:view_time_entries, context[:project])
        "#{link_to(l(:label_wkexpense_reports), url_for(:controller => 'wkexpense', :action => 'reportdetail', :project_id => context[:project], :host => host_with_subdir))}"
      end
    end
  end
end



