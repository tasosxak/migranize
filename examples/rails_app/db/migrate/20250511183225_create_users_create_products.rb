# Migration generated at 2025-05-11 18:32:25 +0300
class CreateUsersCreateProducts < ActiveRecord::Migration[7.0]
  def change
	create_table :users do |t|
		t.string :name
		t.timestamps
	end


	create_table :products do |t|
		t.string :name
		t.integer :user_id, index: true, null: true
		t.timestamps
	end

	add_foreign_key :products, :users, column: :user_id

  end
end
