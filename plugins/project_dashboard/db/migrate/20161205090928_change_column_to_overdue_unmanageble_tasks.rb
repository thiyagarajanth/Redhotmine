class ChangeColumnToOverdueUnmanagebleTasks < ActiveRecord::Migration
  def change
    change_column :overdue_unmanage_tasks_settings, :allocation_type, :string, :limit => 455
  end

end
