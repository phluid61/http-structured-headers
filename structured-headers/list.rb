
module StructuredHeaders
  class List
    def initialize arr=[]
      @array = []
      arr.each {|v| append v }
    end

    def length
      @array.length
    end

    def empty?
      @array.empty?
    end

    def << list_member
      append list_member
    end

    def append list_member, parameters={}
      # FIXME: dedup this with SH::Dictionary
      case list_member
      when SH::InnerList, SH::Item
        # nop
      when Array
        list_member = SH::InnerList.new list_member
      else
        list_member = SH::Item.new list_member
      end
      parameters = parameters.each_pair.with_object({}) do |(key, value), hsh|
        key = SH::Key.new(key) unless key.is_a? SH::Key
        value = SH::Item.new value unless value.nil?
        hsh[key] = value
      end
      @array << [list_member, parameters]
      self
    end

    # Yields: list-member, {parameters...}
    def each_member
      return enum_for(:each_member) unless block_given?
      @array.each {|e| yield *e }
    end

    # Yields: [list-member, {parameters...}]
    def each
      return enum_for(:each) unless block_given?
      @array.each {|e| yield e }
    end

    def inspect
      "#<#{@array.map{|(v,p)| "#{v.inspect}#{p.map{|k,w|";#{k.inspect}=#{w.inspect}"}.join}"}.join(', ')}>"
    end
  end
end

