module EKanban
  module Hooks
  	class KanbanSettingHook  < Redmine::Hook::ViewListener
      	def helper_projects_settings_tabs(context = {})
          #if User.current.allowed_to?(:new_tab_action, context[:project])
              context[:tabs].push({ :name    => 'ProjectGoal',
                                    :action  => :setup,
                                    :partial => 'kanbans/setup',
                                    :label   => :label_kanban})
          #end
        end
 	  end


    class ControllerIssuesSaveHook < Redmine::Hook::ViewListener

      def tracker_changed?(issue, card)
      	return card.kanban_pane.Kanban.tracker_id != issue.tracker_id
      end

      def create_kanban_from_issue(issue)
      	kanban = Kanban.new()
      	kanban.name = "Created by system with issue #{issue.id}"
      	kanban.project_id = issue.project_id
      	kanban.tracker_id = issue.tracker_id
      	kanban.update_attribute(:is_valid,true);
        # kanban_pane is invalid here, there's no context
      	return kanban_pane
      end

      def controller_issues_new_after_save(context={})
      	card = KanbanCard.build(context[:issue], context[:journal])
      	true
      end

      # This callback will be invoked from issue's update action when user update issue from "issues"
      # Issue updated from Kanban will go though another path, kanban_card's update action.
      def controller_issues_edit_after_save(context={})

       	# Assume the validation has been done in the validate callback
       	issue = context[:issue]
       	card = KanbanCard.find_by_issue_id(issue.id)
        if card.nil?

          card = KanbanCard.build(issue, context[:journal])
          return false if card.nil?
        end

        old_card = card.dup
       	assignee = issue.assigned_to
        new_state = IssueStatusKanbanState.state_id(issue.status_id, issue.tracker_id)
        kanban = Kanban.find_by_project_id_and_tracker_id_and_is_valid(issue.project_id,issue.tracker_id,true)
        return true if kanban.nil?
        new_pane = KanbanPane.pane_by(new_state,kanban)
        return false if new_pane.nil?

        # Tracker changed.
       	if kanban.id != card.kanban_pane.kanban.id
            old_state = new_state
            old_pane  = new_pane
       	else
            old_state = card.kanban_pane.kanban_state_id
            old_pane  = card.kanban_pane
        end
        return false if !KanbanWorkflow.transition_allowed?(old_state,new_state,kanban.id)

        journal = context[:journal]
        p journal
        p journal.details
        detail = journal.details
        detail = journal.details.detect {|x| x.prop_key == "estimated_hours"}


        #Assignee changed
        if !detail.nil?

          old_assignee = detail.old_value;
          card.developer_id = assignee.id if assignee.has_role?("Developer", issue.project)
          card.verifier_id  = assignee.id if assignee.has_role?("Verifier", issue.project)
        end

    		#kanban card update
    		card.kanban_pane_id = new_pane.id

        if card.save
                   KanbanCardJournal.build(old_card,card,journal)
        end
      end
    end
  end
end
