class Frontend::CertChecksController < Frontend::ApplicationController

  def index
    redirect_to new_frontend_cert_check_path
  end

  def create
    file = params.dig(:cert_check, :file)&.tempfile

    if file.nil?
      flash[:error] = "Bitte wählen Sie eine Datei aus"
      return redirect_to new_frontend_cert_check_path
    end

    if File.size(file) > 1.megabyte
      flash[:error] = "Die Datei darf maximal 1 MB groß sein"
      return redirect_to new_frontend_cert_check_path
    end

    digest = Digest::SHA256.hexdigest(File.read(file))
    redirect_to frontend_cert_check_path(id: digest)
  end

  def show
    @digest = params[:id]
    @registration = Certificate.find_by(digest: @digest)&.registration
  end

end
