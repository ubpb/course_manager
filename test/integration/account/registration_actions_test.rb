require "test_helper"

# From the detail page participants cancel an upcoming registration and
# download the certificate of an event they attended.
module Account
  class RegistrationActionsTest < ActionDispatch::IntegrationTest

    include ActionMailer::TestHelper
    include MailerRecords

    setup do
      @offer = create_offer
      @event = create_event(date_and_time: 1.week.from_now)
      @registration = create_registration(ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID)
      post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                          password: AlmaAuthenticationStub::VALID_PASSWORD}}
    end

    def attend
      @event.update!(date_and_time: 2.days.ago)
      Certification.create!(event: @event, learning_results: "Katalogrecherche")
    end

    test "cancelling an upcoming registration removes it and tells participant and team" do
      assert_enqueued_emails 2 do
        delete account_registration_path(@registration)
      end

      assert_redirected_to account_root_path
      assert_response :see_other
      assert_equal I18n.t("account.registrations.destroy.success"), flash[:notice]
      assert_not Registration.exists?(@registration.id)
    end

    test "a past registration cannot be cancelled" do
      @event.update!(date_and_time: 2.days.ago)

      assert_no_enqueued_emails do
        delete account_registration_path(@registration)
      end

      assert_redirected_to account_root_path
      assert_equal I18n.t("account.registrations.destroy.not_allowed"), flash[:alert]
      assert Registration.exists?(@registration.id)
    end

    test "the certificate of an attended event downloads as a PDF" do
      attend

      get certificate_account_registration_path(@registration)

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers["Content-Disposition"], Certificate.filename(@registration)
    end

    test "there is no certificate before the event" do
      Certification.create!(event: @event, learning_results: "Katalogrecherche")

      get certificate_account_registration_path(@registration)

      assert_redirected_to account_root_path
      assert_response :see_other
      assert_equal I18n.t("account.registrations.certificate.not_available"), flash[:alert]
      assert_equal 0, Certificate.count
    end

    test "there is no certificate without a certification" do
      @event.update!(date_and_time: 2.days.ago)

      get certificate_account_registration_path(@registration)

      assert_redirected_to account_root_path
      assert_equal 0, Certificate.count
    end

    test "someone else's registration has no certificate and cannot be cancelled" do
      attend
      other = create_registration(email: "other@example.com", ils_primary_id: "99999")

      get certificate_account_registration_path(other)

      assert_response :not_found

      delete account_registration_path(other)

      assert_response :not_found
      assert Registration.exists?(other.id)
    end

  end
end
