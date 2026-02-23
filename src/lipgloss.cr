module Lipgloss
  # Style represents a terminal style with various formatting options.
  struct Style
    # ameba:disable Naming/QueryBoolMethods
    property inline : Bool = false
    # ameba:disable Naming/QueryBoolMethods
    property reverse : Bool = false

    # Returns a new style with the inline property set.
    def inline(value : Bool) : Style
      style = dup
      style.inline = value
      style
    end

    # Returns a new style with the reverse property set.
    def reverse(value : Bool) : Style
      style = dup
      style.reverse = value
      style
    end

    # Renders the given text with the current style.
    # For now, returns the text unchanged.
    def render(text : String) : String
      text
    end
  end
end
