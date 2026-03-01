require "./spec_helper"
require "../src/bubbles/paginator"

describe Bubbles::Paginator do
  it "TestNew" do
    model = Bubbles::Paginator.new
    model.per_page.should eq(1)
    model.total_pages.should eq(1)

    per_page = 42
    total_pages = 42

    model = Bubbles::Paginator.new(
      Bubbles::Paginator.with_per_page(per_page),
      Bubbles::Paginator.with_total_pages(total_pages)
    )

    model.per_page.should eq(per_page)
    model.total_pages.should eq(total_pages)
  end

  it "TestSetTotalPages" do
    tests = [
      {"Less than one page", 5, 1, 5},
      {"Exactly one page", 10, 1, 10},
      {"More than one page", 15, 1, 15},
      {"negative value for page", -10, 1, 1},
    ]

    tests.each do |tt|
      model = Bubbles::Paginator.new
      if model.total_pages != tt[2]
        model.set_total_pages(tt[2])
      end
      model.set_total_pages(tt[1])
      model.total_pages.should eq(tt[3]), tt[0]
    end
  end

  it "TestPrevPage" do
    tests = [
      {"Go to previous page", 10, 1, 0},
      {"Stay on first page", 5, 0, 0},
    ]

    tests.each do |tt|
      model = Bubbles::Paginator.new
      model.set_total_pages(tt[1])
      model.page = tt[2]
      model, _ = model.update(Tea::Key.new(code: Tea::KeyLeft))
      model.page.should eq(tt[3]), tt[0]
    end
  end

  it "TestNextPage" do
    tests = [
      {"Go to next page", 2, 0, 1},
      {"Stay on last page", 2, 1, 1},
    ]

    tests.each do |tt|
      model = Bubbles::Paginator.new
      model.set_total_pages(tt[1])
      model.page = tt[2]
      model, _ = model.update(Tea::Key.new(code: Tea::KeyRight))
      model.page.should eq(tt[3]), tt[0]
    end
  end

  it "TestOnLastPage" do
    tests = [
      {"On last page", 1, 2, true},
      {"Not on last page", 0, 2, false},
    ]

    tests.each do |tt|
      model = Bubbles::Paginator.new
      model.set_total_pages(tt[2])
      model.page = tt[1]
      model.on_last_page?.should eq(tt[3]), tt[0]
    end
  end

  it "TestOnFirstPage" do
    tests = [
      {"On first page", 0, 2, true},
      {"Not on first page", 1, 2, false},
    ]

    tests.each do |tt|
      model = Bubbles::Paginator.new
      model.set_total_pages(tt[2])
      model.page = tt[1]
      model.on_first_page?.should eq(tt[3]), tt[0]
    end
  end

  it "TestItemsOnPage" do
    [{1, 10, 10, 1}, {3, 10, 10, 1}, {7, 10, 10, 1}].each do |tc|
      model = Bubbles::Paginator.new
      model.page = tc[0]
      model.set_total_pages(tc[1])
      model.items_on_page(tc[2]).should eq(tc[3])
    end
  end

  it "TestDupMethod" do
    # Create a paginator with custom settings
    model = Bubbles::Paginator.new(
      Bubbles::Paginator.with_per_page(5),
      Bubbles::Paginator.with_total_pages(20)
    )
    model.page = 3
    model.type = Bubbles::Paginator::Type::Dots
    model.active_dot = "X"
    model.inactive_dot = "o"
    model.arabic_format = "Page %d of %d"

    # Create a copy
    copy = model.dup

    # Verify copy has same values
    copy.per_page.should eq(5)
    copy.total_pages.should eq(20)
    copy.page.should eq(3)
    copy.type.should eq(Bubbles::Paginator::Type::Dots)
    copy.active_dot.should eq("X")
    copy.inactive_dot.should eq("o")
    copy.arabic_format.should eq("Page %d of %d")

    # Modify original
    model.page = 10
    model.active_dot = "Y"

    # Verify copy is unchanged (deep copy)
    copy.page.should eq(3)
    copy.active_dot.should eq("X")

    # Test KeyMap dup
    keymap = model.key_map
    keymap_copy = keymap.dup

    # Verify keymap copy
    keymap_copy.prev_page.keys.should eq(keymap.prev_page.keys)
    keymap_copy.next_page.keys.should eq(keymap.next_page.keys)

    # Test that update returns a modified copy, not modifies original
    original_page = model.page
    updated_model, _ = model.update(Tea::Key.new(code: Tea::KeyRight))

    # Original should be unchanged
    model.page.should eq(original_page)
    # Updated model should have changed
    updated_model.page.should eq(original_page + 1)
  end
end
