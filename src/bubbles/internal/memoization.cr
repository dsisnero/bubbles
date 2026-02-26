require "digest/sha256"

module Bubbles
  module Internal
    module Memoization
      module Hasher
        abstract def memo_hash : String
      end

      struct Entry(T)
        getter key : String
        property value : T

        def initialize(@key : String, @value : T)
        end
      end

      # MemoCache is an LRU cache with fixed capacity.
      class MemoCache(H, T)
        @capacity : Int32
        @mutex : Mutex
        @cache : Hash(String, Entry(T))
        @eviction_list : Array(String)
        @hashable_items : Hash(String, T)

        def initialize(@capacity : Int32)
          @mutex = Mutex.new
          @cache = {} of String => Entry(T)
          @eviction_list = [] of String
          @hashable_items = {} of String => T
        end

        def capacity : Int32
          @capacity
        end

        def size : Int32
          @mutex.synchronize { @eviction_list.size }
        end

        def get(h : H) : {T?, Bool}
          @mutex.synchronize do
            hashed_key = h.memo_hash
            if value = @cache[hashed_key]?
              move_to_front(hashed_key)
              return {value.value, true}
            end
            {nil, false}
          end
        end

        def set(h : H, value : T)
          @mutex.synchronize do
            hashed_key = h.memo_hash
            if entry = @cache[hashed_key]?
              entry.value = value
              @cache[hashed_key] = entry
              move_to_front(hashed_key)
              return
            end

            if @eviction_list.size >= @capacity
              evict_lru
            end

            @cache[hashed_key] = Entry(T).new(hashed_key, value)
            @hashable_items[hashed_key] = value
            @eviction_list.unshift(hashed_key)
          end
        end

        private def move_to_front(hashed_key : String)
          @eviction_list.reject! { |k| k == hashed_key }
          @eviction_list.unshift(hashed_key)
        end

        private def evict_lru
          evicted = @eviction_list.pop?
          return unless evicted
          @cache.delete(evicted)
          @hashable_items.delete(evicted)
        end
      end

      struct HString
        include Hasher

        getter value : String

        def initialize(@value : String)
        end

        def memo_hash : String
          Digest::SHA256.hexdigest(@value)
        end
      end

      struct HInt
        include Hasher

        getter value : Int32

        def initialize(@value : Int32)
        end

        def memo_hash : String
          Digest::SHA256.hexdigest(@value.to_s)
        end
      end
    end
  end
end
