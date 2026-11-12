require "test_helper"
require Rails.root.join("db/migrate/20261112120000_add_origin_to_registrations.rb")

# The migration that introduced the origin of a registration sorted the
# registrations made until then: a login left the ILS id behind, everything
# else was entered in the admin. Anonymizing had dropped the ILS id, so for an
# anonymized registration the origin could no longer be told.
class AddOriginToRegistrationsTest < ActiveSupport::TestCase

  include MailerRecords

  setup do
    @offer = create_offer
    @event = create_event
  end

  def backfill
    ActiveRecord::Migration.suppress_messages { AddOriginToRegistrations.new.backfill_origin }
  end

  test "the backfill tells account and admin registrations apart and leaves anonymized ones unknown" do
    account = create_registration(ils_primary_id: "12345")
    admin = create_registration(email: "erika@example.com")
    blank_id = create_registration(email: "otto@example.com", ils_primary_id: "")
    anonymized = create_registration(email: "hans@example.com")
    anonymized.update_columns(Registration::ANONYMIZED_ATTRIBUTES)

    backfill

    assert_equal(["account", "admin", "admin", nil], [account, admin, blank_id, anonymized].map { it.reload.origin })
  end

  test "the backfill keeps an origin already set" do
    guest = create_registration(origin: "guest")

    backfill

    assert_predicate guest.reload, :origin_guest?
  end

end
