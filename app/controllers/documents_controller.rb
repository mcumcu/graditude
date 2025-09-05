class DocumentsController < ApplicationController
  include Printable

  def index
    @params = default_params.merge!(
      graduate_name: "Meili Blaine Elizabeth Unger",
      degree: "Bachelor of Science",
      honoree_name: "Michael Christopher Unger",
      major: "Organic Chemistry",
      nouns: [
        "love",
        "support"
      ],
      message: [
        "Gratias tibi ago pro amore et auxilio tuo"
        # "Thank you for your love and support"
      ],
      presented_on: "May 2026",
      signature_path: "givers_signature.png"
    )

    respond_to do |format|
      format.html
      format.pdf
      format.png
    end
  end
end
