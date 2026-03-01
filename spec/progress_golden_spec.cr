require "./spec_helper"
require "../src/bubbles/progress"
require "golden"

describe Bubbles::Progress do
  describe "TestBlend" do
    it "10w-red-to-green-50perc" do
      p = Bubbles::Progress.new(
        Bubbles::Progress.with_colors(Lipgloss.color("#FF0000"), Lipgloss.color("#00FF00")),
        Bubbles::Progress.with_scaled(false),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(10)
      )

      Golden.require_equal("10w-red-to-green-50perc", p.view_as(0.5), "spec/testdata/TestBlend")
    end

    it "10w-red-to-green-50perc-full-block" do
      p = Bubbles::Progress.new(
        Bubbles::Progress.with_colors(Lipgloss.color("#FF0000"), Lipgloss.color("#00FF00")),
        Bubbles::Progress.with_fill_characters('█', Bubbles::Progress::DefaultEmptyCharBlock),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(10)
      )

      Golden.require_equal("10w-red-to-green-50perc-full-block", p.view_as(0.5), "spec/testdata/TestBlend")
    end

    it "30w-red-to-green-100perc" do
      p = Bubbles::Progress.new(
        Bubbles::Progress.with_colors(Lipgloss.color("#FF0000"), Lipgloss.color("#00FF00")),
        Bubbles::Progress.with_scaled(false),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(30)
      )

      Golden.require_equal("30w-red-to-green-100perc", p.view_as(1.0), "spec/testdata/TestBlend")
    end

    it "10w-red-to-green-scaled-50perc" do
      p = Bubbles::Progress.new(
        Bubbles::Progress.with_colors(Lipgloss.color("#FF0000"), Lipgloss.color("#00FF00")),
        Bubbles::Progress.with_scaled(true),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(10)
      )

      Golden.require_equal("10w-red-to-green-scaled-50perc", p.view_as(0.5), "spec/testdata/TestBlend")
    end

    it "30w-red-to-green-scaled-100perc" do
      p = Bubbles::Progress.new(
        Bubbles::Progress.with_colors(Lipgloss.color("#FF0000"), Lipgloss.color("#00FF00")),
        Bubbles::Progress.with_scaled(true),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(30)
      )

      Golden.require_equal("30w-red-to-green-scaled-100perc", p.view_as(1.0), "spec/testdata/TestBlend")
    end

    it "30w-colorfunc-rgb-100perc" do
      color_func = ->(total : Float64, current : Float64) do
        if current <= 0.3
          Lipgloss.color("#FF0000")
        elsif current <= 0.7
          Lipgloss.color("#00FF00")
        else
          Lipgloss.color("#0000FF")
        end
      end

      p = Bubbles::Progress.new(
        Bubbles::Progress.with_color_func(color_func),
        Bubbles::Progress.without_percentage,
        Bubbles::Progress.with_width(30)
      )

      Golden.require_equal("30w-colorfunc-rgb-100perc", p.view_as(1.0), "spec/testdata/TestBlend")
    end
  end
end
