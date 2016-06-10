class CreateListmembers < ActiveRecord::Migration
  def change
    create_table :listmembers do |t|
      t.belongs_to :listservlist, index: true
      t.belongs_to :member, index: true
      t.timestamps null: false
    end
  end
end
