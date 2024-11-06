
module StructuredFields
  module Parameterised
    def parameters
      @parameters ||= StructuredFields::Parameters.new
    end

    def parameters?
      @parameters && !@parameters.empty?
    end

    def parameters= params
      case params
      when Array
        params = params.to_h
      when StructuredFields::Parameters
        # noop
      when Hash
        params = StructuredFields::Parameters.new(params)
      else
        raise "invalid Parameters #{params.inspect}"
      end
      @parameters = params
    end

    def strip_parameters!
      parameters.tap { @parameters = StructuredFields::Parameters.new }
    end
  end
end

