class AddTrackerColumnToProjectgoal < ActiveRecord::Migration
  def change
  	add_column :project_goals, :trackers, :string, array: true, default: []
  end
end
