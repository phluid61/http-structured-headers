
module StructuredHeaders
  class InnerList
    include SH::Parameterised
    include Enumerable

    def initialize arr=[], params={}
      @array = []
      arr.each {|v| append v }
    end

    def length
      @array.length
    end

    def empty?
      @array.empty?
    end

    def append list_member
      # convert list_member to an Item
      case list_member
      when SH::Item
        # nop
      else
        list_member = SH::Item.new list_member
      end
      @array << list_member
      self
    end
    alias << append

    # Yields: list-member
    def each_member
      return enum_for(:each_member) unless block_given?
      @array.each {|e| yield e }
    end
    alias each each_member

    def inspect
      "#<#{self.class.name}: [#{@array.map{|v|v.inspect}.join(' ')}]>"
    end
  end
end

