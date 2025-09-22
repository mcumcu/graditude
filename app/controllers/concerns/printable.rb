require "prawn-rails"
require "prawn/measurement_extensions"
require "pdftoimage"

module Printable
  extend ActiveSupport::Concern

  included do
    # Code within this block is executed when the concern is included
    # in a controller
    ASSET_DIR = "app/assets"
    FONT_DIR = "#{ASSET_DIR}/fonts"
    IMG_DIR = "#{ASSET_DIR}/images"
  end

  # Methods defined directly in the module become instance methods of the including controller
  def default_params
    {
      graduate_name: nil,
      degree: nil,
      major: nil,
      nouns: [],
      honoree_name: nil,
      message: nil,
      presented_on: nil,
      signature_path: nil
    }
  end

  def new_prawn_doc
    background = "#{IMG_DIR}/paper.jpg"
    document_font = "#{FONT_DIR}/OPTIEngraversOldEnglish.otf"
    banner_path = "#{IMG_DIR}/penn.svg"
    seal_path = "#{IMG_DIR}/penn_seal.png"

    page_size = "LETTER"
    page_layout = :landscape
    page_margin = [ 0, 0, 0, 0 ]

    prawn_document_params = {
      page_size: page_size,
      page_layout: page_layout,
      margin: page_margin
    }

    @new_prawn_doc ||= PrawnRails::Document.new(prawn_document_params) do |pdf|
      pdf.font(document_font)

      pdf.float do
        pdf.image background, width: pdf.margin_box.width, height: pdf.margin_box.height, position: :center
      end

      pdf.move_down(25.mm)

      pdf.float do
        pdf.svg File.read(banner_path), width: 220.mm, position: :center
      end

      pdf.move_down(20.mm)

      pdf.image seal_path, width: 40.mm, position: :center

      pdf.move_down(10.mm)

      pdf.text "This certifies that", align: :center, size: 5.mm

      pdf.move_down(10.mm)
    end
  end

  def make_document(params = {})
    graduate_name = params["graduate_name"] || " "
    degree = params["degree"]
    honoree_name = params["honoree_name"] || " "
    major = params["major"]
    nouns = params["nouns"]&.reject { |n| n.empty? } || []
    message = params["message"] || ""
    presented_on = params["presented_on"]
    # signature_font = "#{FONT_DIR}/MySoul-Regular.ttf"
    signature_font = "#{FONT_DIR}/HomemadeApple-Regular.ttf"

    pdf = new_prawn_doc

    pdf.text graduate_name.to_s, align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text [
      "has successfully completed the requirements for",
      degree || "their degree",
      nouns.any? ? "with the #{nouns.join(' and ')} of" : nil
    ].compact.join(" "), align: :center, size: 5.mm

    pdf.move_down(10.mm)

    pdf.text honoree_name.to_s, align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text "Presented #{presented_on}", align: :center, size: 5.mm

    pdf.move_down(14.mm)

    # left column
    container_width = message.size == 0 ? width : half_width

    # pdf.image "#{DocumentsController::IMG_DIR}/#{signature_path}", width: signature_width, at: [ (container_width / 2) - (signature_width / 2), pdf.cursor ] if signature_path

    pdf.font(signature_font) do
      pdf.text_box graduate_name.to_s, align: :center, size: 6.mm, width: container_width, at: [ 0, pdf.cursor - 1.5.mm ]
    end

    pdf.text_box [ degree, major ].compact.join(", "), align: :center, size: 3.5.mm, width: container_width, at: [ 0, pdf.cursor - 12.mm ]

    # right column
    # if message.size == 2
    #   pdf.text_box message.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 10.mm ]

    #   pdf.text_box message.last, align: :center, size: 3.5.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 19.mm ]
    # elsif message.size == 1
    #   pdf.text_box message.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 13.mm ]
    # end

    pdf.text_box message, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, at: [ (half_width) + 10.mm, pdf.cursor - 10.5.mm ]

    pdf
  end

  def new_westtown_doc
    # background = "#{IMG_DIR}/westtown_paper.png"
    document_font = "#{FONT_DIR}/Jost-VariableFont_wght.ttf"
    banner_path = "#{IMG_DIR}/westtown.svg"
    seal_path = "#{IMG_DIR}/westtown_seal.svg"

    page_size = [ 175.mm, 227.mm ]
    page_layout = :landscape
    page_margin = [ 0, 0, 0, 0 ]

    prawn_document_params = {
      page_size: page_size,
      page_layout: page_layout,
      margin: page_margin
    }

    @new_prawn_doc ||= PrawnRails::Document.new(prawn_document_params) do |pdf|
      pdf.font(document_font)

      pdf.float do
        pdf.bounding_box([ 5.mm, pdf.margin_box.height - 5.mm ], width: pdf.margin_box.width - 10.mm, height: pdf.margin_box.height - 10.mm) do
          pdf.transparent(0.5.pt) { pdf.stroke_bounds }
        end

        pdf.bounding_box([ 6.mm, pdf.margin_box.height - 6.mm ], width: pdf.margin_box.width - 12.mm, height: pdf.margin_box.height - 12.mm) do
          pdf.transparent(1.pt) { pdf.stroke_bounds }
        end
      end

      pdf.move_down(20.mm)

      pdf.svg File.read(banner_path), width: 170.mm, position: :center

      pdf.move_down(9.mm)

      pdf.text_box "WEST CHESTER", align: :left, size: 4.5.mm, at: [ 54.mm, pdf.cursor - 9.7.mm ], kerning: true, character_spacing: 0.8

      pdf.text_box "PENNSYLVANIA", align: :left, size: 4.5.mm, at: [ 138.mm, pdf.cursor - 9.7.mm ], kerning: true, character_spacing: 0.8

      pdf.svg File.read(seal_path), width: 25.4.mm, position: :center

      pdf.move_down(6.mm)

      pdf.text "This is to certify that", align: :center, size: 3.5.mm

      pdf.move_down(2.mm)
    end
  end

  def make_westtown_document(params = {})
    graduate_name = params["graduate_name"] || " "
    # degree = params["degree"]
    honoree_name = params["honoree_name"] || " "
    # major = params["major"]
    nouns = params["nouns"]&.reject { |n| n.empty? } || []
    message = params["message"] || ""
    presented_on = params["presented_on"]
    name_font = "#{FONT_DIR}/Literata-SemiBold.ttf"
    # signature_font = "#{FONT_DIR}/MySoul-Regular.ttf"
    signature_font = "#{FONT_DIR}/HomemadeApple-Regular.ttf"

    pdf = new_westtown_doc

    pdf.font(name_font) do
      pdf.text graduate_name.to_s, align: :center, size: 9.mm
    end

    pdf.move_down(3.mm)

    pdf.text "has successfully completed the requirements for graduation", align: :center, size: 3.5.mm
    # pdf.text "and in recognition thereof is awarded this diploma", align: :center, size: 3.5.mm
    pdf.text nouns.any? ? "and hereby recognizes the #{nouns.join(' and ').downcase} of" : nil, align: :center, size: 3.5.mm

    pdf.move_down(3.mm)

    pdf.font(name_font) do
      pdf.text honoree_name.to_s, align: :center, size: 9.mm
    end

    pdf.move_down(3.mm)

    pdf.text "on this #{presented_on.split(' ').slice(0...-1).join(' ')}, #{presented_on.split(' ').last.to_i.humanize}.", align: :center, size: 3.5.mm

    pdf.move_down(3.mm)

    # left column
    container_width = message.size == 0 ? width : half_width

    pdf.font(signature_font) do
      pdf.text_box graduate_name.to_s, align: :center, size: 4.mm, width: container_width, at: [ 0, pdf.cursor - 8.mm ]
    end

    pdf.text_box "Westtown School, #{presented_on.split(' ').last}", align: :center, size: 3.5.mm, width: container_width, at: [ 0, pdf.cursor - 14.mm ]

    pdf.text_box message, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, at: [ (half_width) + 10.mm, pdf.cursor - 5.mm ]

    pdf
  end

  def rerender_png_path
    doc = make_westtown_document(@certificate&.data || default_params)
    doc.render_file(temp_pdf_path(@certificate&.id || "_blank"))

    page = PDFToImage.open(temp_pdf_path(@certificate&.id || "_blank")).first

    if page
      page.resize("1024").save(temp_png_path(@certificate&.id || "_blank"))
    end

    temp_png_path(@certificate&.id || "_blank")
  end

  def temp_pdf_dir
    @temp_pdf_path ||= Rails.root.join("tmp", "preview", "pdf")
  end

  def temp_png_dir
    @temp_png_path ||= Rails.root.join("tmp", "preview", "png")
  end

  def temp_pdf_path(filename)
    @temp_pdf_path ||= Rails.root.join(temp_pdf_dir, "#{filename}.pdf")
  end

  def temp_png_path(filename)
    @temp_png_path ||= Rails.root.join(temp_png_dir, "#{filename}.png")
  end

  def width
    @width ||= @new_prawn_doc.bounds.width
  end

  def half_width
    @half_width ||= width / 2
  end

  def margin_horizontal
    30.mm
  end

  def signature_width
    70.mm
  end

  # Methods here become class methods of the including controller
  module ClassMethods
  end
end
