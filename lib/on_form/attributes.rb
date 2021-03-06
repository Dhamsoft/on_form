module OnForm
  module Attributes
    # the individual attribute methods are introduced by the expose_attribute class method.
    # here we introduce some methods used for the attribute set as a whole.

    def [](attribute_name)
      send(attribute_name)
    end

    def []=(attribute_name, attribute_value)
      send("#{attribute_name}=", attribute_value)
    end

    def read_attribute_for_validation(attribute_name)
      send(attribute_name)
    end

    def write_attribute(attribute_name, attribute_value)
      send("#{attribute_name}=", attribute_value)
    end

    def attribute_names
      self.class.exposed_attributes.values.flat_map(&:keys).collect(&:to_s) +
        self.class.introduced_attribute_types.keys.collect(&:to_s)
    end

    def attributes
      attribute_names.each_with_object({}) do |attribute_name, results|
        results[attribute_name] = self[attribute_name]
      end
    end

    def attributes=(attributes)
      # match ActiveRecord #attributes= behavior on nil, scalars, etc.
      if !attributes.respond_to?(:stringify_keys)
        raise ArgumentError, "When assigning attributes, you must pass a hash as an argument."
      end

      multiparameter_attributes = {}
      attributes.each do |attribute_name, attribute_value|
        attribute_name = attribute_name.to_s
        if attribute_name.include?('(')
          multiparameter_attributes[attribute_name] = attribute_value
        else
          write_attribute(attribute_name, attribute_value)
        end
      end
      assign_multiparameter_attributes(multiparameter_attributes)
    end

  private
    def backing_model_instance(backing_model_name)
      send(backing_model_name)
    end

    def backing_model_instances
      self.class.exposed_attributes.keys.collect { |backing_model_name| backing_model_instance(backing_model_name) }
    end

    def backing_for_attribute(exposed_name)
      self.class.exposed_attributes.each do |backing_model_name, attribute_mappings|
        if backing_name = attribute_mappings[exposed_name.to_sym]
          return [backing_model_instance(backing_model_name), backing_name]
        end
      end
      nil
    end
  end
end
