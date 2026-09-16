require "test_helper"

# Staff addresses are the only ones allowed in the sender and contact fields, so
# UPB_EMAIL_REGEXP has to accept every shape the university hands out
# (uni-paderborn.de as well as a subdomain like ub.) and nothing else. The
# regexp is asserted through both models that use it, because a validation that
# lets a foreign address through would send mail from an address the university
# mail server refuses.
class UpbEmailRegexpTest < ActiveSupport::TestCase

  include MailerRecords

  VALID = [
    "a.b@uni-paderborn.de",
    "musterfrau@uni-paderborn.de",
    "a_b@uni-paderborn.de",
    "a-b@uni-paderborn.de",
    "a+tag@uni-paderborn.de",
    "x@ub.uni-paderborn.de",
    "info@mail.ub.uni-paderborn.de",
    "A.B@UB.Uni-Paderborn.DE"
  ].freeze

  INVALID = [
    "a@evil.de",
    "a@uni-paderborn.dex",
    "a@uni-paderborn.de.evil.com",
    "x@ubxuni-paderborn.de",      # the dots are separators, not any character
    "a b@uni-paderborn.de",
    "hack\na@uni-paderborn.de",   # a second line must not slip past the anchors
    "a@uni-paderborn.de\nhack",
    # A From header addresses by comma and angle bracket, so neither belongs in
    # a local part.
    "a,b@uni-paderborn.de",
    "<a>@uni-paderborn.de",
    "a\"b@uni-paderborn.de"
  ].freeze

  setup do
    @offer = create_offer
  end

  test "the regexp accepts university addresses" do
    VALID.each do |email|
      assert_match ApplicationRecord::UPB_EMAIL_REGEXP, email, "expected #{email.inspect} to be accepted"
    end
  end

  test "the regexp rejects everything else" do
    INVALID.each do |email|
      assert_no_match ApplicationRecord::UPB_EMAIL_REGEXP, email, "expected #{email.inspect} to be rejected"
    end
  end

  test "the regexp accepts a blank address" do
    ["", nil.to_s].each { |email| assert_match ApplicationRecord::UPB_EMAIL_REGEXP, email }
  end

  test "an offer accepts a university contact address" do
    VALID.each do |email|
      offer = Offer.new(title: "Literaturrecherche", type: "course", contact_email: email)

      assert_predicate offer, :valid?, "expected #{email.inspect} to be accepted"
    end
  end

  test "an offer rejects a foreign contact address" do
    INVALID.each do |email|
      offer = Offer.new(title: "Literaturrecherche", type: "course", contact_email: email)

      assert_predicate offer, :invalid?, "expected #{email.inspect} to be rejected"
      assert_includes offer.errors.attribute_names, :contact_email
    end
  end

  test "an offer accepts a blank contact address" do
    [nil, ""].each do |email|
      offer = Offer.new(title: "Literaturrecherche", type: "course", contact_email: email)

      assert_predicate offer, :valid?, "expected #{email.inspect} to be accepted"
    end
  end

  test "an event accepts a university sender address" do
    VALID.each do |email|
      event = build_event(email_from: email)

      assert_predicate event, :valid?, "expected #{email.inspect} to be accepted"
    end
  end

  test "an event rejects a foreign sender address" do
    INVALID.each do |email|
      event = build_event(email_from: email)

      assert_predicate event, :invalid?, "expected #{email.inspect} to be rejected"
      assert_includes event.errors.attribute_names, :email_from
    end
  end

  test "an event accepts a blank sender address" do
    [nil, ""].each do |email|
      event = build_event(email_from: email)

      assert_predicate event, :valid?, "expected #{email.inspect} to be accepted"
    end
  end

  private

  def build_event(**attributes)
    @offer.events.build({date_and_time: Time.zone.parse(EVENT_TIME),
                         max_no_of_participants: 10}.merge(attributes))
  end

end
