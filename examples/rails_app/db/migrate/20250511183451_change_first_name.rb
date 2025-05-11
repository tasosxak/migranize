# Migration generated at 2025-05-11 18:34:51 +0300
class ChangeFirstName < ActiveRecord::Migration[7.0]
  def change
	change_column :users, :first_name, :text

  end
end
