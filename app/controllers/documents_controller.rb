class DocumentsController < ApplicationController
  include Printable

  def index
    @params = default_certificate_params

    respond_to do |format|
      format.png { render plain: rerender_png_data_url }
    end
  end
end
