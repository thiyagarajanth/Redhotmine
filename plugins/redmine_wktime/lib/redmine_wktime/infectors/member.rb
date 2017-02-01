module RedmineWktime
	module Infectors
		module Member
			module ClassMethods; end

			module InstanceMethods; end

			def self.included(receiver)
				receiver.extend(ClassMethods)
				receiver.send(:include, InstanceMethods)
				receiver.class_eval do 
					unloadable

					belongs_to :billable_type

				end
			end
		end
	end
end
