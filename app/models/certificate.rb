class Certificate < ApplicationRecord

  # Relations
  belongs_to :registration, optional: true

  # Validations
  validates :digest, presence: true
  validates :initials, presence: true

  class << self

    def generate(registration)
      upb_logo = Rails.root.join("etc/cert-upb-logo.png").to_s
      ub_logo = Rails.root.join("etc/cert-ub-logo.png").to_s
      io = StringIO.new("".b)

      # Create the PDF
      HexaPDF::Composer.create(io, page_size: :A4, margin: [40, 40, 40, 60]) do |pdf|
        pdf.style(:base, font: "Helvetica", font_size: 12, line_spacing: 2)
        # pdf.document.config['debug'] = true

        pdf.image(upb_logo, width: 150, position: :float, margin: [0, 0], style: {align: :left})
        pdf.image(ub_logo, width: 130, position: :default, margin: [0, 0], style: {align: :right})

        pdf.text("Teilnahmebescheinigung", font_size: 20, align: :left, margin: [60, 0, 0, 0], font: ["Helvetica", variant: :bold])

        pdf.text(registration.full_name, font: ["Helvetica", variant: :bold], margin: [40, 0, 0, 0])
        pdf.text("hat im Rahmen der Angebote zur Informationskompetenz der Universitätsbibliothek am #{I18n.l(registration.event.date_and_time.to_date)} an der Veranstaltung", margin: [20, 0, 0, 0])
        pdf.text(registration.event.course.title, font: ["Helvetica", variant: :bold], margin: [20, 0, 0, 0])
        pdf.text("teilgenommen.", margin: [20, 0, 0, 0])

        if registration.event.certification.learning_results.present?
          pdf.text("Inhalte der Veranstaltung waren:", margin: [20, 0, 20, 0])
          pdf.box(:list, item_spacing: 10) do |list|
            registration.event.certification.learning_results.each_line do |line|
              list.text(line.strip)
            end
          end
        end

        pdf.text("Paderborn, #{I18n.l(Time.zone.now.to_date)}", margin: [40, 0, 0, 0])

        if registration.event.certification.signature.present?
          pdf.text(registration.event.certification.signature, margin: [20, 0, 0, 0])
        end

        pdf.formatted_text(
          [{
            text: "Hinweis: Die Gültigkeit der digitalen Version dieser Teilnahmebescheinigung kann unter https://schulungen.ub.uni-paderborn.de/validate überprüft werden.",
            fill_color: "gray"
          }],
          valign: :bottom,
          margin: [20, 0, 0, 0],
          align: :center,
          font_size: 8
        )
      end

      # Secure the PDF, allowing only printing
      doc = HexaPDF::Document.new(io: io)
      out_io = StringIO.new("".b)
      doc.encrypt(
        owner_password: SecureRandom.hex(10),
        permissions: HexaPDF::Encryption::StandardSecurityHandler::Permissions::PRINT
      )
      doc.write(out_io)

      # Get the PDF content
      cert = out_io.string

      # Store certificate for later verification
      registration.certificates.create!(
        digest: Digest::SHA256.hexdigest(cert),
        initials: [
          registration.first_name&.slice(0..1),
          registration.last_name&.slice(0..1)
        ].compact.join(" / ")
      )

      # Return the certificate in PDF format as a string
      cert
    end

    def filename(registration)
      [
        registration.event.date_and_time.to_date.strftime("%Y%m%d"),
        "teilnahmebescheinigung",
        registration.last_name.downcase.parameterize
      ].join("_") + ".pdf"
    end

  end

end
