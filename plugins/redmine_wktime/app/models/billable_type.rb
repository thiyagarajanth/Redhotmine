class BillableType < ActiveRecord::Base
  include Redmine::SafeAttributes
  has_one :member

  def migrate_support_type #Member Table billabel field migrate
  	a = BillableType.find_or_initialize_by_name('Billable')
  	a.is_billable = true
  	a.can_contributable = true
  	a.is_active = true
  	a.save

  	b = BillableType.find_or_initialize_by_name('Support')
  	b.is_billable = false
  	b.can_contributable = false
  	b.is_active = true
  	b.save

  	c = BillableType.find_or_initialize_by_name('Shadow')
  	c.is_billable = false
  	c.can_contributable = true
  	c.is_active = true
  	c.save
  	Member.where(:billable => 'billable').update_all(:billable_type_id =>a.id )
  	Member.where(:billable => 'shadow').update_all(:billable_type_id =>c.id )
  	Member.where(:billable => 'support').update_all(:billable_type_id =>b.id )
  end

  def migrate_member_histroy
     Member.all.each do |m|
       mh = MemberHistory.find_or_initialize_by_member_id(m.id)
       mh.user_id = m.user_id
       mh.project_id=m.project_id
       mh.billable=m.billable
       mh.capacity=m.capacity
       mh.billable_type_id = m.billable_type_id
       if mh.start_date.nil?
         mh.start_date=Date.today.beginning_of_year
         mh.end_date=Date.today.end_of_year
       end
       mh.save
     end
  end

  def migrate_missing_billable
    Member.where("billable_type_id >3").each do |rec|
      rec.billable = rec.billable_type.name
      rec.save
    end
  end
end
