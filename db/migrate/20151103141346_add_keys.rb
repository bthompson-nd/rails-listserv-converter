class AddKeys < ActiveRecord::Migration
  def change
    add_foreign_key "listmembers", "listservlists", name: "listmembers_listservlist_id_fk"
    add_foreign_key "listmembers", "members", name: "listmembers_member_id_fk"
  end
end
