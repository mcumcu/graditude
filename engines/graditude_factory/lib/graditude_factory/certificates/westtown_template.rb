# frozen_string_literal: true

module GraditudeFactory
  module Certificates
    class WesttownTemplate < Template
      def page_config
        {
          page_size: [175.mm, 227.mm],
          page_layout: :landscape,
          margin: [0, 0, 0, 0]
        }
      end

      def document_font
        asset_path(:font, "Jost-VariableFont_wght.ttf")
      end

      def name_font
        asset_path(:font, "Literata-SemiBold.ttf")
      end

      def signature_font
        asset_path(:font, "HomemadeApple-Regular.ttf")
      end

      def template_assets
        {
          banner: asset_path(:image, "westtown.svg"),
          seal: asset_path(:image, "westtown_seal.svg")
        }
      end

      def render_header(pdf)
        banner_path = template_assets[:banner]
        seal_path = template_assets[:seal]

        pdf.float do
          pdf.bounding_box([5.mm, pdf.margin_box.height - 5.mm], width: pdf.margin_box.width - 10.mm, height: pdf.margin_box.height - 10.mm) do
            pdf.transparent(0.5.pt) { pdf.stroke_bounds }
          end

          pdf.bounding_box([6.mm, pdf.margin_box.height - 6.mm], width: pdf.margin_box.width - 12.mm, height: pdf.margin_box.height - 12.mm) do
            pdf.transparent(1.pt) { pdf.stroke_bounds }
          end
        end

        pdf.move_down(20.mm)

        pdf.svg File.read(banner_path), width: 170.mm, position: :center

        pdf.move_down(9.mm)

        pdf.text_box "WEST CHESTER", align: :left, size: 4.5.mm, at: [54.mm, pdf.cursor - 9.7.mm], kerning: true, character_spacing: 0.8

        pdf.text_box "PENNSYLVANIA", align: :left, size: 4.5.mm, at: [138.mm, pdf.cursor - 9.7.mm], kerning: true, character_spacing: 0.8

        pdf.svg File.read(seal_path), width: 25.4.mm, position: :center

        pdf.move_down(6.mm)

        pdf.text "This is to certify that", align: :center, size: 3.5.mm

        pdf.move_down(2.mm)
      end

      def render_content(pdf)
        graduate_name = @params["graduate_name"] || " "
        honoree_name = @params["honoree_name"] || " "
        nouns = @params["nouns"]&.reject { |n| n.empty? } || []
        message = @params["message"] || ""
        presented_on = @params["presented_on"] || ""

        pdf.font(name_font) do
          pdf.text graduate_name.to_s, align: :center, size: 9.mm
        end

        pdf.move_down(3.mm)

        pdf.text "has successfully completed the requirements for graduation", align: :center, size: 3.5.mm
        pdf.text nouns.any? ? "and hereby recognizes the #{nouns.join(' and ').downcase} of" : nil, align: :center, size: 3.5.mm

        pdf.move_down(3.mm)

        pdf.font(name_font) do
          pdf.text honoree_name.to_s, align: :center, size: 9.mm
        end

        pdf.move_down(3.mm)

        # Format the date if presented_on is provided
        date_text = if presented_on.present?
          "on this #{presented_on.split(' ').slice(0...-1).join(' ')}, #{presented_on.split(' ').last.to_i.humanize}."
        else
          ""
        end
        pdf.text date_text, align: :center, size: 3.5.mm

        pdf.move_down(3.mm)

        # left column
        container_width = message.size == 0 ? width : half_width

        pdf.font(signature_font) do
          pdf.text_box graduate_name.to_s, align: :center, size: 4.mm, width: container_width, at: [0, pdf.cursor - 8.mm]
        end

        year = presented_on.present? ? presented_on.split(' ').last : ""
        pdf.text_box "Westtown School, #{year}", align: :center, size: 3.5.mm, width: container_width, at: [0, pdf.cursor - 14.mm]

        pdf.text_box message, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, at: [(half_width) + 10.mm, pdf.cursor - 5.mm]
      end
    end
  end
end
