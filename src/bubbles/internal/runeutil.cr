module Bubbles
  module Internal
    module Runeutil
      alias Option = SanitizerConfig -> SanitizerConfig

      module Sanitizer
        abstract def sanitize(runes : Array(Char)) : Array(Char)
      end

      class SanitizerConfig
        property replace_new_line : Array(Char)
        property replace_tab : Array(Char)

        def initialize(
          @replace_new_line : Array(Char) = ['\n'],
          @replace_tab : Array(Char) = [' ', ' ', ' ', ' '],
        )
        end

        def clone_config : SanitizerConfig
          SanitizerConfig.new(@replace_new_line.dup, @replace_tab.dup)
        end
      end

      class DefaultSanitizer
        include Sanitizer

        def initialize(@cfg : SanitizerConfig)
        end

        def sanitize(runes : Array(Char)) : Array(Char)
          # NOTE: Crystal chars are valid codepoints; we treat replacement
          # rune U+FFFD as invalid input equivalent for Go parity.
          out = [] of Char
          runes.each do |rune|
            if rune == '\uFFFD'
              next
            end

            case rune
            when '\r', '\n'
              out.concat(@cfg.replace_new_line)
            when '\t'
              out.concat(@cfg.replace_tab)
            else
              out << rune unless rune.control?
            end
          end
          out
        end
      end

      # NewSanitizer constructs a rune sanitizer.
      def self.new_sanitizer(*opts : Option) : Sanitizer
        cfg = SanitizerConfig.new
        opts.each do |opt|
          cfg = opt.call(cfg.clone_config)
        end
        DefaultSanitizer.new(cfg)
      end

      # ReplaceTabs replaces tabs by the specified string.
      def self.replace_tabs(tab_repl : String) : Option
        ->(s : SanitizerConfig) do
          s.replace_tab = tab_repl.chars
          s
        end
      end

      # ReplaceNewlines replaces newline characters by the specified string.
      def self.replace_newlines(nl_repl : String) : Option
        ->(s : SanitizerConfig) do
          s.replace_new_line = nl_repl.chars
          s
        end
      end
    end
  end
end
