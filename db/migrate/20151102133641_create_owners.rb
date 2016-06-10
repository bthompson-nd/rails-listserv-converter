class CreateOwners < ActiveRecord::Migration
  def change
    create_table :owners do |t|
      t.timestamps null: false
      t.belongs_to :listservlist, index:true
      t.string :address
    end
  end
end
