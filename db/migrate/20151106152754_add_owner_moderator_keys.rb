class AddOwnerModeratorKeys < ActiveRecord::Migration
  def change
    add_foreign_key "moderators", "listservlists", name: "moderators_listservlist_id_fk"
    add_foreign_key "owners", "listservlists", name: "owners_listservlist_id_fk"
  end
end
