# include DashboardHelper
module ProjectsControllerPatch

  BLOCKS = { 'issuesassignedtome' => :label_assigned_to_me_issues,
             'issuesreportedbyme' => :label_reported_issues,
             'issueswatched' => :label_watched_issues,
             'news' => :label_news_latest,
             'calendar' => :label_calendar,
             'documents' => :label_document_plural,
             'timelog' => :label_spent_time,
             'overduetasks' => :label_overdue_tasks,
             'unmanageabletasks' => :label_unmanageable_tasks,
             'issues_burndown_chart' => :label_issues_burndown_chart,
             'work_burndown_chart' => :label_work_burndown_chart,
             'story_burndown_chart' => :label_story_burndown_chart,
             'texteditor' => :label_texteditor
  }.merge(Redmine::Views::MyPage::Block.additional_blocks).freeze

  DEFAULT_LAYOUT = {  'left' => ['issuesassignedtome'],
                      'right' => ['issuesreportedbyme']
  }.freeze

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
      # helper :search

      # include SearchHelper
      # Insert overrides here, for example:
      def show
        @project= Project.find(params[:id])
        retrieve_dash_board_query
        sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
        sort_update(
            @query.sortable_columns)
        @query.sort_criteria = sort_criteria.to_a

        @user = User.current
        @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
        p "+++++++++++++++++@project_preference+++++++++++++++++"
        p @project_preference
        p "++++++++++=end ++++++++++++++++="
        @blocks = @project_preference[:my_page_layout] || DEFAULT_LAYOUT
        # try to redirect to the requested menu item
        if params[:jump] && redirect_to_project_menu_item(@project, params[:jump])
          return
        end

        @users_by_role = @project.users_by_role
        @subprojects = @project.children.visible.all
        @news = @project.news.limit(5).includes(:author, :project).reorder("#{News.table_name}.created_on DESC").all
        @trackers = @project.rolled_up_trackers

        cond = @project.project_condition(Setting.display_subprojects_issues?)

        @open_issues_by_tracker = Issue.visible.open.where(cond).group(:tracker).count
        @total_issues_by_tracker = Issue.visible.where(cond).group(:tracker).count

        if User.current.allowed_to?(:view_time_entries, @project)
          @total_hours = TimeEntry.visible.where(cond).sum(:hours).to_f
        end


        respond_to do |format|
          format.html
          format.api
        end
      end

      def retrieve_dash_board_query
        @find_dashboard_query = DashboardQuery.where(:project_id=>@project.id,:user_id=>User.current.id)
          # @query=nil
        if @find_dashboard_query.present?
          if api_request? || params[:set_filter]
            @init_filters={ 'status_id' => {:operator => "o", :values => [""]} }
            @find_dashboard_query.last.update_attributes(:filters=> @init_filters)
          end
          @query = @find_dashboard_query.last
        else
           @init_filters={ 'status_id' => {:operator => "o", :values => [""]} }
          @query ||= DashboardQuery.new(:name => "_", :filters => @init_filters)
          @query.user_id=User.current.id
          @query.project_id= @project.id
        end

      end

   end

      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
  end
  module InstanceMethods
    # Here, I include helper like this (I've noticed how the other controllers do it)
    # helper :queries
    include ApplicationHelper

    def index_with_filters
      # ...
      # do stuff
      # ...
    end
  end # module
  end


