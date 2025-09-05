prawn_document(page_layout: :landscape, margin: [ 0, 0, 0, 0 ]) do |pdf|
  # document variables
  half_width = pdf.bounds.width / 2
  margin_horizontal = 40.mm
  signature_width = 70.mm
  background = "#{DocumentsController::IMG_DIR}/paper.jpg"

  # institution variables
  document_font = "#{DocumentsController::FONT_DIR}/OPTIEngraversOldEnglish.otf"
  banner_path = "#{DocumentsController::IMG_DIR}/penn.svg"
  seal_path = "#{DocumentsController::IMG_DIR}/penn_seal.png"

  # instance (user) variables
  graduate_name = "Meili Blaine Elizabeth Unger"
  honoree_name = "Michael Christopher Unger"
  degree = "Bachelor of Science"
  major = "Organic Chemistry"
  nouns = [
    "mentorship",
    "support"
  ]
  lines = [
    "Gratias tibi ago pro amore et auxilio tuo",
    "Thank you for your love and support"
  ]
  presented_on = "May 2026"
  signature_path = "givers_signature.png"

  pdf.float do
    pdf.image background, width: pdf.margin_box.width, height: pdf.margin_box.height, position: :center
  end

  pdf.move_down(20.mm)

  pdf.float do
    pdf.svg File.read(banner_path), width: 220.mm, position: :center
  end

  pdf.move_down(20.mm)

  pdf.image seal_path, width: 40.mm, position: :center

  pdf.move_down(10.mm)

  pdf.font(document_font) do
    pdf.text "This certifies that", align: :center, size: 5.mm

    pdf.move_down(10.mm)

    pdf.text graduate_name, align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text "has successfully completed the requirements for #{degree} with the #{nouns.join(' and ')} of", align: :center, size: 5.mm

    pdf.move_down(10.mm)

    pdf.text honoree_name, align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text "Presented #{presented_on}", align: :center, size: 5.mm

    pdf.move_down(14.mm)

    # left column
    pdf.image "#{DocumentsController::IMG_DIR}/#{signature_path}", width: signature_width, at: [ (half_width / 2) - (signature_width / 2), pdf.cursor ]

    pdf.text_box graduate_name, align: :center, size: 4.mm, width: half_width, at: [ 0, pdf.cursor - 13.mm ]

    pdf.text_box [ degree, major ].join(", "), align: :center, size: 4.mm, width: half_width, at: [ 0, pdf.cursor - 19.mm ]

    # right column
    if lines.size == 2
      pdf.text_box lines.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 10.mm ]

      pdf.text_box lines.last, align: :center, size: 4.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 19.mm ]
    elsif lines.size == 1
      pdf.text_box lines.first, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, height: 30.mm, at: [ (half_width) + 10.mm, pdf.cursor - 13.mm ]
    end
  end
end
