module Catalog
  module Normalizer
    module_function

    def hashify(value)
      return {} if value.nil?

      hash = if value.is_a?(Hash)
        value
      elsif value.respond_to?(:to_hash)
        value.to_hash
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        {}
      end

      return {} unless hash.is_a?(Hash)

      if hash.respond_to?(:deep_stringify_keys)
        hash.deep_stringify_keys
      else
        hash.transform_keys { |key| key.to_s }
      end
    end

    def paragraphs(text)
      text.to_s
          .split(/\r?\n{2,}|\r?\n/)
          .map(&:strip)
          .reject(&:blank?)
    end

    def list_from_text(value)
      return [] if value.nil?

      if value.is_a?(Array)
        value.map { |item| item.to_s.strip }.reject(&:blank?)
      else
        value.to_s
             .split(/[\r\n,]+/)
             .map(&:strip)
             .reject(&:blank?)
      end
    end

    def list_from_lines(value)
      return [] if value.nil?

      if value.is_a?(Array)
        value.map { |item| item.to_s.strip }.reject(&:blank?)
      else
        value.to_s
             .split(/\r?\n/)
             .map(&:strip)
             .reject(&:blank?)
      end
    end

    def normalize_attributes(attributes)
      list_from_text(attributes)
    end

    def normalize_marketing_features(features)
      Array(features).map do |feature|
        if feature.is_a?(Hash)
          name = feature["name"] || feature[:name]
          description = feature["description"] || feature[:description]
          next if name.blank? && description.blank?

          { "name" => name, "description" => description }.compact
        else
          value = feature.to_s.strip
          next if value.blank?

          { "name" => value }
        end
      end.compact
    end

    def marketing_features_from_text(text)
      text.to_s.lines.map do |line|
        next if line.blank?

        cleaned = line.strip
        name = nil
        description = nil

        if cleaned.include?("|")
          name, description = cleaned.split("|", 2)
        elsif cleaned.include?(" - ")
          name, description = cleaned.split(" - ", 2)
        else
          name = cleaned
        end

        name = name.to_s.strip
        description = description.to_s.strip

        next if name.blank? && description.blank?

        feature = { "name" => name }
        feature["description"] = description if description.present?
        feature
      end.compact
    end

    def variant_format(metadata:, heading:, description:, infer: true)
      metadata = hashify(metadata)
      value = metadata["format"] || metadata["framed"] || metadata["frame"]
      normalized = normalize_variant_value(value)
      return normalized if normalized

      return nil unless infer

      text = [ heading, description ].compact.join(" ").downcase
      return "unframed" if text.include?("unframed") || text.include?("no frame")
      return "framed" if text.include?("framed") || text.include?("frame")

      nil
    end

    def normalize_variant_value(value)
      normalized = value.to_s.downcase.strip
      return "framed" if %w[framed frame true yes 1].include?(normalized)
      return "unframed" if %w[unframed false no 0].include?(normalized)

      nil
    end
  end
end
