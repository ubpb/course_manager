require "test_helper"

class OfferTest < ActiveSupport::TestCase

  include ConfigOverride

  def build_offer(**attributes)
    Offer.new({title: "Literaturrecherche", type: "course"}.merge(attributes))
  end

  # The defaults come from config/application.yml and may change; an offer
  # only keeps what differs from them.
  test "contact and call to action equal to the defaults are not stored" do
    offer = build_offer(contact_name: "Schulungsteam", contact_email: "schulung@ub.uni-paderborn.de",
                        contact_phone: "05251 60-2017", call_to_action_text: "Selbstlernkurs öffnen")
    offer.save!

    assert_nil offer[:contact_name]
    assert_nil offer[:contact_email]
    assert_nil offer[:contact_phone]
    assert_nil offer[:call_to_action_text]
  end

  test "an offer without contact and call to action follows the current defaults" do
    offer = build_offer.tap(&:save!)

    with_config(default_contact: {name: "Team Recherche"}, default_call_to_action: {text: "Kurs starten"}) do
      assert_equal "Team Recherche", offer.contact_name
      assert_equal "Kurs starten", offer.call_to_action_text
    end
  end

  test "values of its own are stored and win over the defaults" do
    offer = build_offer(contact_name: "Max Muster", contact_email: "muster@ub.uni-paderborn.de",
                        contact_phone: "05251 60-1234", call_to_action_text: "Jetzt lernen")
    offer.save!

    assert_equal "Max Muster", offer.reload.contact_name
    assert_equal "muster@ub.uni-paderborn.de", offer.contact_email
    assert_equal "05251 60-1234", offer.contact_phone
    assert_equal "Jetzt lernen", offer.call_to_action_text
  end

  test "the URL carries the title as slug, or the id alone without one" do
    offer = build_offer(title: "Recherche in Datenbanken: Übung").tap(&:save!)

    assert_equal "#{offer.id}-recherche-in-datenbanken-uebung", offer.to_param

    offer.title = "!!!"

    assert_equal offer.id.to_s, offer.to_param
  end

  test "a call to action needs a web address" do
    assert_not_predicate build_offer, :call_to_action?
    assert_predicate build_offer(call_to_action_url: "https://example.com/kurs"), :call_to_action?
    assert_not build_offer(call_to_action_url: "ftp://example.com/kurs").valid?
  end

  test "the kinds of offers" do
    assert_predicate build_offer(type: "course"), :course?
    assert_predicate build_offer(type: "consulting"), :consulting?
    assert_predicate build_offer(type: "self_study_course"), :self_study_course?
    assert_not build_offer(type: "seminar").valid?
  end

  test "upcoming events come soonest first, past events latest first" do
    offer = build_offer.tap(&:save!)
    later, sooner, recent, older = [2.weeks.from_now, 1.week.from_now, 1.week.ago, 2.weeks.ago].map do |time|
      offer.events.create!(date_and_time: time, max_no_of_participants: 10)
    end

    assert_equal [sooner, later], offer.upcoming_events.to_a
    assert_equal [recent, older], offer.past_events.to_a
  end

end
