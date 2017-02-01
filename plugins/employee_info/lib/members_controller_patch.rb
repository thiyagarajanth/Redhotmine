module MembersControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # helper :employee_info
      def create
        p '5555555'
        members = []
        if params[:membership]
          if params[:membership][:user_ids]

            attrs = params[:membership].dup
            user_ids = attrs.delete(:user_ids)
            user_ids.each do |user_id|

              members << Member.new(:role_ids => params[:membership][:role_ids], :user_id => user_id,:billable_type_id=> params[:billable].present? ? params[:billable] : "",:capacity=>params[:member_capacity].present? ? params[:member_capacity].to_f/100 : 0.0)
              p '========='
              p members
              p '=========='
            end
          else
           members << Member.new(:role_ids => params[:membership][:role_ids], :user_id => params[:membership][:user_id],:billable_type_id=> params[:billable].present? ? params[:billable] : "",:capacity=>params[:member_capacity].present? ? params[:member_capacity].to_f/100 : 0.0)
          end
          p 'ffffffff'
          p members
          @project.members << members
          p '666666666666'
        end

        respond_to do |format|
          format.html { redirect_to_settings_in_projects }
          p '**********'
          format.js { @members = members }
          p '==========////////'
          format.api {
            @member = members.first
            if @member.valid?
              render :action => 'show', :status => :created, :location => membership_url(@member)
            else
              render_validation_errors(@member)
            end
          }
        end
      end


      def update
      
         if params[:membership]
          @member.role_ids = params[:membership][:role_ids]
          @member.billable_type_id=params[:billable_type_id] 
          @member.capacity=params[:capacity].present? ? params[:capacity].to_f/100 : 0.0
        end
        saved = @member.save
        respond_to do |format|
          format.html { redirect_to_settings_in_projects }
          format.js
          format.api {
            if saved
              render_api_ok
            else
              render_validation_errors(@member)
            end
          }
        end
      end

      


  end
  end
end