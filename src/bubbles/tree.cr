require "lipgloss"
require "ansi"
require "./key"
require "./help"
require "./viewport"

module Bubbles
  # Tree provides a tree component for Bubble Tea applications.
  #
  # Ported from Go: vendor/bubbles/tree/tree.go (v2.2.2)
  module Tree
    SPACEBAR = " "

    # Value types accepted by nodes. Go accepts `any`; the common primitives
    # are listed explicitly and any type including `DisplayValue` works too.
    module DisplayValue
      abstract def to_s : String
    end

    alias ValueType = String | Int32 | Int64 | Float32 | Float64 | Bool | Nil | DisplayValue

    # StyleFunc allows the tree to be styled per item.
    alias StyleFunc = Proc(Array(Node), Int32, Lipgloss::Style)

    # KeyMap is the key bindings for different actions within the tree.
    # Ported from Go: vendor/bubbles/tree/tree.go:20
    class KeyMap
      property down : Bubbles::Key::Binding
      property up : Bubbles::Key::Binding
      property page_down : Bubbles::Key::Binding
      property page_up : Bubbles::Key::Binding
      property half_page_up : Bubbles::Key::Binding
      property half_page_down : Bubbles::Key::Binding
      property go_to_top : Bubbles::Key::Binding
      property go_to_bottom : Bubbles::Key::Binding
      property toggle : Bubbles::Key::Binding
      property open : Bubbles::Key::Binding
      property close : Bubbles::Key::Binding
      property show_full_help : Bubbles::Key::Binding
      property close_full_help : Bubbles::Key::Binding

      def initialize(
        @down = Bubbles::Key::Binding.new,
        @up = Bubbles::Key::Binding.new,
        @page_down = Bubbles::Key::Binding.new,
        @page_up = Bubbles::Key::Binding.new,
        @half_page_up = Bubbles::Key::Binding.new,
        @half_page_down = Bubbles::Key::Binding.new,
        @go_to_top = Bubbles::Key::Binding.new,
        @go_to_bottom = Bubbles::Key::Binding.new,
        @toggle = Bubbles::Key::Binding.new,
        @open = Bubbles::Key::Binding.new,
        @close = Bubbles::Key::Binding.new,
        @show_full_help = Bubbles::Key::Binding.new,
        @close_full_help = Bubbles::Key::Binding.new,
      )
      end
    end

    # DefaultKeyMap returns the default key bindings.
    # Ported from Go: vendor/bubbles/tree/tree.go:45
    def self.default_key_map : KeyMap
      KeyMap.new(
        down: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("down", "j", "ctrl+n"),
          Bubbles::Key.with_help("↓/j", "down")),
        up: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("up", "k", "ctrl+p"),
          Bubbles::Key.with_help("↑/k", "up")),
        page_down: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("pgdown", SPACEBAR, "f"),
          Bubbles::Key.with_help("f/pgdn", "page down")),
        page_up: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("pgup", "b"),
          Bubbles::Key.with_help("b/pgup", "page up")),
        half_page_down: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("d", "ctrl+d"),
          Bubbles::Key.with_help("d", "½ page down")),
        half_page_up: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("u", "ctrl+u"),
          Bubbles::Key.with_help("u", "½ page up")),
        go_to_top: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("g", "home"),
          Bubbles::Key.with_help("g", "top")),
        go_to_bottom: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("G", "shift+g", "end"),
          Bubbles::Key.with_help("G", "bottom")),
        toggle: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("enter"),
          Bubbles::Key.with_help("⏎", "toggle")),
        open: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("l", "right"),
          Bubbles::Key.with_help("→/l", "open")),
        close: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("h", "left"),
          Bubbles::Key.with_help("←/h", "close")),
        show_full_help: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("?"),
          Bubbles::Key.with_help("?", "more")),
        close_full_help: Bubbles::Key.new_binding(
          Bubbles::Key.with_keys("?"),
          Bubbles::Key.with_help("?", "close help"))
      )
    end

    # Styles contains style definitions for this tree component.
    # Ported from Go: vendor/bubbles/tree/styles.go:12
    class Styles
      property tree_style : Lipgloss::Style
      property help_style : Lipgloss::Style

      property selected_node_style : Lipgloss::Style
      property node_style : Lipgloss::Style
      property root_node_style : Lipgloss::Style
      property parent_node_style : Lipgloss::Style
      property cursor_style : Lipgloss::Style
      property enumerator_style : Lipgloss::Style
      property selected_enumerator_style : Lipgloss::Style
      property indenter_style : Lipgloss::Style
      property open_indicator_style : Lipgloss::Style

      property selected_node_func : StyleFunc?
      property selected_node_style_func : StyleFunc?
      property node_func : StyleFunc?
      property node_style_func : StyleFunc?
      property root_node_func : StyleFunc?
      property root_node_style_func : StyleFunc?
      property parent_node_func : StyleFunc?
      property parent_node_style_func : StyleFunc?
      property enumerator_func : StyleFunc?
      property enumerator_style_func : StyleFunc?
      property selected_enumerator_func : StyleFunc?
      property selected_enumerator_style_func : StyleFunc?
      property indenter_func : StyleFunc?
      property indenter_style_func : StyleFunc?

      def initialize(
        @tree_style = Lipgloss::Style.new,
        @help_style = Lipgloss::Style.new,
        @selected_node_style = Lipgloss::Style.new,
        @node_style = Lipgloss::Style.new,
        @root_node_style = Lipgloss::Style.new,
        @parent_node_style = Lipgloss::Style.new,
        @cursor_style = Lipgloss::Style.new,
        @enumerator_style = Lipgloss::Style.new,
        @selected_enumerator_style = Lipgloss::Style.new,
        @indenter_style = Lipgloss::Style.new,
        @open_indicator_style = Lipgloss::Style.new,
        @selected_node_func = nil,
        @selected_node_style_func = nil,
        @node_func = nil,
        @node_style_func = nil,
        @root_node_func = nil,
        @root_node_style_func = nil,
        @parent_node_func = nil,
        @parent_node_style_func = nil,
        @enumerator_func = nil,
        @enumerator_style_func = nil,
        @selected_enumerator_func = nil,
        @selected_enumerator_style_func = nil,
        @indenter_func = nil,
        @indenter_style_func = nil,
      )
      end
    end

    # DefaultStyles returns a set of default style definitions.
    # Ported from Go: vendor/bubbles/tree/styles.go:43
    def self.default_styles(is_dark : Bool) : Styles
      ld = ->(light : String, dark : String) { Lipgloss.color(is_dark ? dark : light) }
      very_subdued = ld.call("#DDDADA", "#3C3C3C")
      subdued = ld.call("#9B9B9B", "#5C5C5C")

      s = Styles.new
      s.tree_style = Lipgloss::Style.new
      s.help_style = Lipgloss::Style.new.padding_top(1)

      s.node_style = Lipgloss::Style.new.foreground(ld.call("#9B9B9B", "#B0B0B0"))
      s.node_func = ->(_nodes : Array(Node), _i : Int32) { s.node_style }

      s.selected_node_style = s.node_style.foreground(ld.call("249", "212")).bold(true)
      s.selected_node_func = ->(_nodes : Array(Node), _i : Int32) { s.selected_node_style }

      s.root_node_style = Lipgloss::Style.new.foreground(Lipgloss.color("#EE6FF8"))
      s.root_node_func = ->(_nodes : Array(Node), _i : Int32) { s.root_node_style }

      s.parent_node_style = Lipgloss::Style.new.foreground(ld.call("90", "99"))
      s.parent_node_func = ->(_nodes : Array(Node), _i : Int32) { s.parent_node_style }

      s.cursor_style = Lipgloss::Style.new
        .padding_right(1)
        .foreground(ld.call("249", "212"))
        .bold(true)

      s.enumerator_style = Lipgloss::Style.new.foreground(very_subdued)
      s.enumerator_func = ->(_nodes : Array(Node), _i : Int32) { s.enumerator_style }

      s.selected_enumerator_style = s.enumerator_style
      s.selected_enumerator_func = ->(_nodes : Array(Node), _i : Int32) { s.selected_enumerator_style }

      s.indenter_style = Lipgloss::Style.new.foreground(very_subdued)
      s.indenter_func = ->(_nodes : Array(Node), _i : Int32) { s.indenter_style }

      s.open_indicator_style = Lipgloss::Style.new.foreground(subdued)
      s
    end

    def self.default_dark_styles : Styles
      default_styles(true)
    end

    def self.default_light_styles : Styles
      default_styles(false)
    end

    # ItemOptions are the per-node render options.
    # Ported from Go: vendor/bubbles/tree/node.go:104
    class ItemOptions
      property open_character : String
      property closed_character : String
      property tree_y_offset : Int32
      property styles : Styles

      def initialize(
        @open_character = "",
        @closed_character = "",
        @tree_y_offset = 0,
        @styles = Tree.default_dark_styles,
      )
      end
    end

    # Node is a node in the tree.
    #
    # A Node implements Lipgloss::Tree::Node and wraps a Lipgloss tree used as
    # the renderer layer.
    # Ported from Go: vendor/bubbles/tree/node.go:9
    class Node
      include Lipgloss::Tree::Node

      property tree : Lipgloss::Tree::Tree
      property y_offset : Int32
      property line_offset : Int32
      property is_root : Bool        # ameba:disable Naming/QueryBoolMethods
      property initial_closed : Bool # ameba:disable Naming/QueryBoolMethods
      getter? open : Bool
      property given_value : ValueType
      property opts : ItemOptions

      def open=(value : Bool)
        @open = value
      end

      def initialize(
        @tree = Lipgloss::Tree::Tree.new,
        @y_offset = 0,
        @line_offset = 0,
        @is_root = false,
        @initial_closed = false,
        @open = false,
        @given_value = nil,
        @opts = ItemOptions.new,
      )
      end

      # Indicator returns the rendered open/closed symbol.
      # Ported from Go: vendor/bubbles/tree/node.go:38
      def indicator : String
        char = @open ? @opts.open_character : @opts.closed_character
        char = "#{char} " unless char.empty?
        @opts.styles.open_indicator_style.render(char)
      end

      # IsSelected returns whether this item is selected.
      def is_selected? : Bool # ameba:disable Naming/PredicateName
        @y_offset == @opts.tree_y_offset
      end

      # Size returns the number of nodes in the tree. If a child isn't open,
      # its size is 1.
      def size : Int32
        all_nodes.size
      end

      # Height returns the number of rendered lines of the node.
      def height : Int32
        Lipgloss.height(to_s)
      end

      # Close closes the node.
      def close : Node
        @initial_closed = true
        @open = false
        @tree.offset(0, 0)
        @tree.offset(@tree.children.length, 0)
        self
      end

      # Open opens the node.
      def open : Node
        @initial_closed = false
        @open = true
        @tree.offset(0, 0)
        self
      end

      def is_open? : Bool # ameba:disable Naming/PredicateName
        @open
      end

      def to_s(io : IO) : Nil
        io << @tree.to_s
      end

      # Value returns the rendered value of this node.
      # Ported from Go: vendor/bubbles/tree/node.go:162
      def value : String
        v = get_style.render(@tree.value)
        return v unless @is_root

        Lipgloss::Style.join_horizontal(Lipgloss::Position::Top, indicator, v)
      end

      def value=(value : String)
        @tree.value = value
      end

      # SetValue sets the value of the node.
      # Ported from Go: vendor/bubbles/tree/node.go:173
      def set_value(value) : Nil # ameba:disable Naming/AccessorMethodName
        @given_value = value.is_a?(ValueType) ? value : value.to_s
        @tree.set_value(value)
      end

      # Children returns the children of an item.
      def children : Lipgloss::Tree::Children
        @tree.children
      end

      # ChildNodes returns the children of an item as Nodes.
      def child_nodes : Array(Node)
        res = [] of Node
        kids = @tree.children
        kids.length.times do |i|
          child = kids.at(i)
          res << child.as(Node) if child.is_a?(Node)
        end
        res
      end

      # AllNodes returns all descendant nodes as a flat list.
      def all_nodes : Array(Node)
        res = [self]
        kids = @tree.children
        kids.length.times do |i|
          child = kids.at(i)
          res.concat(child.as(Node).all_nodes) if child.is_a?(Node)
        end
        res
      end

      # Hidden returns whether this item is hidden.
      def hidden? : Bool
        @tree.hidden?
      end

      def set_hidden(hidden : Bool) : Nil # ameba:disable Naming/AccessorMethodName
        @tree.set_hidden(hidden)
      end

      # get_style returns the style for this node.
      # Ported from Go: vendor/bubbles/tree/node.go:115
      def get_style : Lipgloss::Style # ameba:disable Naming/AccessorMethodName
        s = @opts.styles
        if @y_offset == @opts.tree_y_offset && (f = s.selected_node_func)
          return f.call([self], 0)
        elsif @y_offset == 0 && (f = s.root_node_func)
          return f.call([self], 0)
        elsif @is_root && (f = s.parent_node_func)
          return f.call([self], 0)
        elsif f = s.node_func
          return f.call([self], 0)
        end

        Lipgloss::Style.new
      end

      def get_enumerator_style : Lipgloss::Style # ameba:disable Naming/AccessorMethodName
        s = @opts.styles
        if @y_offset == @opts.tree_y_offset && (f = s.selected_enumerator_func)
          return f.call([self], 0)
        elsif f = s.enumerator_func
          return f.call([self], 0)
        end

        Lipgloss::Style.new
      end

      def get_indenter_style : Lipgloss::Style # ameba:disable Naming/AccessorMethodName
        if f = @opts.styles.indenter_func
          return f.call([self], 0)
        end

        Lipgloss::Style.new
      end

      # ItemStyle sets a static style for all items.
      def item_style(style : Lipgloss::Style) : Node
        @tree.item_style(style)
        self
      end

      def item_style_func(f : StyleFunc) : Node
        @tree.item_style_func(->(children : Lipgloss::Tree::Children, i : Int32) {
          c = [] of Node
          children.length.times do |idx|
            child = children.at(idx)
            c << child.as(Node) if child.is_a?(Node)
          end
          f.call(c, i)
        })
        self
      end

      # Enumerator sets the enumerator implementation.
      def enumerator(enumerator : Lipgloss::Tree::Enumerator) : Node
        @tree.enumerator(enumerator)
        self
      end

      # Indenter sets the indenter implementation.
      def indenter(indenter : Lipgloss::Tree::Indenter) : Node
        @tree.indenter(indenter)
        self
      end

      def enumerator_style(style : Lipgloss::Style) : Node
        @tree.enumerator_style(style)
        self
      end

      def enumerator_style_func(f : StyleFunc) : Node
        @tree.enumerator_style_func(->(children : Lipgloss::Tree::Children, i : Int32) {
          c = [] of Node
          children.length.times do |idx|
            child = children.at(idx)
            c << child.as(Node) if child.is_a?(Node)
          end
          f.call(c, i)
        })
        self
      end

      def indenter_style(style : Lipgloss::Style) : Node
        @tree.indenter_style(style)
        self
      end

      def indenter_style_func(f : StyleFunc) : Node
        @tree.indenter_style_func(->(children : Lipgloss::Tree::Children, i : Int32) {
          c = [] of Node
          children.length.times do |idx|
            child = children.at(idx)
            c << child.as(Node) if child.is_a?(Node)
          end
          f.call(c, i)
        })
        self
      end

      # RootStyle sets a style for the root element.
      def root_style(style : Lipgloss::Style) : Node
        @tree.root_style(style)
        self
      end

      # Child adds a child to this tree.
      # Ported from Go: vendor/bubbles/tree/node.go:349
      def child(*children : ValueType | Node) : Node
        children.each do |child|
          case child
          when Node
            @tree.child(child)
          else
            item = Node.plain
            item.opts = ItemOptions.new(styles: Tree.default_dark_styles)
            item.tree = Lipgloss::Tree::Tree.root(child)
            item.open = false
            item.given_value = child
            @tree.child(item)
          end

          close if @initial_closed
        end

        self
      end

      # NewNode returns a new node.
      def self.new : Node
        node = allocate
        node.initialize
        node.opts = ItemOptions.new(styles: Tree.default_dark_styles)
        node.open = true
        node.is_root = true
        node.tree = Lipgloss::Tree::Tree.new
        node
      end

      # plain returns an unconfigured node, matching Go's `new(Node)`.
      def self.plain : Node
        node = allocate
        node.initialize
        node
      end

      # Root returns a new tree with the root set.
      def self.root(root : ValueType) : Node
        node = Node.new
        node.given_value = root
        node.tree = Lipgloss::Tree::Tree.root(root)
        node
      end
    end

    # Model is the Bubble Tea model for this tree element.
    # Ported from Go: vendor/bubbles/tree/tree.go:111
    class Model
      include Help::KeyMap

      property key_map : KeyMap
      property help : Help::Model
      property show_help : Bool # ameba:disable Naming/QueryBoolMethods
      property scroll_off : Int32
      property open_character : String
      property closed_character : String
      property cursor_character : String
      property root : Node
      property viewport : Viewport::Model
      property width : Int32
      property height : Int32
      property y_offset : Int32
      getter styles : Styles
      getter enumerator : Lipgloss::Tree::Enumerator?
      getter indenter : Lipgloss::Tree::Indenter?
      property additional_short_help_keys : Proc(Array(Bubbles::Key::Binding))?
      property additional_full_help_keys : Proc(Array(Array(Bubbles::Key::Binding)))?

      def initialize(root : Node?, width : Int32, height : Int32)
        @key_map = Tree.default_key_map
        @help = Help.new
        @show_help = true
        @scroll_off = 5
        @open_character = "▼"
        @closed_character = "▶"
        @cursor_character = "→"
        @styles = Styles.new
        @enumerator = nil
        @indenter = nil
        @additional_short_help_keys = nil
        @additional_full_help_keys = nil
        @root = root || Node.new
        @viewport = Viewport::Model.new
        @viewport.key_map = Viewport::KeyMap.new
        @width = 0
        @height = 0
        @y_offset = 0

        set_styles(Tree.default_dark_styles)
        set_size(width, height)
        set_y_offsets
        update_styles
        update_viewport(0)
      end

      # Update is the Bubble Tea update loop.
      # Ported from Go: vendor/bubbles/tree/tree.go:159
      def update(msg : Tea::Msg) : {Model, Tea::Cmd?} # ameba:disable Metrics/CyclomaticComplexity
        if msg.is_a?(Tea::KeyPressMsg)
          case
          when Bubbles::Key.matches?(msg, @key_map.down)
            down
          when Bubbles::Key.matches?(msg, @key_map.up)
            up
          when Bubbles::Key.matches?(msg, @key_map.page_down)
            page_down
          when Bubbles::Key.matches?(msg, @key_map.page_up)
            page_up
          when Bubbles::Key.matches?(msg, @key_map.half_page_down)
            half_page_down
          when Bubbles::Key.matches?(msg, @key_map.half_page_up)
            half_page_up
          when Bubbles::Key.matches?(msg, @key_map.go_to_top)
            go_to_top
          when Bubbles::Key.matches?(msg, @key_map.go_to_bottom)
            go_to_bottom
          when Bubbles::Key.matches?(msg, @key_map.toggle)
            toggle_current_node
          when Bubbles::Key.matches?(msg, @key_map.open)
            open_current_node
          when Bubbles::Key.matches?(msg, @key_map.close)
            close_current_node
          when Bubbles::Key.matches?(msg, @key_map.show_full_help)
            @help.show_all = !@help.show_all
          when Bubbles::Key.matches?(msg, @key_map.close_full_help)
            @help.show_all = !@help.show_all
          end
        end

        {self, nil}
      end

      # View renders the component.
      # Ported from Go: vendor/bubbles/tree/tree.go:202
      def view : String
        sections = [@viewport.view]
        sections << help_view if @show_help
        Lipgloss.join_vertical(Lipgloss::Position::Left, sections)
      end

      # SetScrollOff sets the minimal number of lines above/below the selection.
      def set_scroll_off(value : Int32) : Nil # ameba:disable Naming/AccessorMethodName
        @scroll_off = value
      end

      def set_open_character(character : String) : Nil # ameba:disable Naming/AccessorMethodName
        @open_character = character
      end

      def set_closed_character(character : String) : Nil # ameba:disable Naming/AccessorMethodName
        @closed_character = character
      end

      def set_cursor_character(character : String) : Nil # ameba:disable Naming/AccessorMethodName
        @cursor_character = character
      end

      # SetNodes sets the tree to the given root node.
      # Ported from Go: vendor/bubbles/tree/tree.go:239
      def set_nodes(tree : Node?) : Nil # ameba:disable Naming/AccessorMethodName
        tree ||= Node.new
        @root = tree
        @root.given_value = tree.given_value

        if enumerator = @enumerator
          @root.enumerator(enumerator)
        end
        if indenter = @indenter
          @root.indenter(indenter)
        end

        set_y_offsets
        update_styles
        set_root_styles
        update_viewport(0)
      end

      def set_additional_full_help_keys(val : Proc(Array(Array(Bubbles::Key::Binding)))?) : Nil # ameba:disable Naming/AccessorMethodName
        @additional_full_help_keys = val
      end

      def set_additional_short_help_keys(val : Proc(Array(Bubbles::Key::Binding))?) : Nil # ameba:disable Naming/AccessorMethodName
        @additional_short_help_keys = val
      end

      def down : Nil
        update_viewport(1)
      end

      def up : Nil
        update_viewport(-1)
      end

      def page_down : Nil
        update_viewport(@viewport.height)
      end

      def page_up : Nil
        update_viewport(-@viewport.height)
      end

      def half_page_down : Nil
        update_viewport(@viewport.height // 2)
      end

      def half_page_up : Nil
        update_viewport(-(@viewport.height // 2))
      end

      def go_to_top : Nil
        update_viewport(-@y_offset)
      end

      def go_to_bottom : Nil
        update_viewport(@root.size)
      end

      def toggle_current_node : Nil
        node = find_node(@root, @y_offset)
        return unless node

        toggle_node(node, !node.is_open?)
      end

      def open_current_node : Nil
        node = find_node(@root, @y_offset)
        return unless node

        toggle_node(node, true)
      end

      def close_current_node : Nil
        node = find_node(@root, @y_offset)
        return unless node

        toggle_node(node, false)
      end

      private def toggle_node(node : Node, open : Bool) : Nil
        node.open = open

        node.tree.offset(0, 0)
        node.tree.offset(node.tree.children.length, 0) unless open
        set_y_offsets
        update_viewport(0)
      end

      private def update_viewport(movement : Int32) : Nil
        @y_offset = Math.max(Math.min(@root.size - 1, @y_offset + movement), 0)
        update_styles

        cursor = cursor_view
        tree_view = @styles.tree_style
          .width(@width)
          .max_width(@width)
          .render(@root.to_s)
        @viewport.set_content(
          Lipgloss::Style.join_horizontal(Lipgloss::Position::Top, cursor, tree_view)
        )

        # If this is the initial render, make sure we show the root node.
        return if @y_offset == 0 && movement == 0

        selected = find_node(@root, @y_offset)
        return unless selected

        line_offset = selected.line_offset
        height = @viewport.visible_line_count
        scrolloff = Math.min(@scroll_off, height // 2)
        min_top = Math.max(line_offset - scrolloff, 0)
        min_bottom = Math.min(@viewport.total_line_count - 1, line_offset + scrolloff)

        if @viewport.y_offset > min_top
          @viewport.set_y_offset(min_top)
        elsif @viewport.y_offset + height < min_bottom + 1
          @viewport.set_y_offset(min_bottom - height + 1)
        end
      end

      # SetStyles sets the styles for this component.
      # Ported from Go: vendor/bubbles/tree/tree.go:375
      def set_styles(styles : Styles) : Nil # ameba:disable Naming/AccessorMethodName
        if f = styles.node_style_func
          styles.node_func = f
        else
          styles.node_func = ->(_nodes : Array(Node), _i : Int32) { styles.node_style }
        end

        if f = styles.selected_node_style_func
          styles.selected_node_func = f
        else
          styles.selected_node_func = ->(_nodes : Array(Node), _i : Int32) { styles.selected_node_style }
        end

        if f = styles.parent_node_style_func
          styles.parent_node_func = f
        else
          styles.parent_node_func = ->(_nodes : Array(Node), _i : Int32) { styles.parent_node_style }
        end

        if f = styles.root_node_style_func
          styles.root_node_func = f
        else
          styles.root_node_func = ->(_nodes : Array(Node), _i : Int32) { styles.root_node_style }
        end

        if f = styles.enumerator_style_func
          styles.enumerator_func = f
        else
          styles.enumerator_func = ->(_nodes : Array(Node), _i : Int32) { styles.enumerator_style }
        end

        if f = styles.selected_enumerator_style_func
          styles.selected_enumerator_func = f
        else
          styles.selected_enumerator_func = ->(_nodes : Array(Node), _i : Int32) { styles.selected_enumerator_style }
        end

        if f = styles.indenter_style_func
          styles.indenter_func = f
        else
          styles.indenter_func = ->(_nodes : Array(Node), _i : Int32) { styles.indenter_style }
        end

        @styles = styles
        set_root_styles
        set_size(@width, @height)
        update_viewport(0)
      end

      private def set_root_styles : Nil
        @root.enumerator_style_func(->(children : Array(Node), i : Int32) {
          children[i].get_enumerator_style
        })
        @root.indenter_style_func(->(children : Array(Node), i : Int32) {
          children[i].get_indenter_style
        })
        @root.item_style_func(->(children : Array(Node), i : Int32) {
          children[i].get_style
        })
      end

      def set_show_help(value : Bool) : Nil # ameba:disable Naming/AccessorMethodName
        @show_help = value
        set_size(@width, @height)
      end

      def set_width(width : Int32) : Nil # ameba:disable Naming/AccessorMethodName
        set_size(width, @height)
      end

      def set_height(height : Int32) : Nil # ameba:disable Naming/AccessorMethodName
        set_size(@width, height)
      end

      # SetSize sets the width and height of this component.
      # Ported from Go: vendor/bubbles/tree/tree.go:478
      def set_size(width : Int32, height : Int32) : Nil
        @width = width
        @height = height

        @root.tree.width(
          width - Lipgloss.width(cursor_view) - @styles.tree_style.get_horizontal_frame_size
        )

        @viewport.set_width(width)
        help_height = @show_help ? Lipgloss.height(help_view) : 0
        @viewport.set_height(height - help_height)
        @help.set_width(width)
      end

      # ShortHelp returns bindings to show in the abbreviated help view.
      def short_help : Array(Bubbles::Key::Binding)
        bindings = [@key_map.down, @key_map.up, @key_map.toggle]

        if f = @additional_short_help_keys
          bindings.concat(f.call)
        end

        bindings << @key_map.show_full_help
        bindings
      end

      # FullHelp returns bindings to show in the full help view.
      def full_help : Array(Array(Bubbles::Key::Binding))
        bindings = [
          [@key_map.down, @key_map.up, @key_map.open, @key_map.close, @key_map.toggle],
          [@key_map.page_down, @key_map.page_up, @key_map.half_page_down, @key_map.half_page_up],
          [@key_map.go_to_top, @key_map.go_to_bottom],
        ]

        if f = @additional_full_help_keys
          bindings.concat(f.call)
        end

        bindings << [@key_map.close_full_help]
        bindings
      end

      private def cursor_view : String
        return "" if @cursor_character.empty?

        cursor = Array(String).new(@root.height, " ")
        if node = find_node(@root, @y_offset)
          cursor[node.line_offset] = @cursor_character if node.line_offset < cursor.size
        end
        @styles.cursor_style.render(
          Lipgloss::Style.join_vertical(Lipgloss::Position::Left, cursor)
        )
      end

      private def help_view : String
        @styles.help_style.render(@help.view(self))
      end

      def all_nodes : Array(Node)
        @root.all_nodes
      end

      private def set_y_offsets : Nil
        set_y_offsets(@root)
      end

      # Updates each Node's yOffset and lineOffset based on the nodes above it.
      # Ported from Go: vendor/bubbles/tree/tree.go:639
      private def set_y_offsets(tree : Node) : Nil
        children = tree.tree.children
        above = 0
        lines_above = 0

        children.length.times do |i|
          child = children.at(i)
          next unless child.is_a?(Node)

          child.y_offset = tree.y_offset + above + i + 1
          child.line_offset = tree.line_offset + lines_above + i + 1
          set_y_offsets(child)
          above += child.size - 1
          lines_above += child.height - 1
        end
      end

      def viewport_y_offset : Int32
        @viewport.y_offset
      end

      def set_viewport_y_offset(yoffset : Int32) : Nil # ameba:disable Naming/AccessorMethodName
        @viewport.set_y_offset(yoffset)
      end

      def set_y_offset(yoffset : Int32) : Nil # ameba:disable Naming/AccessorMethodName
        movement = yoffset - @y_offset
        update_viewport(movement)
      end

      # Node returns the item at the given yoffset.
      def node(yoffset : Int32) : Node?
        find_node(@root, yoffset)
      end

      def node_at_current_offset : Node?
        find_node(@root, @y_offset)
      end

      def enumerator(enumerator : Lipgloss::Tree::Enumerator) : Model
        @enumerator = enumerator
        @root.enumerator(enumerator)
        self
      end

      def indenter(indenter : Lipgloss::Tree::Indenter) : Model
        @indenter = indenter
        @root.indenter(indenter)
        self
      end

      # update_styles refreshes the selected node styles and the rendered root.
      # Ported from Go: vendor/bubbles/tree/tree.go:699
      private def update_styles : Nil
        opts = get_item_opts
        @root.opts = opts
        root_style_value = root_style
        @root.root_style(root_style_value)

        raw = @root.given_value
        display = raw.is_a?(String) ? Ansi.strip(raw) : raw.to_s
        root_line = root_style_value.render(display)
        root_line = Lipgloss::Style.join_horizontal(
          Lipgloss::Position::Left,
          @root.indicator,
          root_line
        )
        @root.tree.set_value(root_line)

        all_nodes.each(&.opts=(opts))
      end

      private def get_item_opts : ItemOptions
        ItemOptions.new(
          open_character: @open_character,
          closed_character: @closed_character,
          tree_y_offset: @y_offset,
          styles: @styles
        )
      end

      private def root_style : Lipgloss::Style
        f = @styles.root_node_func
        return Lipgloss::Style.new unless f

        nodes = [@root]
        if @root.y_offset == @y_offset && (selected = @styles.selected_node_func)
          return f.call(nodes, 0).inherit(selected.call(nodes, 0))
        end

        f.call(nodes, 0)
      end

      # find_node starts a DFS search for the node with the given yOffset.
      private def find_node(tree : Node, yoffset : Int32) : Node?
        return tree if tree.y_offset == yoffset

        children = tree.tree.children
        children.length.times do |i|
          child = children.at(i)
          next unless child.is_a?(Node)

          found = find_node(child, yoffset)
          return found if found
        end

        nil
      end
    end

    def self.new(root : Node?, width : Int32, height : Int32) : Model
      Model.new(root, width, height)
    end
  end
end
