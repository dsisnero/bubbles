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
    model = Bubbles::Paginator.new
    model.set_total_pages(2)
    model.page = 1
    model, _ = model.update(Tea::KeyPressMsg.new("left"))
    model.page.should eq(0)
  end

  it "TestNextPage" do
    model = Bubbles::Paginator.new
    model.set_total_pages(2)
    model.page = 0
    model, _ = model.update(Tea::KeyPressMsg.new("right"))
    model.page.should eq(1)
  end

  it "TestOnLastPage" do
    model = Bubbles::Paginator.new
    model.set_total_pages(2)
    model.page = 1
    model.on_last_page?.should be_true
  end

  it "TestOnFirstPage" do
    model = Bubbles::Paginator.new
    model.set_total_pages(2)
    model.page = 0
    model.on_first_page?.should be_true
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
