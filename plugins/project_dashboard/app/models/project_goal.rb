class ProjectGoal < ActiveRecord::Base
  unloadable
  serialize :statuses
  serialize :trackers
end
