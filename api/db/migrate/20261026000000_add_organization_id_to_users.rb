# frozen_string_literal: true

# F-001 fix: give users an explicit home organization so login can derive the
# JWT `scheme` claim from the user's own tenant instead of the request header.
class AddOrganizationIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :organization_id, :bigint
  end
end
