class CreateConversions < ActiveRecord::Migration
  def change
    create_table :conversions do |t|
      t.string :title
      t.string :address
      t.string :contact_owners
      t.string :contact_members
      t.string :view_member_addresses
      t.string :view_topics
      t.string :status
      t.string :message
      t.string :owner
      t.belongs_to :listservlist, index:true

      t.timestamps null: false
    end
  end
end
