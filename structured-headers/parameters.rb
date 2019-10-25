
module StructuredHeaders
  class Parameters
    include Enumerable

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
      @hash.key? k.to_s
    end

    def set member_name, member_value
      key = SH::Key.new(member_name)
      case member_value
      when nil
        # noop
      when SH::Item
        member_value.strip_parameters!
      #when SH::InnerList
      #  member_value.strip_parameters!
      #when Array
      #  member_value = SH::InnerList.new member_value
      else
        member_value = SH::Item.new member_value
      end
      @hash[key.to_s] = [key, member_value]
      self
    end
    alias []= set

    # Yields: member-name, member-value
    def each_pair
      return enum_for(:each_pari) unless block_given?
      @hash.each_pair {|_,kv| yield *kv }
    end

    # Yields: [member-name, member-value]
    def each
      return enum_for(:each) unless block_given?
      @hash.each_pair {|_,kv| yield kv }
    end

    def inspect
      "#<#{self.class.name}: #{@hash.map{|_,(k,v)| "#{k.inspect}=#{v.inspect}" }.join(', ')}>"
    end
  end
end

