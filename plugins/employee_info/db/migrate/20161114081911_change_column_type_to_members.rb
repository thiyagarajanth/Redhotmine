class ChangeColumnTypeToMembers < ActiveRecord::Migration
  def change
    change_column :members, :billable, :string
    change_column :member_histories, :billable, :string
  end
end
