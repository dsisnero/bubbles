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
end
