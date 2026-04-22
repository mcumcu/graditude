class DocumentsController < ApplicationController
  include GraditudeFactory::Concerns::Printable

  def index
    @params = default_certificate_params

    respond_to do |format|
      format.html
      format.pdf
      format.png
    end
  end
end
