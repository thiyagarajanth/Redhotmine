class KanbanPane < ActiveRecord::Base
  unloadable

  belongs_to  :kanban_state
  belongs_to  :kanban
  belongs_to  :role
  has_many    :kanban_card
  has_many    :issue, :through=>:kanban_card, :order => "priority_id ASC, updated_on DESC, issue_id DESC"

  validates_presence_of :kanban_state
  before_destroy :check_cards_and_workflow

  PROJECT_VIEW = 0
  GROUP_VIEW = 1
  USER_VIEW = 2

  attr_accessor :view

  scope :by_kanban, lambda {|kanban|
    kanban_id = Kanban.to_id(kanban)
    where(:kanban_id => kanban_id)
  }

  def open_cards()
  	is_closed_id = IssueStatus.closed_id;
  	self.kanban_card.reject{|card| card.issue.status_id == is_closed_id}
  end

  def closed_cards()
    is_closed_id = IssueStatus.closed_id;
    self.kanban_card.reject{|card| card.issue.status_id != is_closed_id}
  end

  def self.to_id(pane)
    pane_id = pane.nil? ? nil : pane.is_a?(KanbanPane) ? pane.id : pane.to_i
  end

  def self.to_pane(pane)
    pane = pane.nil? ? nil : pane.is_a?(KanbanPane) ?  pane : KanbanPane.find(pane);
  end

  def self.pane_by(state,kanban)
    return KanbanPane.find_by_kanban_id_and_kanban_state_id(Kanban.to_id(kanban), KanbanState.to_id(state))
  end


  # Get Pane's or User's WIP limit, don't name it wip_limit to avoid naming conflict
  def wip_limit_by_view(group=nil, user=nil)
    if self.wip_limit_auto == false
      return self.wip_limit
    end

    role = Role.find(self.role_id);
    project = self.kanban.project if project.nil?
    if (group.nil? and user.nil?)
      @view = PROJECT_VIEW
      wip_limit = project.wip_limit(self.role_id)
    elsif !user.nil?
      # User.wip_limit if he has the same role with pane
      @view = USER_VIEW
      user = User.to_user(user)
      wip_limit = (user.roles_for_project(project).include?(role) or role.nil?) ? user.wip_limit : 0
    else
      # Group's wip_limit is equal to all his members that work in this pane
      @view = GROUP_VIEW
      group = Group.to_group(group)
      wip_limit = group.wip_limit(self.role_id, project);
    end
    wip_limit
  end

  def self.wip(pane,group=nil, user=nil)
    return 0 if pane.nil?
    pane_id = KanbanPane.to_id(pane)
    if !user.nil?
      user_id = User.to_id(user)
      return KanbanCard.by_user(user_id).in_pane(pane_id).size
    elsif !group.nil?
      group_id = Group.to_group(group)
      return KanbanCard.by_group(group_id).in_pane(pane_id).size
    else
      return KanbanCard.in_pane(pane_id).size
    end
  end

  def accept_user?(user)

    #1 I still have space?
    if self.wip_limit_by_view() <= KanbanPane.wip(self)
      puts "wip_limit #{self.wip_limit_by_view()} <= wip #{KanbanPane.wip(self)}"
      return false 
    end

    user = user.is_a?(User) ? User.to_user(user) : Group.to_group(user)
    project = self.kanban.project

    # He is a member of my project?
    p "+++++++++=user+++++++++"
    p user
    p "+++++++++++++++++"
    if !user.member_of?(project)
      puts "user #{user.alias} is not a member of project #{project.name}"
      return false
    end

    # user match my role?
    if !user.has_role?(self.role_id, project)
      puts "user #{user.alias} does not have a role #{self.role_id}"
      return false
    end

    true
  end

  def check_cards_and_workflow
    count = self.kanban_card.count
    if count > 0
      errors.add("","Cannot delete pane #{self.name}, #{count} cards still in this pane!")
    end

    flows = KanbanWorkflow.find(:all, :conditions => ["(old_state_id = ? or new_state_id = ?) and kanban_id = ?", self.kanban_state.id, self.kanban_state.id, self.kanban.id])
    count = 0
    count = flows.size if !flows.nil?
    if count > 0
      errors.add("","Cannot delete pane #{self.name}, #{count} workflow still associated with this pane!")
    end
    errors.blank?
  end
end



