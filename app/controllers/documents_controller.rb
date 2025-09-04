require "prawn/measurement_extensions"

class DocumentsController < ApplicationController
  ASSET_DIR = "app/assets"
  FONT_DIR = "#{ASSET_DIR}/fonts"
  IMG_DIR = "#{ASSET_DIR}/images"

  def index
    respond_to do |format|
      format.html
      format.pdf
    end
  end
end
