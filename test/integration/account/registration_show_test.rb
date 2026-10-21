require "test_helper"

# The detail page in the account gathers everything about one registration --
# the date, the custom text of the confirmation, what the offer is about -- so
# participants find it again long after the confirmation mail is gone.
class Account::RegistrationShowTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Literaturrecherche",
                           type: "course",
                           published: true,
                           description: "Wir **suchen** Literatur.",
                           learning_targets: "- Kataloge nutzen")
    @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                   duration: 90,
                                   online: true,
                                   online_url: "https://meet.example.com/abc",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true,
                                   confirmation_message: "###ANREDE###, bitte Zotero installieren.")
    @registration = create_registration(@event, ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID,
                                                user_notes: "Komme etwas später",
                                                internal_notes: "Intern: VIP")
  end

  def create_registration(event, **attributes)
    event.registrations.create!({first_name: "Max", last_name: "Mustermann", email: "max@example.com"}.merge(attributes))
  end

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  def cancel_form_selector
    "form[action='#{account_registration_path(@registration)}']"
  end

  test "the participant sees everything about the registration" do
    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_includes response.body, "Literaturrecherche"
    assert_includes response.body, "Hallo Max Mustermann, bitte Zotero installieren."
    assert_includes response.body, "<strong>suchen</strong>"
    assert_includes response.body, "Kataloge nutzen"
    assert_includes response.body, "90 Minuten"
    assert_includes response.body, "href=\"https://meet.example.com/abc\""
    assert_includes response.body, "Komme etwas später"
    assert_not_includes response.body, "Intern: VIP"
    assert_not_includes response.body, "translation missing"
    assert_select cancel_form_selector
  end

  # The offer page no longer shows the access link, so the detail page has to
  # make it easy to find -- and to copy, for those who join from another device.
  test "the access link stands out as a button with the address to copy" do
    log_in
    get account_registration_path(@registration)

    assert_select "a.btn[href=?][target=_blank]", "https://meet.example.com/abc", text: /Online-Termin beitreten/
    assert_select ".text-break", text: "https://meet.example.com/abc"
  end

  test "an online event without access link says how it will come" do
    @event.update!(online_url: nil)

    log_in
    get account_registration_path(@registration)

    assert_includes response.body, "Die Zugangsdaten erhalten Sie vor der Veranstaltung in einer separaten E-Mail."
    assert_select "a", text: /Online-Termin beitreten/, count: 0
  end

  test "an event on site has no access section" do
    @event.update!(online: false, location: "Raum 1.2")

    log_in
    get account_registration_path(@registration)

    assert_includes response.body, "Raum 1.2"
    assert_not_includes response.body, "meet.example.com"
    assert_not_includes response.body, "Zugangsdaten"
  end

  test "an unpublished and archived offer is still shown" do
    @offer.update!(published: false, archived: true)
    @event.update!(published: false)

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select "a[href=?]", frontend_offer_path(@offer), count: 0
  end

  test "a published offer links to its public page" do
    log_in
    get account_registration_path(@registration)

    assert_select "a[href=?]", frontend_offer_path(@offer)
  end

  # Mails link here, but a registration may be gone by the time the link is
  # clicked: cancelled, deleted by staff, or anonymized 10 days after the event.
  # Someone else's registration gets the very same answer, so the response
  # gives nothing away about which ids exist.
  def assert_led_back_to_the_overview
    assert_redirected_to account_root_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Diese Anmeldung ist nicht (mehr) vorhanden."
  end

  test "someone else's registration leads back to the overview" do
    other = create_registration(@event, ils_primary_id: "99999", first_name: "Fremd")

    log_in
    get account_registration_path(other)

    assert_led_back_to_the_overview
    assert_not_includes response.body, "Fremd"
  end

  test "a registration without an account leads back to the overview" do
    manual = create_registration(@event, ils_primary_id: nil)

    log_in
    get account_registration_path(manual)

    assert_led_back_to_the_overview
  end

  test "a cancelled registration leads back to the overview" do
    id = @registration.id
    @registration.destroy!

    log_in
    get account_registration_path(id)

    assert_led_back_to_the_overview
  end

  test "a logged out visitor is sent to the login and back" do
    get account_registration_path(@registration)

    assert_redirected_to new_session_path
    assert_equal account_registration_path(@registration), session[:return_to]

    log_in

    assert_redirected_to account_registration_path(@registration)
  end

  test "a past event offers the certificate instead of cancelling" do
    @event.update!(date_and_time: 3.days.ago)
    Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select cancel_form_selector, count: 0
    assert_not_includes response.body, "meet.example.com"
    assert_select "a[href=?]", certificate_account_registration_path(@registration)
    assert_not_includes response.body, "translation missing"
  end

  test "a past event announces when the registration is deleted" do
    @event.update!(date_and_time: Time.zone.parse("2026-10-15 18:00"))
    travel_to Time.zone.parse("2026-10-21 10:00")

    log_in
    get account_registration_path(@registration)

    assert_includes response.body, "Aus Datenschutzgründen wird Ihre Anmeldung 10 Tage nach dem Termin gelöscht, also ab dem 25.10.2026."
    assert_not_includes response.body, "Teilnahmebescheinigung bis dahin"
  end

  test "with a certificate the deletion notice asks to download it in time" do
    @event.update!(date_and_time: 3.days.ago)
    Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")

    log_in
    get account_registration_path(@registration)

    assert_includes response.body, "Bitte laden Sie Ihre Teilnahmebescheinigung bis dahin herunter."
  end

  test "an upcoming event has no deletion notice" do
    log_in
    get account_registration_path(@registration)

    assert_not_includes response.body, "Aus Datenschutzgründen"
  end

  # date_in_words only knows the future ("in 5 Tagen"), so a past date must not
  # get it at all.
  test "a past event does not claim to lie ahead" do
    @event.update!(date_and_time: 5.days.ago)

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_no_match(/\(in \d+ Tagen\)/, response.body)
  end

  # Event#upcoming? counts the whole day, and so does the cancellation itself.
  test "an event earlier today can still be cancelled" do
    @event.update!(date_and_time: Time.zone.now.beginning_of_day + 1.minute)

    log_in
    get account_registration_path(@registration)

    assert_select cancel_form_selector
  end

  test "without a custom text there is no notes box" do
    @event.update!(confirmation_message: nil, location: nil, duration: nil)

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select ".callout-warning", count: 0
  end

  # The text is kept for plain text mails, so the page must not render more of
  # it than the mail would.
  test "the custom text is escaped" do
    @event.update!(confirmation_message: "<script>alert(1)</script>")

    log_in
    get account_registration_path(@registration)

    assert_not_includes response.body, "<script>alert(1)"
    assert_includes response.body, "&lt;script&gt;alert(1)"
  end

  TURBO_STREAM_HEADERS = {
    "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  }.freeze

  test "the overview gets the detail page as a modal" do
    log_in
    get account_registration_path(@registration, modal: 1), headers: TURBO_STREAM_HEADERS

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, '<turbo-stream action="replace" target="registration-modal">'
    assert_includes response.body, "Hallo Max Mustermann, bitte Zotero installieren."
    assert_includes response.body, "Online-Termin beitreten"
    assert_not_includes response.body, "translation missing"
    assert_select_in_stream cancel_form_selector
  end

  # Without Turbo -- or with ?modal=1 left in a bookmarked URL -- the very same
  # request has to work as a page of its own.
  test "a modal link without Turbo renders the full page" do
    log_in
    get account_registration_path(@registration, modal: 1)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "h3", text: /Literaturrecherche/
  end

  # After the login the overview -- and with it the #registration-modal
  # placeholder -- is gone, so come back as a full page by dropping ?modal.
  test "a modal request while logged out comes back as a full page" do
    get account_registration_path(@registration, modal: 1), headers: TURBO_STREAM_HEADERS

    assert_redirected_to new_session_path
    assert_equal account_registration_path(@registration), session[:return_to]
  end

  def assert_select_in_stream(selector)
    template = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream template")
    assert template, "no turbo stream template in the response"
    assert Nokogiri::HTML5.fragment(template.inner_html).at_css(selector), "#{selector} not in the modal"
  end

end
