class CreateTables < ActiveRecord::Migration[5.2]
  def change
    create_table :tables do |t|
      t.timestamps
    end
  end
end
