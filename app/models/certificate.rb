class Certificate < ApplicationRecord
  belongs_to :user

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
