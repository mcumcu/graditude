class CertificatesController < ApplicationController
  include Printable

  rescue_from ActionController::ParameterMissing, with: :missing_certificate_params

  before_action :set_certificate, only: %i[ show edit update destroy preview ]
  before_action :options_for_nouns, only: %i[ index edit new create show ]

  # GET /certificates or /certificates.json
  def index
    @certificates = Certificate.where(user: Current.user)
  end

  # GET /certificates/1 or /certificates/1.json
  def show
  end

  # GET /certificates/new
  def new
    existing_certificate = Certificate.where(
      user: Current.user
    ).last

    attrs = existing_certificate ? existing_certificate.data.except("honoree_name") : {}

    @certificate = Certificate.new(attrs)
  end

  # GET /certificates/1/edit
  def edit
  end

  # POST /certificates or /certificates.json
  def create
    @certificate = Certificate.new(certificate_params.merge(user: Current.user))

    respond_to do |format|
      if @certificate.save
        format.html { redirect_to @certificate, notice: "Certificate for #{@certificate.honoree_name} was created" }
        format.json { render :show, status: :created, location: @certificate }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @certificate.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /certificates/1 or /certificates/1.json
  def update
    respond_to do |format|
      if @certificate.update(certificate_params)
        format.html do
          if @certificate.saved_changes?
            redirect_to certificate_path(@certificate), notice: "Certificate for #{@certificate.honoree_name} was updated"
          else
            redirect_to certificate_path(@certificate)
          end
        end
        format.json { render :show, status: :ok, location: @certificate }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @certificate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /certificates/1 or /certificates/1.json
  def destroy
    @certificate.destroy!

    respond_to do |format|
      format.html { redirect_to certificates_path, alert: "Certificate for #{@certificate.honoree_name} was deleted", status: :see_other }
      format.json { head :no_content }
    end
  end

  def preview
    respond_to do |format|
      format.pdf
      format.png
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_certificate
      @certificate = Certificate.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def certificate_params
      params.require(:certificate).permit(
        :graduate_name,
        :degree,
        :major,
        :honoree_name,
        :presented_on,
        :signature_path,
        :message,
        :template,
        nouns: []
      )
    end

    def missing_certificate_params
      head :bad_request
    end

    def options_for_nouns
      @options_for_nouns ||= %w[Love Support Guidance Mentorship Patience]
    end
end
