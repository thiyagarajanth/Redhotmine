class AddStatusColumnToProjectGoal < ActiveRecord::Migration
  def change
  	add_column :project_goals, :statuses, :string, array: true, default: []
  end
end
