class Wktime < ActiveRecord::Base
unloadable
include Redmine::SafeAttributes

  belongs_to :user
  belongs_to :user, :class_name => 'User', :foreign_key => 'submitter_id'
  belongs_to :user, :class_name => 'User', :foreign_key => 'statusupdater_id'
  
  acts_as_customizable
  
  attr_protected :user_id, :submitter_id, :statusupdater_id
  safe_attributes 'hours', 'notes', 'begin_date', 'status', 'submitted_on', 'statusupdate_on'

  validates_presence_of :user_id, :hours, :begin_date, :status
  validates_numericality_of :hours, :message => :invalid
  validates_length_of :notes, :maximum => 255, :allow_nil => true
  validate :validate_wktime

  def initialize(attributes=nil, *args)
    super
  end
  
  def validate_wktime
    errors.add :hours, :invalid if hours && (hours < 0 || hours >= 1000)
#    errors.add :user_id, :invalid if user.nil?
#	errors.add :submitter_id, :invalid if submitter.nil?
#    errors.add :statusupdater_id, :invalid if approver.nil?
  end
  
  def hours=(h)
    write_attribute :hours, (h.is_a?(String) ? (h.to_hours || h) : h)
  end

  def hours
    h = read_attribute(:hours)
    if h.is_a?(Float)
      h.round(2)
    else
      h
    end
  end

    def submitted_on=(date)
		super
		if submitted_on.is_a?(Time)
		  self.submitted_on = submitted_on.to_date
		end
	end
	
	def statusupdate_on=(date)
		super
		if statusupdate_on.is_a?(Time)
		  self.statusupdate_on = statusupdate_on.to_date
		end
  end

  
  def migrate_ptos
    require 'csv'
    m = []
    CSV.foreach("/home/local/OFS1/thiyagarajant/Desktop/pto.csv") do |row|
    m << row
    end
    array_of_hashes = []
    m.each_with_index do |record, i|
      a = record[1].split('/')
      array_of_hashes << {'emp_id' => record[0], 'fromDate' => "#{a[2]}-#{a[0].length == 1 ? '0'+a[0] : a[0]}-#{a[1].length == 1 ? '0'+a[1] : a[1] }", 'toDate' => "#{a[2]}-#{a[0]}-#{a[1]}", 'leave' => record[3]} if i!=0
    end
    count = 0
    missing = []
    array_of_hashes.each do|rec|
      p '===================================================================='
      user = UserOfficialInfo.find_by_employee_id(rec['emp_id']).user_id
      find_user_project = Member.find_by_sql("select * from members where user_id=#{user} order by capacity DESC limit 1")
      pto = TimeEntryActivity.find_by_name('pto')
      entries =   TimeEntry.where(:spent_on =>rec['fromDate'], :user_id => user).map(&:activity_id).include?(pto.id)
      if !entries && find_user_project.present?
        missing << [rec['emp_id'], user, rec['fromDate']]
        count = count + 1
        find_tracker = Tracker.where(:name=>'support')
        if find_tracker.present?
          find_tracker_id = find_tracker.first.id
        else
          errors << "Unable apply for Leave, PTO Activity Not Found .!"
        end
        find_issue = Issue.where(:project_id=>find_user_project.first.project_id,:tracker_id=>find_tracker_id,:subject=>'PTO')
        if find_issue.present?
          find_issue_id = find_issue.first.id
        else
          find_issue = Issue.new(:subject=>"PTO",:project_id=>find_user_project.first.project_id,:tracker_id=>find_tracker_id,:author_id=>user,:assigned_to_id=>user)
          if find_issue.save(:validate => false)
            find_issue_id = find_issue.id
          end
          # p find_issue.errors
          # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
        end
        find_activity_id = Enumeration.where(:name=>'PTO').last.id
        p '---------- okay ------------'
        time_entry = TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(find_user_project.first.project_id,user,find_activity_id,rec['fromDate'],find_issue_id)
        if time_entry.present? && time_entry.id.blank?
          time_entry.project_id = find_user_project.first.project_id
          time_entry.activity_id = find_activity_id

          time_entry.issue_id = find_issue_id
          time_entry.hours = rec['leave'].to_i == 1 ? 8 : 4
          time_entry.comments= time_entry.comments.present? ? time_entry.comments : 'PTO'
          time_entry.save
        end
        # p time_entry.errors
      end
    end
    p '=========total un-----'
    # p count
    # p m.count
    # p missing
  end

  def migrate_onDuty
    require 'csv'
    m = []
    CSV.foreach("/home/local/OFS1/thiyagarajant/Desktop/onDuty.csv") do |row|
    m << row
    end
    # p m
    array_of_hashes = []
    m.each_with_index do |record, i|
      a = record[2].split('/')
      array_of_hashes << {'emp_id' => record[0], 'fromDate' => "#{a[2].length == 2 ? '20'+a[2] : a[2]}-#{a[0].length == 1 ? '0'+a[0] : a[0]}-#{a[1].length == 1 ? '0'+a[1] : a[1] }", 'toDate' => "#{a[2]}-#{a[0]}-#{a[1]}", 'hours' => record[1]} if i!=0
    end
    p '======ok===='
    count = 0
    missing = []
    array_of_hashes.each do|rec|
      p '===================================================================='
      user = UserOfficialInfo.find_by_employee_id(rec['emp_id']).user_id
      find_user_project = Member.find_by_sql("select * from members where user_id=#{user} order by capacity DESC limit 1")
      pto = TimeEntryActivity.find_by_name('pto')
      entries =   TimeEntry.where(:spent_on =>rec['fromDate'], :user_id => user).map(&:activity_id).include?(pto.id)
      if !entries && find_user_project.present?
        missing << [rec['emp_id'], user, rec['fromDate']]
        count = count + 1
        find_tracker = Tracker.where(:name=>'support')
        if find_tracker.present?
          find_tracker_id = find_tracker.first.id
        else
          errors << "Unable apply for Leave, PTO Activity Not Found .!"
        end
        find_issue = Issue.where(:project_id=>find_user_project.first.project_id,:tracker_id=>find_tracker_id,:subject=>'OnDuty')
        if find_issue.present?
          find_issue_id = find_issue.first.id
        else
          find_issue = Issue.new(:subject=>"OnDuty",:project_id=>find_user_project.first.project_id,:tracker_id=>find_tracker_id,:author_id=>user,:assigned_to_id=>user)
          if find_issue.save(:validate => false)
            find_issue_id = find_issue.id
          end
          # p find_issue.errors
          # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
        end
        find_activity_id = Enumeration.where(:name=>'OnDuty').last.id
        p '---------- okay ------------'
        time_entry = TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(find_user_project.first.project_id,user,find_activity_id,rec['fromDate'],find_issue_id)
        if time_entry.present? && time_entry.id.blank?
          time_entry.project_id = find_user_project.first.project_id
          time_entry.activity_id = find_activity_id

          time_entry.issue_id = find_issue_id
          time_entry.hours = rec['hours']
          time_entry.comments= time_entry.comments.present? ? time_entry.comments : 'OnDuty'
          time_entry.save
        end
        # p time_entry.errors
      end
    end
  end 
end
