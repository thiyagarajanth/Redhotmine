module Cas
  module Infectors
    module Mailer
      module ClassMethods; end
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          # Builds a mail for notifying to_users and cc_users about a new issue
          def issue_add(issue, to_users, cc_users)
            redmine_headers 'Project' => issue.project.identifier,
                            'Issue-Id' => issue.id,
                            'Issue-Author' => issue.author.login
            redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
            message_id issue
            references issue
            @author = issue.author
            @issue = issue
            @users = to_users + cc_users
            @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue)
            if to_users.map(&:auth_source_id).include?(nil) || cc_users.map(&:auth_source_id).include?(nil)
              urls = @issue_url.split('.com')
              @issue_client_url = "https://"+Redmine::Configuration['inia_external_url']+urls[1]
            end
            mail :to => to_users.map(&:mail),
                 :cc => cc_users.map(&:mail),
                 :subject => "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] (#{issue.status.name}) #{issue.subject}"
          end

          # Builds a mail for notifying to_users and cc_users about an issue update
          def issue_edit(journal, to_users, cc_users)
            issue = journal.journalized
            redmine_headers 'Project' => issue.project.identifier,
                            'Issue-Id' => issue.id,
                            'Issue-Author' => issue.author.login
            redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
            message_id journal
            references issue
            @author = journal.user
            s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
            s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
            s << issue.subject
            @issue = issue
            @users = to_users + cc_users
            @journal = journal
            @journal_details = journal.visible_details(@users.first)
            @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue, :anchor => "change-#{journal.id}")
            if to_users.map(&:auth_source_id).include?(nil) || cc_users.map(&:auth_source_id).include?(nil)
              urls = @issue_url.split('.com')
              @issue_client_url = "https://"+Redmine::Configuration['inia_external_url']+urls[1]
            end
            mail :to => to_users.map(&:mail),
                 :cc => cc_users.map(&:mail),
                 :subject => s
          end

        end
      end

    end
  end

end
