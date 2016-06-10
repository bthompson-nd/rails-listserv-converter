class CreateMembers < ActiveRecord::Migration
  def change
    create_table :members do |t|
      t.timestamps null: false
      t.string :address
      t.string :netid_address
    end
  end
end
