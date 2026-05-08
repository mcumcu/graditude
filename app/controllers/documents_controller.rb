class DocumentsController < ApplicationController
  include Printable

  def index
    respond_to do |format|
      format.png { render plain: rerender_png_data_url }
    end
  end
end
