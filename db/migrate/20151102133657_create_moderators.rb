class CreateModerators < ActiveRecord::Migration
  def change
    create_table :moderators do |t|
      t.timestamps null: false
      t.belongs_to :listservlist, index:true
      t.string :address
    end
  end
end
