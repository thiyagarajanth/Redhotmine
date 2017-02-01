module EKanban
  module Patches
    module ProjectsControllerPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          def kanbans
            #@kanbans = Kanban.where("project_id=? and is_valid = ?",@project.id, true)
            @kanbans = Kanban.where("project_id=? ",@project.id)
          end
          #user to extend.
          #alias_method_chain :show, :plugin
        end
      end

      module ClassMethods
      end

      module InstanceMethods
      end
    end


    module ProjectsHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
            unloadable
            alias_method_chain :project_settings_tabs, :ekanban
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def project_settings_tabs_with_ekanban
            tabs = project_settings_tabs_without_ekanban
            call_hook(:helper_projects_settings_tabs, { :tabs => tabs })
            return tabs
        end
      end
    end
  end
end
