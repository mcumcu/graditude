# frozen_string_literal: true

module GraditudeFactory
  module Certificates
    class PennTemplate < Template
      def page_config
        {
          page_size: "LETTER",
          page_layout: :landscape,
          margin: [0, 0, 0, 0]
        }
      end

      def document_font
        asset_path(:font, "OPTIEngraversOldEnglish.otf")
      end

      def signature_font
        asset_path(:font, "HomemadeApple-Regular.ttf")
      end

      def template_assets
        {
          background: asset_path(:image, "paper.jpg"),
          banner: asset_path(:image, "penn.svg"),
          seal: asset_path(:image, "penn_seal.png")
        }
      end

      def render_background(pdf)
        background = template_assets[:background]
        pdf.float do
          pdf.image background, width: pdf.margin_box.width, height: pdf.margin_box.height, position: :center
        end
      end

      def render_header(pdf)
        banner_path = template_assets[:banner]
        seal_path = template_assets[:seal]

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

      def render_content(pdf)
        graduate_name = @params["graduate_name"] || " "
        degree = @params["degree"]
        honoree_name = @params["honoree_name"] || " "
        major = @params["major"]
        nouns = @params["nouns"]&.reject { |n| n.empty? } || []
        message = @params["message"] || ""
        presented_on = @params["presented_on"] || ""

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

        pdf.text "Presented #{presented_on}".strip, align: :center, size: 5.mm if presented_on.present?

        pdf.move_down(14.mm)

        # left column
        container_width = message.size == 0 ? width : half_width

        pdf.font(signature_font) do
          pdf.text_box graduate_name.to_s, align: :center, size: 6.mm, width: container_width, at: [0, pdf.cursor - 1.5.mm]
        end

        pdf.text_box [degree, major].compact.join(", "), align: :center, size: 3.5.mm, width: container_width, at: [0, pdf.cursor - 12.mm]

        # right column
        pdf.text_box message, align: :center, size: 6.mm, width: (half_width) - margin_horizontal, at: [(half_width) + 10.mm, pdf.cursor - 10.5.mm]
      end
    end
  end
end
