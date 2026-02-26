# Key provides types and functions for generating user-definable key mappings
# useful in Bubble Tea components.
module Bubbles
  module Key
    # Binding describes a set of keybindings and, optionally, their associated help text.
    class Binding
      property keys : Array(String)?
      property help : Help
      property? disabled : Bool

      def initialize(@keys = nil, @help = Help.new, @disabled = false)
      end

      # SetKeys sets the keys for the keybinding.
      def set_keys(*keys : String) # ameba:disable Naming/AccessorMethodName
        @keys = keys.to_a
      end

      def keys=(keys : Array(String))
        set_keys(*keys)
      end

      # Keys returns the keys for the keybinding.
      def keys : Array(String)?
        @keys
      end

      # SetHelp sets the help text for the keybinding.
      def set_help(key : String, desc : String)
        @help = Help.new(key, desc)
      end

      # Help returns the Help information for the keybinding.
      def help : Help
        @help
      end

      # Enabled returns whether or not the keybinding is enabled. Disabled
      # keybindings won't be activated and won't show up in help. Keybindings are
      # enabled by default.
      def enabled? : Bool
        !@disabled && !@keys.nil?
      end

      # Enabled returns whether or not the keybinding is enabled.
      # Kept for Go parity with key.Binding.Enabled.
      def enabled : Bool
        enabled?
      end

      # SetEnabled enables or disables the keybinding.
      def set_enabled(v : Bool) # ameba:disable Naming/AccessorMethodName
        @disabled = !v
      end

      def enabled=(v : Bool)
        set_enabled(v)
      end

      # Unbind removes the keys and help from this binding, effectively nullifying
      # it. This is a step beyond disabling it, since applications can enable
      # or disable key bindings based on application state.
      def unbind
        @keys = nil
        @help = Help.new
      end
    end

    # Help is help information for a given keybinding.
    struct Help
      getter key : String
      getter desc : String

      def initialize(@key : String = "", @desc : String = "")
      end
    end

    # BindingOpt is an initialization option for a keybinding. It's used as an
    # argument to NewBinding.
    alias BindingOpt = Proc(Binding, Nil)

    # NewBinding returns a new keybinding from a set of BindingOpt options.
    def self.new_binding(*opts : BindingOpt) : Binding
      binding = Binding.new
      opts.each do |opt|
        opt.call(binding)
      end
      binding
    end

    # WithKeys initializes a keybinding with the given keystrokes.
    def self.with_keys(*keys : String) : BindingOpt
      ->(b : Binding) { b.keys = keys.to_a }
    end

    # WithHelp initializes a keybinding with the given help text.
    def self.with_help(key : String, desc : String) : BindingOpt
      ->(b : Binding) { b.set_help(key, desc) }
    end

    # WithDisabled initializes a disabled keybinding.
    def self.with_disabled : BindingOpt
      ->(b : Binding) { b.disabled = true }
    end

    # Matches checks if the given key matches the given bindings.
    def self.matches?(k : T, *bindings : Binding) : Bool forall T
      key_str = k.to_s
      bindings.each do |binding|
        next unless binding.enabled?
        keys = binding.keys
        next unless keys
        keys.each do |binding_key|
          return true if key_str == binding_key
        end
      end
      false
    end
  end
end
