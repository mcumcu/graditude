class Certificate < ApplicationRecord
  TEMPLATE_VALUES = %w[boulder westtown penn].freeze

  belongs_to :user

  validates :template, inclusion: { in: TEMPLATE_VALUES }, allow_nil: true

  store_accessor(:data,
    :graduate_name,
    :degree,
    :major,
    :nouns,
    :honoree_name,
    :message,
    :presented_on,
    :signature_path
  )
end
