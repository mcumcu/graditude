# frozen_string_literal: true

module GraditudeFactory
  module Certificates
    class BoulderTemplate < Template
      def document_font
        asset_path(:font, "oldenglishtextmt.ttf")
      end

      def body_font
        asset_path(:font, "GoudyTextMTStdRegularHYLT2.otf")
      end

      def template_assets
        {
          header: asset_path(:image, "boulder-header.png"),
          seal: asset_path(:image, "boulder-seal.png")
        }
      end

      def render_header(pdf)
        header_path = template_assets[:header]

        pdf.move_down(10.mm)

        # "The Regents of the" - small text above header
        pdf.font(body_font) do
          pdf.text "The Regents of the", align: :center, size: 6.mm, color: "565A5C"
        end

        pdf.move_down(2.mm)

        # Render header image (same dimensions as Penn template)
        pdf.image header_path, width: 220.mm, position: :center

        pdf.move_down(8.mm)
      end

      def render_content(pdf)
        graduate_name = @params["graduate_name"] || " "
        degree = @params["degree"]
        honoree_name = @params["honoree_name"] || " "
        major = @params["major"]
        message = @params["message"] || ""
        presented_on = @params["presented_on"] || ""

        # "have conferred on"
        pdf.font(body_font) do
          pdf.text "have conferred on", align: :center, size: 6.5.mm, color: "565A5C"
        end

        pdf.move_down(2.mm)

        # Graduate name in large Old English
        pdf.font(document_font) do
          pdf.text graduate_name.to_s, align: :center, size: 15.mm, color: "000000"
        end

        pdf.move_down(2.mm)

        # "the Degree"
        pdf.font(body_font) do
          pdf.text "the Degree", align: :center, size: 6.5.mm, color: "565A5C"
        end

        pdf.move_down(2.mm)

        # Degree and major in Old English
        degree_text = [ degree, major ].compact.join(", ")
        pdf.font(document_font) do
          pdf.text degree_text, align: :center, size: 10.mm, color: "000000"
        end

        pdf.move_down(3.mm)

        # Boilerplate text - with horizontal margins
        boilerplate = "with all the rights and privileges thereunto appertaining. In witness thereof this diploma is awarded by the Regents upon the recommendation of the Faculty."
        pdf.font(body_font) do
          pdf.text_box boilerplate, align: :center, size: 5.5.mm, color: "000000", width: width - 40.mm, at: [ 20.mm, pdf.cursor ]
        end

        pdf.move_down(18.mm)

        # Date line
        if presented_on.present?
          pdf.font(body_font) do
            pdf.text "Given at Boulder on #{presented_on}, A. D.", align: :center, size: 5.mm, color: "000000"
          end
        end

        pdf.move_down(4.mm)

        # Bottom row: left column (signature) | center (seal) | right column (message)
        # All elements positioned at the same vertical level
        seal_path = template_assets[:seal]
        seal_width = 45.mm
        col_width = (width - seal_width) / 2 - 10.mm
        row_y = pdf.cursor - 20.mm

        # Left column: signature and certificate info
        pdf.font(document_font) do
          pdf.text_box graduate_name.to_s, align: :center, size: 7.mm, width: col_width, at: [ 5.mm, row_y ]
        end

        pdf.font(body_font) do
          pdf.text_box [ degree, major ].compact.join(", "), align: :center, size: 4.mm, width: col_width, at: [ 5.mm, row_y - 9.mm ]
        end

        # Center: seal horizontally centered
        seal_x = (width / 2) - (seal_width / 2)
        pdf.image seal_path, at: [ seal_x, row_y + 12.mm ], width: seal_width

        # Right column: message (if present)
        if message.present?
          right_x = width - col_width - 5.mm
          pdf.font(body_font) do
            pdf.text_box message, align: :center, size: 6.5.mm, width: col_width, at: [ right_x, row_y ]
          end
        end
      end
    end
  end
end
