class DocumentsController < ApplicationController
  include Printable

  def index
    @params = default_params.merge!(honoree_name: "foo")

    respond_to do |format|
      format.html
      format.pdf
      format.png
    end
  end
end
