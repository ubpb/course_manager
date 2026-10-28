require "test_helper"

# Anyone can upload a certificate PDF to find out whether we issued it: the
# checksum of the file has to match one we stored when generating it.
module Frontend
  class CertChecksTest < ActionDispatch::IntegrationTest

    include MailerRecords

    def upload(content)
      file = Tempfile.new(["teilnahmebescheinigung", ".pdf"])
      file.binmode
      file.write(content)
      file.rewind
      post frontend_cert_checks_path, params: {cert_check: {file: Rack::Test::UploadedFile.new(file.path)}}
    ensure
      file.close!
    end

    test "the check starts with the upload form" do
      get frontend_cert_checks_path

      assert_redirected_to new_frontend_cert_check_path
      follow_redirect!

      assert_select "form[action=?] input[type=file]", frontend_cert_checks_path
    end

    test "an upload leads to the result for its checksum" do
      upload("%PDF-1.7 Bescheinigung")

      assert_redirected_to frontend_cert_check_path(id: Digest::SHA256.hexdigest("%PDF-1.7 Bescheinigung"))
    end

    test "a certificate we issued is valid" do
      @offer = create_offer
      @event = create_event
      registration = create_registration
      registration.certificates.create!(digest: "abc123", initials: "Ma / Mu")

      get frontend_cert_check_path(id: "abc123")

      assert_response :success
      assert_includes response.body, "Prüfsumme: abc123"
      assert_includes response.body, "Die Teilnahmebescheinigung ist gültig."
    end

    test "an unknown checksum is invalid" do
      get frontend_cert_check_path(id: "unbekannt")

      assert_response :success
      assert_includes response.body, "Die Teilnahmebescheinigung ist ungültig."
    end

    # A browser leaves an empty file field out of the request altogether.
    test "without a file there is nothing to check" do
      post frontend_cert_checks_path, params: {commit: "Bescheinigung jetzt prüfen"}

      assert_redirected_to new_frontend_cert_check_path
      assert_equal "Bitte wählen Sie eine Datei aus", flash[:error]
    end

    test "a file over 1 MB is turned away" do
      upload("x" * (1.megabyte + 1))

      assert_redirected_to new_frontend_cert_check_path
      assert_equal "Die Datei darf maximal 1 MB groß sein", flash[:error]
    end

  end
end
