
module EmployeeInfo
  module Patches
    module MemberPatch
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do
          # validate :validate_billable
          # validates :capacity,presence:true, numericality: {less_than: 100,:message=>"Utilization should not be grater than 100"},:if=>:validate_availablity

          # validates :billable,:inclusion => {:in => [true, false],:message => "Choose Billable or Non Billable"},:if=>:validate_billable
          # validates_uniqueness_of :billable, :scope => [:user_id], :if => :billable

          validate :validate_billable
          validates :capacity,presence:true

          # enum billable: [:red, :white, :sparkling]
          # validates_numericality_of :capacity, less_than: ->(self) { (self.capacity*100+self.other_capacity) < 100  }

          validate :capacity_is_less_than_total
          validate :capacity_is_grater_than_total
          # validate :validate_billable
          belongs_to :billable_type

          before_save :check_billable_capacity

          def check_billable_capacity
            if !self.billable_type.can_contributable
              self.capacity = 0
            end
          end

          def capacity_is_less_than_total

            errors.add(:Utilization, "should be less than or equal to #{(100-self.other_capacity).round}") if (self.capacity*100+self.other_capacity) > 100
          end
          def capacity_is_grater_than_total

            # p self.billable
            # # p self.shadow?

            errors.add(:Utilization, "should be greater than 0") if ((self.capacity <= 0) &&  [:"1",:"2"].include?(self.billable_type_id))
          end


          def user_billable?
            return self.billable == true
          end


          def validate_availablity
            current_capacity =  Member.where(:user_id=>self.user_id,:project_id=>self.project_id).map(&:capacity).sum
            total_capacity =  Member.where(:user_id=>self.user_id).map(&:capacity).sum
            other_capacity = total_capacity.to_f - current_capacity.to_f
            return (other_capacity+self.capacity)*100 < 100

          end
          def validate_billable
            p '===========me===='
            p self.billable_type_id
            if validate_with_class?
            if self.billable_type_id.nil? # !["billable" ,"shadow" ,"support"].include?(self.billable_type.name)
              errors.add(:Choose, "Please select type of support")
            end
           end
          end
          def validate_with_class?
            p "++++++++++=self.user.class.name +++++++++"
            p self.user.class.name
            p "++++++++++++++++end ++++++++++=="
            self.user.class.name == "User"
          end

          def self.capacity(member)
            cap = []
            total_capacity =   Member.where(:user_id=>member.user_id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum*100
            return ((cap.compact.sum)*100).round
          end

          def self.user_capacity(id)
            p '=======coolooo'
            cap = []
            p total_capacity =   Member.where(:user_id=>id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum*100
            return ((cap.compact.sum)*100).round
          end

          def self.available_capacity(member)
            cap = []
            p '================called thiyagu------------'
            p total_capacity =  Member.where(:user_id=>member.user_id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum
            p available_capacity = (1-(cap.compact.sum))*100
            return available_capacity.round
          end
          def self.current_project_capacity(member)
            p "++++++++++++++++++member ++++++++++++++++"
            p member
            p "++++++++++++++++end +++++++++++++"
            if member.present?
            total_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum*100
            return total_capacity.round
            end
          end

          def self.other_capacity(member)
            cap = []
            current_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
            total_capacity = Member.where(:user_id=>member.user_id).map{|x| cap << x.capacity if x.project.status==1 && x.capacity!=nil}#.map(&:capacity).sum
            other_capacity = ((cap.compact.sum).to_f - current_capacity.to_f)*100
            return other_capacity.round
          end
          def other_capacity
            cap = []
            current_capacity =  Member.where(:user_id=>self.user_id,:project_id=>self.project_id).map(&:capacity).sum
            total_capacity = Member.where(:user_id=>self.user_id).map{|x| cap << x.capacity if x.project.status==1 && x.capacity!=nil}#.map(&:capacity).sum
            other_capacity = ((cap.compact.sum).to_f - current_capacity.to_f)*100
            return other_capacity.round
          end

          def self.user_available_capacity(id)
            cap = [] 
            total_capacity =  Member.where(:user_id=>id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum
            available_capacity = (1-(cap.compact.sum))*100

            return available_capacity.round
          end

# user
#           def self.available_capacity(id)
#             total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
#             available_capacity = (1-total_capacity)*100
#             return available_capacity
#           end
#
#
#           def self.other_capacity(id)
#             current_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
#             total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
#             other_capacity = total_capacity.to_f - current_capacity.to_f
#             return other_capacity*100
#           end


          def concat_user_name_with_mail

            return "#{self.user.firstname rescue ""}#{self.user.lastname rescue ""}<#{self.user.mail rescue ""}>"
          end
          def used_capacity
            return self.capacity*100.round
          end

          # Non Billable users .

          def self.update_shadow_and_support_for_nonbillable
            non_billable_users_with_below_25_percentage = Member.find_by_sql("select * from members  where capacity > 0 and  capacity < 0.25 and billable=0")
            non_billable_users_with_below_25_percentage.each do |each_member|
              each_member.update_attributes(:billable=>"support",:capacity=>0)
           end
            non_billable_users_with_above_25_percentage = Member.find_by_sql("select * from members where capacity > 0 and  capacity < 0.25 and billable=0")
            non_billable_users_with_above_25_percentage.each do |each_member|
              each_member.update_attributes(:billable=>"shadow")
            end
          end



          def self.update_billable_non_billable_and_capacity

             find_users = Member.find_by_sql("select user_id from members group by user_id");
             find_users.each do |each_user|
               find_members = Member.find_by_sql("select * from members group by project_id HAVING  sum(capacity) <= 0 and user_id=#{each_user.user_id.to_i}  limit 2")
               find_members.each do |each_member|

                 mem = MemberHistory.find_or_initialize_by_user_id_and_project_id(each_member.user_id,each_member.project_id)
                  mem.capacity = 0.25
                  mem.billable = "billbale"
                  mem.start_date = Date.today
                  mem.end_date =   Date.today.end_of_year
                  # mem.created_by = each_member.user_id
                  mem.member_id=each_member.id
                  mem.save

                  each_member.capacity = 0.25
                  each_member.billable = "billbale"
                  each_member.save
                  # mem.created_by = each_member.user_id
                end 
              end 

          end

          def self.update_histories
            
                find_members = Member.find_by_sql("select * from members")
               find_members.each do |each_member|

                 mem = MemberHistory.find_or_initialize_by_user_id_and_project_id(each_member.user_id,each_member.project_id)
                  mem.capacity = each_member.capacity
                  mem.billable = each_member.billable
                  mem.start_date = Date.today
                  mem.end_date =   Date.today.end_of_year
                  # mem.created_by = each_member.user_id
                  mem.member_id=each_member.id
                  mem.save
                  
                  # mem.created_by = each_member.user_id
                end 
           
          end

          def type_of_supports
           #bill =  BillableType.where(:is_active => true)
           #bill.map{|x|[x.name.capitalize, x.id]}
            BillableType.all.map{|x|[x.name.capitalize, x.id]}
          end
          def type_of_support_list
            BillableType.all.map{|x|[x.name.capitalize, x.name]}
          end

          def disabled_support
            BillableType.where(:can_contributable=> true).map{|x|[x.id]}
          end
          def non_support_types
            BillableType.where(:can_contributable=> false).map{|x|[x.name.capitalize, x.id]}
          end
          def name_of_support
            BillableType.all.map{|x| [x.name.capitalize]}
          end
       end


      end

    end

    module ApplicationHelperPatch
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          def principals_check_box_tags(name, principals)
            s = ''
            principals.each do |principal|
              s << "<label>#{ check_box_tag name, principal.id, false, :id => "member_ship_check",:member_available_value=> Member.user_available_capacity(principal),:member_available=> Member.user_available_capacity(principal) > 0 ? true : false } #{h principal} (Available: #{Member.user_available_capacity(principal)}%)</label>\n"
            end
            s.html_safe
          end

          def with_format(format, &block)
            old_formats = formats
            self.formats = [format]
            block.call
            self.formats = old_formats
            nil
          end
        end
      end
    end

  end
end



