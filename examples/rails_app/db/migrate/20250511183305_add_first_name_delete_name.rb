# Migration generated at 2025-05-11 18:33:05 +0300
class AddFirstNameDeleteName < ActiveRecord::Migration[7.0]
  def change
	add_column :users, :first_name, :string
	remove_column :users, :name

  end
end
