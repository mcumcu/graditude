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

  # Methods defined directly in the module become instance methods
  # of the including controller
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

    @new_prawn_doc ||= PrawnRails::Document.new(page_size: "LETTER", page_layout: :landscape, margin: [ 0, 0, 0, 0 ]) do |pdf|
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
    graduate_name = params["graduate_name"]
    degree = params["degree"]
    honoree_name = params["honoree_name"]
    major = params["major"]
    nouns = params["nouns"]&.reject { |n| n.empty? } || []
    message = params["message"] || ""
    presented_on = params["presented_on"]
    signature_path = params["signature_path"]

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

    pdf.image "#{DocumentsController::IMG_DIR}/#{signature_path}", width: signature_width, at: [ (container_width / 2) - (signature_width / 2), pdf.cursor ] if signature_path

    pdf.text_box graduate_name.to_s, align: :center, size: 4.mm, width: container_width, at: [ 0, pdf.cursor - 13.mm ]

    pdf.text_box [ degree, major ].compact.join(", "), align: :center, size: 4.mm, width: container_width, at: [ 0, pdf.cursor - 19.mm ]

    # right column
    # if message.size == 2
    #   pdf.text_box message.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 10.mm ]

    #   pdf.text_box message.last, align: :center, size: 4.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 19.mm ]
    # elsif message.size == 1
    #   pdf.text_box message.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 13.mm ]
    # end

    pdf.text_box message, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 8.mm ], leading: 3.mm

    pdf
  end

  def rerender_png_path
    doc = make_document(@certificate&.data || default_params)
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
