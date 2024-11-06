
module StructuredFields
  class Dictionary
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
      key = StructuredFields::Key.new(member_name)
      case member_value
      when StructuredFields::InnerList, StructuredFields::Item
        # nop
      when Array
        member_value = StructuredFields::InnerList.new member_value
      else
        member_value = StructuredFields::Item.new member_value
      end
      @hash[key.to_s] = [key, member_value]
      self
    end
    alias []= set

    # Yields: member-name, member-value
    def each_member
      return enum_for(:each_member) unless block_given?
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

