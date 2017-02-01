module ApplicationControllerOverridePatch
  def self.included(base)
    base.class_eval do

      # before_filter CASClient::Frameworks::Rails::Filter, :if => proc {|c| !request.xhr?}
      
      before_filter :check_external_users , :session_expiration, :user_setup, :force_logout_if_password_changed, :check_if_login_required, :check_password_change, :set_localization, :validate_parameters

      rescue_from ::Unauthorized, :with => :deny_access
      rescue_from ::ActionView::MissingTemplate, :with => :missing_template

      include Redmine::Search::Controller
      include Redmine::MenuManager::MenuController
      helper Redmine::MenuManager::MenuHelper

      def check_external_users
        if request.headers["external"] == 'true' && !request.xhr? && !api_request? #&& !request.env['HTTP_USER_AGENT'].include?('iOS')
           CASClient::Frameworks::Rails::Filter.filter(self)
        end
      end

      before_filter :beforeFilter

      def beforeFilter
        $request = request
      end


      def verify_message_api_key
        if api_request?
          if request.headers["Auth-key"].present?
            auth = validate_auth_key
            if request.present? && request.headers["X-Redmine-API-Key"].present?
              if (key = api_key_from_request)
                user = User.find_by_api_key(key)
                unless user.present?
                  render :json => {:errors => 'Invalid Api-Key.'}, :status => 401
                end
              else
                render :json => {:errors => 'Invalid Api-Key.'}, :status => 401
              end
            end
            if auth
              true
            else
              render :json => {:errors => 'Invalid Auth-Key.'}, :status => 401
            end
          else
            render :json => {:errors => 'Auth-Key not found.'}, :status => 401
          end
        end
      end

      def validate_auth_key
        find_valid_key = Redmine::Configuration['ios_api_key']
        (find_valid_key == request.headers["Auth-key"].to_s) ? true : false
      end

      def validate_parameters
        errors = []
        verify_message_api_key
        if api_request? && params[:issue].present?
          if params[:issue][:status_id].present?
            status = IssueStatus.find_by_name(params[:issue][:status_id])
            if status.present?
              params[:issue][:status_id] = status.id
            else
              errors <<  "status not found..!"
            end
          end
          if params[:issue][:tracker_id].present?
            p tracker = Tracker.find_by_name(params[:issue][:tracker_id])
            if tracker.present?
              params[:issue][:tracker_id] = tracker.id.to_s
            else
              errors << "tracker not found..!"
            end
          end
          if params[:issue][:priority_id].present?
            priority = IssuePriority.find_by_name(params[:issue][:priority_id])
            if priority.present?
              params[:issue][:priority_id] = priority.id.to_s
            else
              errors <<  "priority not found..!"
            end
          end
          # if params[:issue][:assigned_to_id].present?
          #   user = UserOfficialInfo.find_by_employee_id(params[:issue][:assigned_to_id])
          #   if user.present?
          #     params[:issue][:assigned_to_id] = user.user_id
          #   else
          #     errors << "Employee not found..!"
          #   end
          # end
          if errors.present?
            render :json => errors,:errors=>errors, :layout => nil and return true
          end
        end
      end


      def session_expiration
        if session[:user_id]
          if session_expired? && !try_to_autologin
            set_localization(User.active.find_by_id(session[:user_id]))
            self.logged_user = nil
            flash[:error] = l(:error_session_expired)
            require_login
          else
            session[:atime] = Time.now.utc.to_i
          end
        end
      end

      def session_expired?
        if Setting.session_lifetime?
          unless session[:ctime] && (Time.now.utc.to_i - session[:ctime].to_i <= Setting.session_lifetime.to_i * 60)
            return true
          end
        end
        if Setting.session_timeout?
          unless session[:atime] && (Time.now.utc.to_i - session[:atime].to_i <= Setting.session_timeout.to_i * 60)
            return true
          end
        end
        false
      end

      def start_user_session(user)
        session[:user_id] = user.id
        session[:ctime] = Time.now.utc.to_i
        session[:atime] = Time.now.utc.to_i
        if user.must_change_password?
          session[:pwd] = '1'
        end
      end

      def user_setup
        # Check the settings cache for each request
        Setting.check_cache
        # Find the current user
        User.current = find_current_user
        logger.info("  Current user: " + (User.current.logged? ? "#{User.current.login} (id=#{User.current.id})" : "anonymous")) if logger
         
      end

      def find_current_user
          user = nil
          unless api_request?

            if session[:user_id].present?
              user = User.active.find(session[:user_id]) rescue nil
            elsif session[:cas_user].present?
              user = User.active.find_by_login(session[:cas_user]) rescue nil
            elsif autologin_user = try_to_autologin
              user = autologin_user
            elsif params[:format] == 'atom' && params[:key] && request.get? && accept_rss_auth?
              # RSS key authentication does not start a session
              user = User.find_by_rss_key(params[:key])
            end
          end
          if user.nil? && Setting.rest_api_enabled? && accept_api_auth?
            if (key = api_key_from_request)
              user = User.find_by_api_key(key)
              user
            elsif request.authorization.to_s =~ /\ABasic /i
              # HTTP Basic, either username/password or API key/random
              authenticate_with_http_basic do |username, password|
                user = User.try_to_login(username, password) || User.find_by_api_key(username)
              end
              if user && user.must_change_password?
                render_error :message => 'You must change your password', :status => 403
                return
              end
            end
            # Switch user if requested by an admin user
           if user && user.admin? && (username = api_switch_user_from_request)
              su = User.find_by_login(username)
              if su && su.active?
                logger.info("  User switched by: #{user.login} (id=#{user.id})") if logger
                user = su
              else
                render_error :message => 'Invalid X-Redmine-Switch-User header', :status => 412
              end
            end
          end
          if user && user.auth_source != nil && !session[:cas_user].present? && !verify_message_api_key
            render_error :message => 'You unable to access this URL.', :status => 403
            cookies.delete(autologin_cookie_name)
            Token.delete_all(["user_id = ? AND action = ?", User.current.id, 'autologin'])
            self.logged_user = nil
            return
          end
          user
        end

    end
  end
end
