
module StructuredFields
  class List
    include Enumerable

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

    def last
      @array.last
    end

    def append list_member
      case list_member
      when StructuredFields::InnerList, StructuredFields::Item
        # nop
      when Array
        list_member = StructuredFields::InnerList.new list_member
      else
        list_member = StructuredFields::Item.new list_member
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
      "#<#{self.class.name}: [#{@array.map{|v| v.inspect }.join(', ')}]>"
    end
  end
end

