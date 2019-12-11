
module StructuredHeaders
  module Parameterised
    def parameters
      @parameters ||= SH::Parameters.new
    end

    def parameters?
      @parameters && !@parameters.empty?
    end

    def parameters= params
      case params
      when SH::Parameters
        # noop
      when Hash
        params = SH::Paramaters.new(params)
      else
        raise "invalid Parameters #{params.inspect}"
      end
      @parameters = params
    end

    def strip_parameters!
      parameters.tap { @parameters = SH::Parameters.new }
    end
  end
end

