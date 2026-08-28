class RemoveArchivedFromTitle < ActiveRecord::Migration[8.1]

  def change
    Offer.find_each do |offer|
      offer.update_attribute!(:title, offer.title.gsub(/\A\[ARCHIVIERT\] /, ""))
    end
  end

end
