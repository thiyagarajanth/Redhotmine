class CreateBillableTypes < ActiveRecord::Migration
  def change
    create_table :billable_types do |t|
      t.string :name
      t.boolean :is_billable, :default => false
      t.boolean :can_contributable, :default => false
      t.boolean :is_active, :default => true
      
      t.timestamps
    end
  end
end
