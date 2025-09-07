class DocumentsController < ApplicationController
  include Printable

  def index
    @params = default_params

    respond_to do |format|
      format.html
      format.pdf
      format.png
    end
  end
end
