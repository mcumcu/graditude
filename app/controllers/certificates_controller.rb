class CertificatesController < ApplicationController
  include Printable

  rescue_from ActionController::ParameterMissing, with: :missing_certificate_params

  before_action :set_certificate, only: %i[ show edit update destroy preview ]
  before_action :ensure_certificate_editable, only: %i[ edit update ]
  before_action :set_preferred_format, only: %i[ show new create edit ]
  before_action :options_for_nouns, only: %i[ index edit new create show ]

  # GET /certificates or /certificates.json
  def index
    base_scope = Certificate.where(user: Current.user).includes(:certificate_products)
    @purchasable_certificates = base_scope.purchasable.to_a
    @purchased_certificates = base_scope.purchased.to_a

    return unless @purchasable_certificates.length == 1 && @purchased_certificates.empty?

    redirect_to certificate_path(@purchasable_certificates.first)
  end

  # GET /certificates/1 or /certificates/1.json
  def show
    @products = Product.for_certificate_template(@certificate.template)
    cart_items = Current.user.open_cart&.certificate_products&.where(certificate_id: @certificate.id)
    @cart_product_ids = cart_items&.pluck(:product_id) || []
    @cart_items_by_product_id = cart_items&.pluck(:product_id, :id)&.to_h || {}
  end

  # GET /certificates/new
  def new
    existing_certificate = Certificate.where(
      user: Current.user
    ).last

    attrs = existing_certificate ? existing_certificate.data : {}

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
        format.html do
          redirect_to certificate_path(@certificate, preferred_format: @preferred_format),
                      notice: "Certificate for #{@certificate.honoree_name} was created"
        end
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
    if @certificate.destroy
      respond_to do |format|
        format.html { redirect_to certificates_path, notice: "Certificate for #{@certificate.honoree_name} was deleted", status: :see_other }
        format.json { head :no_content }
      end
    else
      message = @certificate.errors.full_messages.to_sentence.presence || "Unable to delete this certificate."
      respond_to do |format|
        format.html { redirect_to certificate_path(@certificate), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
  end

  def preview
    data_url = rerender_png_data_url

    if data_url
      render plain: data_url
    else
      head :not_found
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

    def set_preferred_format
      @preferred_format = params[:preferred_format].presence
    end

    def ensure_certificate_editable
      return unless @certificate&.purchased?

      message = "Purchased certificates cannot be edited."
      respond_to do |format|
        format.html { redirect_to certificate_path(@certificate), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end

      nil
    end
end
