module OnForm
  module Errors
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    private
    def reset_errors
      @errors = nil
    end

    def collect_errors
      self.class.exposed_attributes.each do |backing_model_name, attribute_mappings|
        backing_model = backing_model_instance(backing_model_name)

        attribute_and_collection_mappings = attribute_mappings.dup
        attribute_and_collection_mappings[:base] = :base
        attribute_and_collection_mappings.merge!(collection_attribute_and_mappings(backing_model_name))
        # Swapping key and value ie: backing_name => expose_name
        attribute_and_collection_mappings = Hash[attribute_and_collection_mappings.map(&:reverse)]

        backing_model.errors.each do |backing_name, backing_model_errors|
          collect_errors_on(backing_model_errors, (attribute_and_collection_mappings[backing_name] || backing_name))
        end
      end
    end

    def collect_errors_on(backing_model_errors, exposed_name)
      Array(backing_model_errors).each { |error| errors[exposed_name] << error }
    end

    def collection_attribute_and_mappings(backing_model_name)
      mappings = {}
      return mappings unless collection_wrappers[backing_model_name].present?

      collection_wrappers[backing_model_name].each do |association_name, collection_wrapper|
        association_exposed_name = collection_wrapper[:exposed_name]
        mappings[association_exposed_name] = association_name

        child_record_form = collection_wrapper[:form].loaded_forms.first
        next unless child_record_form

        child_record_form.class.exposed_attributes.each do |_child_model_name, attribute_mappings|
          attribute_mappings.each do |exposed_name, backing_name|
            # TODO: Require fix if index_errors enabled on association
            mappings[:"#{association_exposed_name}.#{exposed_name}"] = :"#{association_name}.#{backing_name}"
          end
        end
      end

      mappings
    end

  end
end
