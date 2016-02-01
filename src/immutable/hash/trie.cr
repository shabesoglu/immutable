module Immutable
  struct Hash(K, V)
    struct Trie(K, V)
      BITS_PER_LEVEL = 5_u32
      BLOCK_SIZE = (2 ** BITS_PER_LEVEL).to_u32
      INDEX_MASK = BLOCK_SIZE - 1

      getter :size, :levels

      @children : Array(Trie(K, V))
      @bitmap   : UInt32
      @values   : Array(::Hash(K, V))
      @size     : Int32
      @levels   : Int32

      def initialize(@children : Array(Trie(K, V)), @bitmap, @levels : Int32)
        @size   = @children.reduce(0) { |size, child| size + child.size }
        @values = [] of ::Hash(K, V)
      end

      def initialize(@values : Array(::Hash(K, V)), @bitmap : UInt32)
        @size     = @values.reduce(0) { |size, h| size + h.size }
        @levels   = 0
        @children = [] of Trie(K, V)
      end

      def self.empty
        new([] of Trie(K, V), 0_u32, 6)
      end

      def get(key : K)
        lookup(key.hash) { |hash| hash[key] }
      end

      def fetch(key : K, &block : K -> U)
        lookup(key.hash) { |hash| hash.fetch(key, &block) }
      end

      def has_key?(key : K)
        lookup(key.hash) { |hash| hash.has_key?(key) }
      end

      def set(key : K, value : V) : Trie(K, V)
        set_at_index(key.hash, key, value)
      end

      protected def set_at_index(index : Int32, key : K, value : V) : Trie(K, V)
        if leaf?
          set_leaf(index, key, value)
        else
          set_branch(index, key, value)
        end
      end

      private def leaf?
        @levels == 0
      end

      protected def lookup(index : Int32, &block : ::Hash(K, V) -> U)
        return yield({} of K => V) unless i = child_index(bit_index(index))
        if leaf?
          yield @values[i]
        else
          @children[i].lookup(index, &block)
        end
      end

      private def set_leaf(index : Int32, key : K, value : V) : Trie(K, V)
        i = bit_index(index)
        if idx = child_index(i)
          values = @values.dup.tap do |vs|
            vs[idx] = vs[idx].dup
            vs[idx][key] = value
          end
          Trie.new(values, @bitmap)
        else
          bucket = {} of K => V
          bucket[key] = value
          Trie.new(@values.dup.push(bucket), @bitmap | bitpos(i))
        end
      end

      private def set_branch(index : Int32, key : K, value : V) : Trie(K, V)
        i = bit_index(index)
        if idx = child_index(i)
          children = @children.dup.tap do |cs|
            cs[idx] = cs[idx].set_at_index(index, key, value)
          end
          Trie.new(children, @bitmap, @levels)
        else
          if @levels > 1
            child = Trie.new([] of Trie(K, V), 0_u32, @levels - 1)
          else
            child = Trie.new([] of ::Hash(K, V), 0_u32)
          end
          child = child.set_at_index(index, key, value)
          Trie.new(@children.dup.push(child), @bitmap | bitpos(i), @levels)
        end
      end

      private def bitpos(i : Int32)
        1_u32 << i
      end

      private def child_index(i : Int32)
        pos = bitpos(i)
        return nil unless (pos & @bitmap) == pos
        popcount(@bitmap & (pos - 1))
      end

      private def popcount(x : UInt32)
        x = x - ((x >> 1) & 0x55555555_u32)
        x = (x & 0x33333333_u32) + ((x >> 2) & 0x33333333_u32)
        (((x + (x >> 4)) & 0x0F0F0F0F_u32) * 0x01010101_u32) >> 24
      end

      private def bit_index(index : Int32)
        (index >> (@levels * BITS_PER_LEVEL)) & INDEX_MASK
      end
    end
  end
end
