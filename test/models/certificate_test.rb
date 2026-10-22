require "test_helper"

class CertificateTest < ActiveSupport::TestCase

  test "the filename carries the date of the event and the last name" do
    registration = Registration.new(last_name: "Müller-Lüdenscheidt",
                                    event: Event.new(date_and_time: Time.zone.parse("2026-11-05 14:00")))

    assert_equal "20261105_teilnahmebescheinigung_mueller-luedenscheidt.pdf", Certificate.filename(registration)
  end

end
