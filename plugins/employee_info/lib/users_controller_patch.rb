module UsersControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:

     def create

        @user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
        @user.safe_attributes = params[:user]
        @user.admin = params[:user][:admin] || false
        @user.login = params[:user][:login]
        @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation] unless @user.auth_source_id
        @user.pref.attributes = params[:pref]

        if @user.save
          UserOfficialInfo.build(@user.id,params[:user_official_info].to_i)
          Mailer.account_information(@user, @user.password).deliver if params[:send_information]

          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_user_successful_create, :id => view_context.link_to(@user.login, user_path(@user)))
              if params[:continue]
                attrs = params[:user].slice(:generate_password)
                redirect_to new_user_path(:user => attrs)
              else
                redirect_to edit_user_path(@user)
              end
            }
            format.api  { render :action => 'show', :status => :created, :location => user_url(@user) }
          end
        else
          @auth_sources = AuthSource.all
          # Clear password input
          @user.password = @user.password_confirmation = nil

          respond_to do |format|
            format.html { render :action => 'new' }
            format.api  { render_validation_errors(@user) }
          end
        end
      end


      def update

        # user_location =  params[:user][:custom_field_values]["97"] rescue ''
        @user.admin = params[:user][:admin] if params[:user][:admin]
        @user.login = params[:user][:login] if params[:user][:login]
        if params[:user][:password].present? && (@user.auth_source_id.nil? || params[:user][:auth_source_id].blank?)
          @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation]
        end
        @user.safe_attributes = params[:user]
        # Was the account actived ? (do it before User#save clears the change)
        was_activated = (@user.status_change == [User::STATUS_REGISTERED, User::STATUS_ACTIVE])
        # TODO: Similar to My#account
        @user.pref.attributes = params[:pref]
        if @user.present?
          UserOfficialInfo.build(@user.id,params[:user_official_info].to_i) if params[:user_official_info].to_i > 0
        end
        #to save location in userofficialinfo
        # if user_location.present?
        #   usr = UserOfficialInfo.find_by_user_id(params[:id].to_i)
        #   p usr
        #   usr.location_type = user_location
        #   usr.save
        #   p usr
        # end
        if @user.save
          @user.pref.save
          if was_activated
            Mailer.account_activated(@user).deliver
          elsif @user.active? && params[:send_information] && @user.password.present? && @user.auth_source_id.nil?
            Mailer.account_information(@user, @user.password).deliver
          end

          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_update)
              redirect_to_referer_or edit_user_path(@user)
            }
            format.api  { render_api_ok }
          end
        else
          @auth_sources = AuthSource.all
          @membership ||= Member.new
          # Clear password input
          @user.password = @user.password_confirmation = nil

          respond_to do |format|
            format.html { render :action => :edit }
            format.api  { render_validation_errors(@user) }
          end
        end
      end

     def edit_membership
       @membership = Member.edit_membership(params[:membership_id], params[:membership], @user)

       if params[:membership].present?
         @membership.role_ids = params[:membership][:role_ids]
         @membership.billable_type_id=params[:billable_type_id].present? ? params[:billable_type_id] : ""
         @membership.capacity=params[:capacity].present? ? params[:capacity].to_f/100 : 0.0
       end

       @membership.save
       respond_to do |format|
         format.html { redirect_to edit_user_path(@user, :tab => 'memberships') }
         format.js
       end
     end

     def destroy_membership
       # stroy_membership
       @membership = Member.find(params[:membership_id])
       if @membership.deletable?
         @membership.destroy
       end
       respond_to do |format|
         format.html { redirect_to edit_user_path(@user, :tab => 'memberships') }
         format.js
       end
     end


  end
  end
  end