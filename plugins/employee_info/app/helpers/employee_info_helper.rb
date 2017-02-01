module EmployeeInfoHelper

  def capacity(member)
    cap = []
    total_capacity =   Member.where(:user_id=>member.user_id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum*100
    return (cap.compact.sum)*100.round
  end

  def available_capacity(member)
    cap = []
    total_capacity =  Member.where(:user_id=>member.user_id).map{|x| cap << x.capacity if x.project.status==1}#.map(&:capacity).sum
    available_capacity = (1-(cap.compact.sum))*100
    return available_capacity.round
  end
  def get_role(project)
    # return "yes"
 #   find_member =  Member.find_by_sql("select m.id from members m
 # join member_roles mr on mr.member_id=m.id
 # join roles r on r.id=mr.role_id
 # where r.name in ('CO','DO','Manager')  and m.user_id=#{User.current.id} and m.project_id=#{project.id} limit 1")
 #     if find_member.present? || User.current.admin?
 #       return "true"
 #     else
 #       return "false"
 #     end
 return "true"
  end

  def get_internal_role()
    # return "yes"
   Role.givable_internal.map(&:id)

  end

  def get_role_with_member(member_id)
return "yes"
#     find_member = Member.find(member_id)
#      project_id=find_member.project_id
#     find_member =  Member.find_by_sql("select m.id from members m
# join member_roles mr on mr.member_id=m.id
# join roles r on r.id=mr.role_id
# where r.name in ('co','do')  and m.user_id=#{User.current.id} and m.project_id=#{project_id} limit 1")
#     if find_member.present? || User.current.admin?
#       return "yes"
#     else
#       return "no"
#     end
  end

  def get_user_department
    # User.find(User.current).user_official_info.department != "Delivery Engineering"    
    User.current.admin
  end
end
