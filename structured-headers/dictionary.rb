
module StructuredHeaders
  class Dictionary
    def initialize hsh={}
      @hash = {}
      hsh.each_pair {|k,v| set k, v }
    end

    def length
      @hash.length
    end

    def empty?
      @hash.empty?
    end

    def key? k
      @hash.each_key {|j| return true if j.to_s == k }
      false
    end

    def []= member_name, member_value
      set member_name, member_value
    end

    def set member_name, member_value, parameters={}
      key = SH::Key.new(member_name)
      # FIXME: dedup this with SH::List
      case member_value
      when SH::InnerList, SH::Item
        # nop
      when Array
        member_value = SH::InnerList.new member_value
      else
        member_value = SH::Item.new member_value
      end
      parameters = parameters.each_pair.with_object({}) do |(key, value), hsh|
        key = SH::Key.new(key) unless key.is_a? SH::Key
        value = SH::Item.new value unless value.nil?
        hsh[key] = value
      end
      @hash[key] = [member_value, parameters]
      self
    end

    # Yields: member-name, member-value, {parameters...}
    def each_member
      return enum_for(:each_member) unless block_given?
      @hash.each_pair {|k,v| yield k, *v }
    end

    # Yields: [member-name, member-value, {parameters...}]
    def each
      return enum_for(:each) unless block_given?
      @hash.each_pair {|k,v| yield [k, *v] }
    end

    def inspect
      "#<#{@hash.map{|k,(v,p)| "#{k.inspect}=#{v.inspect}#{p.map{|l,w|";#{l.inspect}=#{w.inspect}"}.join}"}.join(', ')}>"
    end
  end
end

