require "../spec_helper"
require "../../src/bubbles/internal/runeutil"

describe Bubbles::Internal::Runeutil do
  it "TestSanitize" do
    td = [
      {"", "", nil},
      {"x", "x", nil},
      {"\n", "XX", nil},
      {"\na\n", "XXaXX", nil},
      {"\n\n", "XXXX", nil},
      {"\t", "", nil},
      {"hello", "hello", nil},
      {"hel\nlo", "helXXlo", nil},
      {"hel\rlo", "helXXlo", nil},
      {"hel\tlo", "hello", nil},
      {"he\n\nl\tlo", "heXXXXllo", nil},
      {"he\tl\n\nlo", "helXXXXlo", nil},
      {"hel\x1blo", "hello", nil},
      {"", "hello", ['h', 'e', 'l', 'l', 'o', '\uFFFD']},
    ]

    td.each do |tc|
      input = tc[0]
      expected = tc[1]
      explicit_runes = tc[2]

      runes = explicit_runes || input.chars
      s = Bubbles::Internal::Runeutil.new_sanitizer(
        Bubbles::Internal::Runeutil.replace_newlines("XX"),
        Bubbles::Internal::Runeutil.replace_tabs("")
      )
      result = s.sanitize(runes)
      result.join.should eq(expected), "input=#{input.inspect} runes=#{runes}"
    end
  end
end
