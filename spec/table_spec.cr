require "./spec_helper"

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

  describe "TestNew" do
    it "Default" do
      model = Bubbles::Table.new
      model.cursor.should eq(0)
      model.viewport_height.should eq(20)
      model.viewport_width.should eq(0)
      model.focused?.should be_false
      model.columns.size.should eq(0)
      model.rows.size.should eq(0)
    end

    it "WithColumns" do
      model = Bubbles::Table.new(
        Bubbles::Table.with_columns([Bubbles::Table::Column.new("Foo", 1), Bubbles::Table::Column.new("Bar", 2)]),
      )
      model.columns.size.should eq(2)
      model.viewport_height.should eq(20)
    end

    it "WithColumns; WithRows" do
      model = Bubbles::Table.new(
        Bubbles::Table.with_columns([Bubbles::Table::Column.new("Foo", 1), Bubbles::Table::Column.new("Bar", 2)]),
        Bubbles::Table.with_rows([["1", "Foo"], ["2", "Bar"]]),
      )
      model.columns.size.should eq(2)
      model.rows.size.should eq(2)
    end

    it "WithHeight" do
      model = Bubbles::Table.new(Bubbles::Table.with_height(10))
      model.viewport_height.should eq(9)
    end

    it "WithWidth" do
      model = Bubbles::Table.new(Bubbles::Table.with_width(10))
      model.viewport_width.should eq(10)
    end

    it "WithFocused" do
      model = Bubbles::Table.new(Bubbles::Table.with_focused(true))
      model.focused?.should be_true
    end

    it "WithStyles" do
      s = Bubbles::Table::Styles.new
      model = Bubbles::Table.new(Bubbles::Table.with_styles(s))
      model.styles.should eq(s)
    end

    it "WithKeyMap" do
      km = Bubbles::Table::KeyMap.new
      model = Bubbles::Table.new(Bubbles::Table.with_key_map(km))
      model.key_map.should eq(km)
    end
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

  describe "TestModel_RenderRow" do
    it "simple row" do
      styles = Bubbles::Table::Styles.new(cell: Lipgloss::Style.new)
      table = Bubbles::Table.new(
        Bubbles::Table.with_columns(test_cols),
        Bubbles::Table.with_rows([["Foooooo", "Baaaaar", "Baaaaaz"]]),
        Bubbles::Table.with_styles(styles)
      )
      ansi_strip.call(table.render_row(0)).should eq("Foooooo   Baaaaar   Baaaaaz   ")
    end

    it "simple row with truncations" do
      styles = Bubbles::Table::Styles.new(cell: Lipgloss::Style.new)
      table = Bubbles::Table.new(
        Bubbles::Table.with_columns(test_cols),
        Bubbles::Table.with_rows([["Foooooooooo", "Baaaaaaaaar", "Quuuuuuuuux"]]),
        Bubbles::Table.with_styles(styles)
      )
      ansi_strip.call(table.render_row(0)).should eq("Foooooooo…Baaaaaaaa…Quuuuuuuu…")
    end

    it "simple row avoiding truncations" do
      styles = Bubbles::Table::Styles.new(cell: Lipgloss::Style.new)
      table = Bubbles::Table.new(
        Bubbles::Table.with_columns(test_cols),
        Bubbles::Table.with_rows([["Fooooooooo", "Baaaaaaaar", "Quuuuuuuux"]]),
        Bubbles::Table.with_styles(styles)
      )
      ansi_strip.call(table.render_row(0)).should eq("FoooooooooBaaaaaaaarQuuuuuuuux")
    end
  end

  it "TestCursorNavigation" do
    tests = {
      "New" => {
        rows:   [["r1"], ["r2"], ["r3"]],
        action: ->(t : Bubbles::Table::Model) { },
        want:   0,
      },
      "MoveDown" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.move_down(2) },
        want:   2,
      },
      "MoveUp" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.cursor = 3; t.move_up(2) },
        want:   1,
      },
      "GotoBottom" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.goto_bottom },
        want:   3,
      },
      "GotoTop" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.cursor = 3; t.goto_top },
        want:   0,
      },
      "SetCursor" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.set_cursor(2) },
        want:   2,
      },
      "MoveDown with overflow" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.move_down(5) },
        want:   3,
      },
      "MoveUp with overflow" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.cursor = 3; t.move_up(5) },
        want:   0,
      },
      "Blur does not stop movement" => {
        rows:   [["r1"], ["r2"], ["r3"], ["r4"]],
        action: ->(t : Bubbles::Table::Model) { t.blur; t.move_down(2) },
        want:   2,
      },
    }

    tests.each do |name, test|
      table = Bubbles::Table.new(
        Bubbles::Table.with_columns(test_cols),
        Bubbles::Table.with_rows(test[:rows])
      )
      test[:action].call(table)
      table.cursor.should eq(test[:want]), "Failed test case: #{name}"
    end
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

  # Go: TestSetRows_CursorClampsOnShrink
  it "clamps the cursor when rows shrink" do
    tbl = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("Name", 10)]),
      Bubbles::Table.with_rows([["a"], ["b"], ["c"]]),
      Bubbles::Table.with_height(5)
    )
    tbl.goto_bottom
    tbl.set_rows([["x"]])
    tbl.cursor.should eq(0)
  end

  # Go: TestSetRows_CursorClampsToZeroOnEmpty
  it "keeps the cursor non-negative on an empty table" do
    tbl = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("Name", 10)]),
      Bubbles::Table.with_rows([["a"], ["b"], ["c"]]),
      Bubbles::Table.with_height(5)
    )
    tbl.goto_bottom
    tbl.cursor.should eq(2)
    tbl.set_rows([] of Bubbles::Table::Row)
    tbl.cursor.should be >= 0
  end

  # Go: TestModel_FromValues_MoreValuesThanColumns
  it "accepts more values than columns" do
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([
        Bubbles::Table::Column.new("Foo", 5),
        Bubbles::Table::Column.new("Bar", 5),
      ])
    )
    table.from_values("foo1,bar1\nfoo2,bar2,baz2", ",")
    table.rows.size.should eq(2)
  end

  # Go: TestModel_RenderRow_MoreCellsThanColumns
  it "renders only as many cells as there are columns" do
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([
        Bubbles::Table::Column.new("col1", 10),
        Bubbles::Table::Column.new("col2", 10),
        Bubbles::Table::Column.new("col3", 10),
      ]),
      Bubbles::Table.with_rows([["Foooooo", "Baaaaar", "Baaaaaz", "Quuuuux"]])
    )
    styles = table.styles
    styles.cell = Lipgloss::Style.new
    styles.selected = Lipgloss::Style.new
    table.styles = styles
    table.render_row(0).should eq("Foooooo   Baaaaar   Baaaaaz   ")
  end

  # Go: TestModel_SetRows_NoColumns
  it "accepts rows without columns" do
    table = Bubbles::Table.new
    table.set_rows([["one"]])
    table.rows.size.should eq(1)
  end

  # Go: TestNew_RowsWithoutColumns
  it "constructs with rows and no columns" do
    table = Bubbles::Table.new(Bubbles::Table.with_rows([["one"]]))
    table.rows.size.should eq(1)
  end

  # Go: TestRenderRowConfiguredColumns
  it "renders a row with configured columns" do
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([
        Bubbles::Table::Column.new("col1", 10),
        Bubbles::Table::Column.new("col2", 10),
        Bubbles::Table::Column.new("col3", 10),
      ]),
      Bubbles::Table.with_rows([["Foooooo", "Baaaaar", "Baaaaaz"]])
    )
    styles = table.styles
    styles.cell = Lipgloss::Style.new
    styles.selected = Lipgloss::Style.new
    table.styles = styles
    table.render_row(0).should eq("Foooooo   Baaaaar   Baaaaaz   ")
  end

  # Go: TestRenderRowDoesNotDiscardExtraData
  it "does not discard extra row data while rendering" do
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("one", 5)]),
      Bubbles::Table.with_rows([["one", "extra"]])
    )
    table.view
    table.rows[0].size.should eq(2)
    table.rows[0][1].should eq("extra")
  end

  # Go: TestSetCursor_TabJumpVisible
  it "keeps a jumped-to cursor visible" do
    rows = (0...30).map { |i| ["item-#{i}"] }
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("Item", 10)]),
      Bubbles::Table.with_rows(rows),
      Bubbles::Table.with_width(20),
      Bubbles::Table.with_height(11)
    )
    table.set_cursor(table.cursor + 9)
    Ansi.strip(table.view).should contain("item-9")
    table.set_cursor(table.cursor + 9)
    Ansi.strip(table.view).should contain("item-18")
  end

  # Go: TestSetCursor_ViewportVisibility
  it "keeps every cursor target inside the viewport" do
    rows = (0...30).map { |i| ["r%02d" % i] }
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("Col", 10)]),
      Bubbles::Table.with_rows(rows),
      Bubbles::Table.with_width(20),
      Bubbles::Table.with_height(6)
    )
    table.viewport.height.should eq(5)

    {3 => 3, 5 => 5, 10 => 10, 28 => 28, 29 => 29, 0 => 0, 15 => 15, 100 => 29, -5 => 0}.each do |cursor, want|
      table.set_cursor(cursor)
      table.cursor.should eq(want)
      cursor_idx = table.cursor - table.start
      offset = table.viewport.y_offset
      cursor_idx.should be >= offset
      cursor_idx.should be < offset + table.viewport.height
      Ansi.strip(table.view).should contain(rows[want][0])
    end
  end

  # Go: TestMoveUpFromBottomKeepsViewport
  it "keeps the viewport steady when moving up from the bottom" do
    rows = (0...30).map { |i| ["r%02d" % i] }
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("c", 4)]),
      Bubbles::Table.with_rows(rows),
      Bubbles::Table.with_width(10),
      Bubbles::Table.with_height(6)
    )
    table.goto_bottom
    before = Ansi.strip(table.view).lines[1]
    table.move_up(1)
    after = Ansi.strip(table.view).lines[1]
    table.cursor.should eq(28)
    after.should eq(before)
  end

  # Go: TestMoveDownAfterUpsKeepsViewport
  it "keeps the viewport steady when moving down after moving up" do
    rows = (0...30).map { |i| ["r%02d" % i] }
    table = Bubbles::Table.new(
      Bubbles::Table.with_columns([Bubbles::Table::Column.new("c", 4)]),
      Bubbles::Table.with_rows(rows),
      Bubbles::Table.with_width(10),
      Bubbles::Table.with_height(6)
    )
    table.goto_bottom
    before = Ansi.strip(table.view).lines[1]
    table.move_up(1)
    table.move_up(1)
    table.move_down(1)
    after = Ansi.strip(table.view).lines[1]
    table.cursor.should eq(28)
    after.should eq(before)
  end
end
