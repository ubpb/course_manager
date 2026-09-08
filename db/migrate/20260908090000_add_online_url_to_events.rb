class AddOnlineUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :online_url, :string
  end
end
