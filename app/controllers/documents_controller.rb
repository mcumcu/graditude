class DocumentsController < ApplicationController
  include Printable

  def index
    respond_to do |format|
      format.png do
        data_url = rerender_png_data_url

        if data_url.nil?
          head :not_found
        else
          render plain: data_url
        end
      end
    end
  end
end
