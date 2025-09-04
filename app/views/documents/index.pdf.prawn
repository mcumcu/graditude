prawn_document(page_layout: :landscape, margin: [ 0, 0, 0, 0 ]) do |pdf|
  pdf.float do
    pdf.image "#{DocumentsController::IMG_DIR}/paper.jpg", width: pdf.margin_box.width, height: pdf.margin_box.height, position: :center
  end

  pdf.move_down(20.mm)

  pdf.float do
    pdf.svg File.read("#{DocumentsController::IMG_DIR}/penn.svg"), width: 220.mm, position: :center
  end

  pdf.move_down(20.mm)

  pdf.image "#{DocumentsController::IMG_DIR}/penn_seal.png", width: 40.mm, position: :center

  pdf.move_down(10.mm)

  pdf.font("#{DocumentsController::FONT_DIR}/OPTIEngraversOldEnglish.otf") do
    pdf.text "This certifies that", align: :center, size: 5.mm

    pdf.move_down(10.mm)

    pdf.text "Meili Blaine Elizabeth Unger", align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text "has successfully completed the requirements for gradution with the love and support of", align: :center, size: 5.mm

    pdf.move_down(10.mm)

    pdf.text "Michael Christopher Unger", align: :center, size: 8.mm

    pdf.move_down(10.mm)

    pdf.text "Presented May 2026", align: :center, size: 5.mm

    pdf.move_down(14.mm)

    pdf.image "#{DocumentsController::IMG_DIR}/givers_signature.png", width: 60.mm, position: :center

    pdf.move_down(2.mm)

    pdf.text "Meili Blaine Elizabeth Unger", align: :center, size: 4.mm

    pdf.move_down(2.mm)

    pdf.text "Bachelor of Science, Organic Chemistry", align: :center, size: 10
  end
end
