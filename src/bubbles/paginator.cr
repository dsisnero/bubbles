require "bubbletea"
require "./key"

module Bubbles
  module Paginator
    enum Type
      Arabic
      Dots
    end

    Arabic = Type::Arabic
    Dots   = Type::Dots

    struct KeyMap
      property prev_page : Bubbles::Key::Binding
      property next_page : Bubbles::Key::Binding

      def initialize(
        @prev_page = Bubbles::Key::Binding.new,
        @next_page = Bubbles::Key::Binding.new,
      )
      end

      # dup creates a copy of the keymap
      def dup : KeyMap
        KeyMap.new(@prev_page.dup, @next_page.dup)
      end
    end

    def self.default_key_map : KeyMap
      KeyMap.new(
        prev_page: Bubbles::Key.new_binding(Bubbles::Key.with_keys("pgup", "left", "h")),
        next_page: Bubbles::Key.new_binding(Bubbles::Key.with_keys("pgdown", "right", "l"))
      )
    end

    alias Option = Proc(Model, Nil)

    def self.with_total_pages(total_pages : Int32) : Option
      ->(m : Model) { m.total_pages = total_pages }
    end

    def self.with_per_page(per_page : Int32) : Option
      ->(m : Model) { m.per_page = per_page }
    end

    class Model
      property type : Type
      property page : Int32
      property per_page : Int32
      property total_pages : Int32
      property active_dot : String
      property inactive_dot : String
      property arabic_format : String
      property key_map : KeyMap

      def initialize
        @type = Type::Arabic
        @page = 0
        @per_page = 1
        @total_pages = 1
        @active_dot = "•"
        @inactive_dot = "○"
        @arabic_format = "%d/%d"
        @key_map = Paginator.default_key_map
      end

      def self.new : Model
        m = allocate
        m.initialize
        m
      end

      def self.new(*opts : Option) : Model
        m = allocate
        m.initialize
        opts.each(&.call(m))
        m
      end

      def set_total_pages(items : Int32) : Int32 # ameba:disable Naming/AccessorMethodName
        return @total_pages if items < 1
        n = items // @per_page
        n += 1 if items % @per_page > 0
        @total_pages = n
        n
      end

      def items_on_page(total_items : Int32) : Int32
        return 0 if total_items < 1
        start, finish = get_slice_bounds(total_items)
        finish - start
      end

      def get_slice_bounds(length : Int32) : {Int32, Int32}
        start = @page * @per_page
        finish = Math.min(@page * @per_page + @per_page, length)
        {start, finish}
      end

      def prev_page
        @page -= 1 if @page > 0
      end

      def next_page
        @page += 1 unless on_last_page?
      end

      def on_last_page? : Bool
        @page == @total_pages - 1
      end

      def on_last_page : Bool
        on_last_page?
      end

      def on_first_page? : Bool
        @page == 0
      end

      def on_first_page : Bool
        on_first_page?
      end

      # dup creates a copy of the model for functional updates
      def dup : Model
        m = Model.new
        m.type = @type
        m.page = @page
        m.per_page = @per_page
        m.total_pages = @total_pages
        m.active_dot = @active_dot.dup
        m.inactive_dot = @inactive_dot.dup
        m.arabic_format = @arabic_format.dup
        m.key_map = @key_map.dup
        m
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        m = self.dup
        case msg
        when Tea::KeyPressMsg
          if Bubbles::Key.matches?(msg, m.key_map.next_page)
            m.next_page
          elsif Bubbles::Key.matches?(msg, m.key_map.prev_page)
            m.prev_page
          end
        end
        {m, nil}
      end

      def view : String
        case @type
        when Type::Dots
          dots_view
        else
          arabic_view
        end
      end

      private def dots_view : String
        String.build do |io|
          @total_pages.times do |i|
            io << (i == @page ? @active_dot : @inactive_dot)
          end
        end
      end

      private def arabic_view : String
        @arabic_format % {@page + 1, @total_pages}
      end
    end

    def self.new : Model
      Model.new
    end

    def self.new(*opts : Option) : Model
      Model.new(*opts)
    end
  end
end
