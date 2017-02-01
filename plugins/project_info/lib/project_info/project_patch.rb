module ProjectInfo
  module Patches
    module ProjectPatch
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do

          # has_one :project_location,
          belongs_to :project_location,:class_name => 'ProjectLocation', :foreign_key => 'location_id'
          belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'

          safe_attributes 'name',
                          'description',
                          'homepage',
                          'is_public',
                          'identifier',
                          'custom_field_values',
                          'custom_fields',
                          'tracker_ids',
                          'issue_custom_field_ids',
                          'dept_code'

        end

      end
    end


  end
end



