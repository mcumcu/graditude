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
          pdf.text "The Regents of the", align: :center, size: 7.mm, color: "565A5C"
        end

        pdf.move_down(2.mm)

        # Render header image
        pdf.image header_path, width: 220.mm, position: :center

        # pdf.move_down(8.mm)
      end

      def render_content(pdf)
        graduate_name = @params["graduate_name"] || " "
        degree = @params["degree"]
        honoree_name = @params["honoree_name"] || " "
        major = @params["major"]
        message = @params["message"] || ""
        presented_on = @params["presented_on"] || ""
        presented_on_date = parse_presented_on(presented_on)
        nouns = @params["nouns"]&.reject { |n| n.empty? } || []

        pdf.move_up(14.mm)

        # "have conferred on"
        pdf.font(body_font) do
          pdf.text "have conferred on", align: :center, size: 7.mm, color: "565A5C"
        end

        pdf.move_down(4.mm)

        # Graduate name in large Old English
        pdf.font(document_font) do
          pdf.text graduate_name.to_s, align: :center, size: 10.mm, color: "000000"
        end

        pdf.move_down(4.mm)

        # "the Degree"
        pdf.font(body_font) do
          pdf.text "the Degree", align: :center, size: 7.mm, color: "565A5C"
        end

        pdf.move_down(4.mm)

        # Degree in Old English
        pdf.font(document_font) do
          pdf.text degree, align: :center, size: 10.mm, color: "000000"
        end

        pdf.move_down(4.mm)

        # Graditude text - with horizontal margins
        margin = nouns.any? ? 60 : 66

        pdf.font(body_font) do
          boilerplate = "with all the rights and privileges thereunto appertaining. In witness thereof and with recognition#{nouns.any? ? " of their #{nouns.join(' and ')}" : ''} this certificate is given to"

          pdf.text_box boilerplate, align: :center, size: 6.mm, color: "565A5C", width: width - (margin * 2).mm, at: [ margin.mm, pdf.cursor ], height: 28.mm, leading: 1.mm

          pdf.move_down(22.mm)

          # Honoree in Old English
          pdf.font(document_font) do
            pdf.text honoree_name, align: :center, size: 12.mm, color: "000000"
          end

          pdf.move_down(4.mm)

          # Date line
          pdf.font(body_font) do
            pdf.text "Given at Boulder on the #{presented_on_text(presented_on_date)}", align: :center, size: 6.mm, color: "565A5C"
          end
        end

        # Bottom row: left column (signature) | center (seal) | right column (message)
        # All elements positioned at the same vertical level
        seal_path = template_assets[:seal]
        seal_width = 45.mm
        col_width = (width - seal_width) / 2 - 10.mm
        row_y = pdf.cursor - 20.mm

        # Left column: signature and certificate info
        pdf.font(document_font) do
          pdf.text_box graduate_name.to_s, align: :center, size: 8.mm, width: col_width, at: [ 5.mm, row_y ]
        end

        pdf.font(body_font) do
          pdf.text_box [ degree, major ].compact.join(", "), align: :center, size: 6.mm, width: col_width, at: [ 5.mm, row_y - 9.mm ]
        end

        # Center: seal horizontally centered
        seal_x = (width / 2) - (seal_width / 2)
        pdf.image seal_path, at: [ seal_x, row_y + 12.mm ], width: seal_width

        # Right column: message (if present)
        if message.present?
          right_x = width - col_width - 5.mm
          pdf.font(body_font) do
            pdf.text_box message, align: :center, size: 8.mm, width: col_width, at: [ right_x, row_y ]
          end
        end
      end

      private

      def parse_presented_on(value)
        return value if value.is_a?(Date)
        return value.to_date if value.respond_to?(:to_date)

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def presented_on_text(date)
        return "" unless date

        day = date.day.ordinalize
        month = Date::MONTHNAMES[date.month]
        year = date.year.humanize.gsub("-", " ")

        "#{day} day of #{month}, A.D. #{year}"
      end
    end
  end
end
