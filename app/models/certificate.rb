class Certificate < ApplicationRecord
  TEMPLATE_VALUES = %w[boulder westtown penn].freeze

  belongs_to :user

  validates :template, inclusion: { in: TEMPLATE_VALUES }, allow_nil: true
  validate :presented_on_must_be_valid_date

  before_validation :normalize_presented_on

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

  private

  def normalize_presented_on
    value = presented_on
    return if value.blank?

    if value.is_a?(Date)
      self.presented_on = value.to_s
    elsif value.is_a?(String)
      self.presented_on = Date.parse(value).to_s
    elsif value.respond_to?(:to_date)
      self.presented_on = value.to_date.to_s
    end
  rescue ArgumentError, TypeError
    # Keep the original value so validation can add an error instead of silently clearing it.
  end

  def presented_on_must_be_valid_date
    return if presented_on.blank?

    Date.parse(presented_on)
  rescue ArgumentError, TypeError
    errors.add(:presented_on, "must be a valid date")
  end
end
