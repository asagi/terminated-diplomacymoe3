class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.string :token

      t.timestamps
    end
    add_index :users, :name, unique: true
    add_index :users, :email, unique: true
    add_index :users, :token, unique: true
  end
end
