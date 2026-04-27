class Certificate < ApplicationRecord
  TEMPLATE_VALUES = %w[boulder westtown penn].freeze
  DEFAULT_MINIMUM_REQUIRED_DATA_FIELDS = %i[graduate_name honoree_name degree presented_on].freeze
  TEMPLATE_MINIMUM_REQUIRED_DATA_FIELDS = {
    "boulder" => DEFAULT_MINIMUM_REQUIRED_DATA_FIELDS,
    "westtown" => DEFAULT_MINIMUM_REQUIRED_DATA_FIELDS + %i[major],
    "penn" => DEFAULT_MINIMUM_REQUIRED_DATA_FIELDS
  }.freeze
  TEMPLATE_OPTIONAL_DATA_FIELDS = {
    "boulder" => %i[message nouns],
    "westtown" => %i[message nouns],
    "penn" => %i[message nouns]
  }.freeze

  belongs_to :user
  has_many :checkout_session_certificates, dependent: :destroy
  has_many :checkout_sessions, through: :checkout_session_certificates

  validates :template, inclusion: { in: TEMPLATE_VALUES }, allow_nil: true
  validates :graduate_name, :honoree_name, :degree, :presented_on, presence: true
  validates :major, presence: true, if: -> { template == "westtown" }
  validate :presented_on_must_be_valid_date

  before_validation :set_default_template, on: :create
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

  def template_data_fields
    TEMPLATE_MINIMUM_REQUIRED_DATA_FIELDS.fetch(self.template.to_s, DEFAULT_MINIMUM_REQUIRED_DATA_FIELDS) +
      TEMPLATE_OPTIONAL_DATA_FIELDS.fetch((self.template.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")).to_s, [])
  end

  private

  def set_default_template
    self.template = ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder") if template.blank?
  end

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

    Date.parse(presented_on.to_s)
  rescue ArgumentError, TypeError
    errors.add(:presented_on, "must be a valid date")
  end

  def attribute_blank?(attribute)
    value = send(attribute)
    value.is_a?(Array) ? value.reject(&:blank?).blank? : value.blank?
  end
end
