require "test_helper"

class CertificateTest < ActiveSupport::TestCase

  include MailerRecords

  # Collects the text a PDF page shows, to read back what the certificate says.
  class TextCollector < HexaPDF::Content::Processor

    attr_reader :text

    def initialize
      super
      @text = +""
    end

    def show_text(str)
      @text << decode_text(str) << "\n"
    end
    alias show_text_with_positioning show_text

  end

  setup do
    @offer = create_offer(title: "Literaturrecherche mit Primo")
    @event = create_event(date_and_time: Time.zone.parse("2026-11-05 14:00"))
    @registration = create_registration(first_name: "Erika", last_name: "Mustermann")
  end

  def certify(**attributes)
    Certification.new({event: @event, learning_results: "Katalogrecherche\nFernleihe\n",
                       signature: "Max Muster"}.merge(attributes)).tap { |c| c.save!(validate: false) }
    @registration.reload
  end

  def text_of(pdf)
    collector = TextCollector.new
    HexaPDF::Document.new(io: StringIO.new(pdf)).pages.first.process_contents(collector)
    collector.text
  end

  test "the filename carries the date of the event and the last name" do
    registration = Registration.new(last_name: "Müller-Lüdenscheidt",
                                    event: Event.new(date_and_time: Time.zone.parse("2026-11-05 14:00")))

    assert_equal "20261105_teilnahmebescheinigung_mueller-luedenscheidt.pdf", Certificate.filename(registration)
  end

  test "the certificate names the participant, the event and what it was about" do
    certify

    text = text_of(Certificate.generate(@registration))

    assert_includes text, "Erika Mustermann"
    assert_includes text, "05.11.2026"
    assert_includes text, "Literaturrecherche mit Primo"
    assert_includes text, "Inhalte der Veranstaltung waren:"
    assert_includes text, "Katalogrecherche"
    assert_includes text, "Fernleihe"
    assert_includes text, "Max Muster"
  end

  test "without learning results and signature the certificate leaves both out" do
    certify(learning_results: "", signature: "")

    text = text_of(Certificate.generate(@registration))

    assert_includes text, "Erika Mustermann"
    assert_not_includes text, "Inhalte der Veranstaltung waren:"
    assert_not_includes text, "Max Muster"
  end

  # Extracting content for accessibility stays allowed: PDF 2.0 treats that
  # permission as always granted.
  test "the PDF allows printing but no changes and no copying" do
    certify

    document = HexaPDF::Document.new(io: StringIO.new(Certificate.generate(@registration)))
    permissions = document.security_handler.permissions

    assert_predicate document, :encrypted?
    assert_includes permissions, :print
    assert_empty permissions & [:modify_content, :copy_content, :modify_annotation, :fill_in_forms,
                                :assemble_document]
  end

  test "each certificate is kept with its digest and the initials for the check" do
    certify

    pdf = Certificate.generate(@registration)
    certificate = @registration.certificates.sole

    assert_equal Digest::SHA256.hexdigest(pdf), certificate.digest
    assert_equal "Er / Mu", certificate.initials
  end

  test "a certificate needs its digest and the initials" do
    certificate = Certificate.new

    assert_not certificate.valid?
    assert_predicate certificate.errors[:digest], :any?
    assert_predicate certificate.errors[:initials], :any?
  end

end
