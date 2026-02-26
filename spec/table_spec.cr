require "./spec_helper"
require "../src/bubbles/table"

describe Bubbles::Table do
  ansi_strip = ->(s : String) { Ansi.strip(s.gsub("\r\n", "\n")) }
  require_table_golden = ->(dir : String, file : String, got : String) do
    golden_path = File.expand_path("../vendor/bubbles/table/testdata/#{dir}/#{file}.golden", __DIR__)
    File.read(golden_path).should eq(got)
  end

  test_cols = [
    Bubbles::Table::Column.new("col1", 10),
    Bubbles::Table::Column.new("col2", 10),
    Bubbles::Table::Column.new("col3", 10),
  ]

  it "TestNew" do
    model = Bubbles::Table.new
    model.cursor.should eq(0)
    model.viewport_height.should eq(20)

    model = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("Foo", 1), Bubbles::Table::Column.new("Bar", 2)]),
      Bubbles::Table.with_rows([["1", "Foo"], ["2", "Bar"]]),
      Bubbles::Table.with_height(10),
      Bubbles::Table.with_width(10),
      Bubbles::Table.with_focused(true)
    )
    model.columns.size.should eq(2)
    model.rows.size.should eq(2)
    model.viewport_height.should eq(9)
    model.viewport_width.should eq(10)
    model.focused?.should be_true
  end

  it "TestModel_FromValues" do
    input = "foo1,bar1\nfoo2,bar2\nfoo3,bar3"
    table = Bubbles::Table.new(Bubbles::Table.with_columns([Bubbles::Table::Column.new("Foo"), Bubbles::Table::Column.new("Bar")]))
    table.from_values(input, ",")

    table.rows.size.should eq(3)
    table.rows.should eq([["foo1", "bar1"], ["foo2", "bar2"], ["foo3", "bar3"]])
  end

  it "TestModel_FromValues_WithTabSeparator" do
    input = "foo1.\tbar1\nfoo,bar,baz\tbar,2"
    table = Bubbles::Table.new(Bubbles::Table.with_columns([Bubbles::Table::Column.new("Foo"), Bubbles::Table::Column.new("Bar")]))
    table.from_values(input, "\t")
    table.rows.should eq([["foo1.", "bar1"], ["foo,bar,baz", "bar,2"]])
  end

  it "TestModel_RenderRow" do
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns(test_cols),
      Bubbles::Table.with_rows([["Foooooo", "Baaaaar", "Baaaaaz"]])
    )
    row = table.render_row(0)
    row.should contain("Foooooo")
    row.should contain("Baaaaar")
    row.should contain("Baaaaaz")
  end

  it "TestCursorNavigation" do
    rows = Array.new(5) { |i| ["row#{i}"] }
    table = Bubbles::Table.new(
      Bubbles::Table.with_rows(rows),
      Bubbles::Table.with_focused(true)
    )

    table.update(Tea::KeyPressMsg.new("down"))
    table.cursor.should eq(1)
    table.update(Tea::KeyPressMsg.new("up"))
    table.cursor.should eq(0)
    table.goto_bottom
    table.cursor.should eq(4)
    table.goto_top
    table.cursor.should eq(0)
  end

  it "TestModel_SetRows" do
    table = Bubbles::Table.new(Bubbles::Table.with_columns(test_cols))
    table.rows.size.should eq(0)
    table.set_rows([["r1"], ["r2"]])
    table.rows.should eq([["r1"], ["r2"]])
  end

  it "TestModel_SetColumns" do
    table = Bubbles::Table.new
    table.columns.size.should eq(0)
    table.set_columns([Bubbles::Table::Column.new("Foo"), Bubbles::Table::Column.new("Bar")])
    table.columns.should eq([Bubbles::Table::Column.new("Foo"), Bubbles::Table::Column.new("Bar")])
  end

  it "TestModel_RenderRow_AnsiWidth" do
    value = "\e[31mABCDEFGH\e[0m"
    styles = Bubbles::Table.default_styles
    styles.cell = Lipgloss::Style.new
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("col1", 8)]),
      Bubbles::Table.with_rows([[value]]),
      Bubbles::Table.with_styles(styles)
    )
    ansi_strip.call(table.render_row(0)).should eq("ABCDEFGH")
  end

  it "TestTableAlignment_No_border" do
    biscuits = Bubbles::Table.new(
      Bubbles::Table.with_width(59),
      Bubbles::Table.with_height(5),
      Bubbles::Table.with_columns([
        Bubbles::Table::Column.new("Name", 25),
        Bubbles::Table::Column.new("Country of Origin", 16),
        Bubbles::Table::Column.new("Dunk-able", 12),
      ]),
      Bubbles::Table.with_rows([
        ["Chocolate Digestives", "UK", "Yes"],
        ["Tim Tams", "Australia", "No"],
        ["Hobnobs", "UK", "Yes"],
      ])
    )
    require_table_golden.call("TestTableAlignment", "No_border", ansi_strip.call(biscuits.view))
  end

  it "TestTableAlignment" do
    base_style = Lipgloss.new_style
      .border_style(Lipgloss.normal_border)
      .border_foreground(Lipgloss.color("240"))

    s = Bubbles::Table.default_styles
    s.header = s.header
      .border_style(Lipgloss.normal_border)
      .border_foreground(Lipgloss.color("240"))
      .border_bottom(true)
      .bold(false)

    biscuits = Bubbles::Table.new(
      Bubbles::Table.with_width(59),
      Bubbles::Table.with_height(5),
      Bubbles::Table.with_columns([
        Bubbles::Table::Column.new("Name", 25),
        Bubbles::Table::Column.new("Country of Origin", 16),
        Bubbles::Table::Column.new("Dunk-able", 12),
      ]),
      Bubbles::Table.with_rows([
        ["Chocolate Digestives", "UK", "Yes"],
        ["Tim Tams", "Australia", "No"],
        ["Hobnobs", "UK", "Yes"],
      ]),
      Bubbles::Table.with_styles(s)
    )
    got = ansi_strip.call(base_style.render(biscuits.view))
    require_table_golden.call("TestTableAlignment", "With_border", got)
  end

  it "TestModel_View" do
    tests = {
      "Empty" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(60),
          Bubbles::Table.with_height(21)
        )
      },
      "Single_row_and_column" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(27),
          Bubbles::Table.with_height(21),
          Bubbles::Table.with_columns([Bubbles::Table::Column.new("Name", 25)]),
          Bubbles::Table.with_rows([["Chocolate Digestives"]])
        )
      },
      "Multiple_rows_and_columns" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(21),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ])
        )
      },
      "Extra_padding" => -> {
        s = Bubbles::Table.default_styles
        s.header = Lipgloss.new_style.padding(2, 2)
        s.cell = Lipgloss.new_style.padding(2, 2)
        Bubbles::Table.new(
          Bubbles::Table.with_width(60),
          Bubbles::Table.with_height(10),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ]),
          Bubbles::Table.with_styles(s)
        )
      },
      "No_padding" => -> {
        s = Bubbles::Table.default_styles
        s.header = Lipgloss::Style.new
        s.cell = Lipgloss::Style.new
        Bubbles::Table.new(
          Bubbles::Table.with_width(53),
          Bubbles::Table.with_height(10),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ]),
          Bubbles::Table.with_styles(s)
        )
      },
      "Bordered_headers" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(23),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ]),
          Bubbles::Table.with_styles(Bubbles::Table::Styles.new(
            header: Lipgloss.new_style.border_style(Lipgloss.normal_border)
          ))
        )
      },
      "Bordered_cells" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(21),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ]),
          Bubbles::Table.with_styles(Bubbles::Table::Styles.new(
            cell: Lipgloss.new_style.border_style(Lipgloss.normal_border)
          ))
        )
      },
      "Height_greater_than_rows" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(6),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ])
        )
      },
      "Height_less_than_rows" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(2),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ])
        )
      },
      "Width_greater_than_columns" => -> {
        Bubbles::Table.new(
          Bubbles::Table.with_width(80),
          Bubbles::Table.with_height(21),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ])
        )
      },
      "Modified_viewport_height" => -> {
        m = Bubbles::Table.new(
          Bubbles::Table.with_width(59),
          Bubbles::Table.with_height(15),
          Bubbles::Table.with_columns([
            Bubbles::Table::Column.new("Name", 25),
            Bubbles::Table::Column.new("Country of Origin", 16),
            Bubbles::Table::Column.new("Dunk-able", 12),
          ]),
          Bubbles::Table.with_rows([
            ["Chocolate Digestives", "UK", "Yes"],
            ["Tim Tams", "Australia", "No"],
            ["Hobnobs", "UK", "Yes"],
          ])
        )
        m.viewport.set_height(2)
        m
      },
    }

    tests.each do |name, build_model|
      table = build_model.call
      got = ansi_strip.call(table.view)
      require_table_golden.call("TestModel_View", name, got)
    end
  end

  pending "TestModel_View_Width_less_than_columns" do
    # Upstream Go test currently skips this case.
  end

  pending "TestModel_View_CenteredInABox" do
    # Upstream Go test is skipped.
  end
end
