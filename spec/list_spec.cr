require "./spec_helper"
require "../src/bubbles/list"

private struct TestListItem
  include Bubbles::List::Item

  getter value : String

  def initialize(@value : String)
  end

  def filter_value : String
    @value
  end

  def ==(other : self) : Bool
    @value == other.value
  end
end

private struct TestListDelegate
  include Bubbles::List::ItemDelegate

  def height : Int32
    1
  end

  def spacing : Int32
    0
  end

  def update(msg : Tea::Msg, m : Bubbles::List::Model) : Tea::Cmd
    _ = msg
    _ = m
    nil
  end

  def render(w : IO, m : Bubbles::List::Model, index : Int32, item : Bubbles::List::Item)
    item = item.as(TestListItem)
    w << m.styles.title_bar.render("#{index + 1}. #{item.value}")
  end
end

describe Bubbles::List do
  it "TestStatusBarItemName" do
    list = Bubbles::List.new([TestListItem.new("foo"), TestListItem.new("bar")] of Bubbles::List::Item, TestListDelegate.new, 10, 10)
    list.status_view.includes?("2 items").should be_true

    list.set_items([TestListItem.new("foo")] of Bubbles::List::Item)
    list.status_view.includes?("1 item").should be_true
  end

  it "TestStatusBarWithoutItems" do
    list = Bubbles::List.new([] of Bubbles::List::Item, TestListDelegate.new, 10, 10)
    list.status_view.includes?("No items").should be_true
  end

  it "TestCustomStatusBarItemName" do
    list = Bubbles::List.new([TestListItem.new("foo"), TestListItem.new("bar")] of Bubbles::List::Item, TestListDelegate.new, 10, 10)
    list.set_status_bar_item_name("connection", "connections")
    list.status_view.includes?("2 connections").should be_true

    list.set_items([TestListItem.new("foo")] of Bubbles::List::Item)
    list.status_view.includes?("1 connection").should be_true

    list.set_items([] of Bubbles::List::Item)
    list.status_view.includes?("No connections").should be_true
  end

  it "TestSetFilterText" do
    tc = [TestListItem.new("foo"), TestListItem.new("bar"), TestListItem.new("baz")]
    list = Bubbles::List.new(tc.map(&.as(Bubbles::List::Item)), TestListDelegate.new, 10, 10)
    list.set_filter_text("ba")

    list.set_filter_state(Bubbles::List::FilterState::Unfiltered)
    list.visible_items.should eq(tc.map(&.as(Bubbles::List::Item)))

    list.set_filter_state(Bubbles::List::FilterState::Filtering)
    expected = [TestListItem.new("bar"), TestListItem.new("baz")].map(&.as(Bubbles::List::Item))
    list.visible_items.should eq(expected)

    list.set_filter_state(Bubbles::List::FilterState::FilterApplied)
    list.visible_items.should eq(expected)
  end

  it "TestSetFilterState" do
    tc = [TestListItem.new("foo"), TestListItem.new("bar"), TestListItem.new("baz")]
    list = Bubbles::List.new(tc.map(&.as(Bubbles::List::Item)), TestListDelegate.new, 10, 10)
    list.set_filter_text("ba")

    list.set_filter_state(Bubbles::List::FilterState::Unfiltered)
    footer = list.view.split('\n').last
    footer.includes?("up").should be_true
    footer.includes?("clear filter").should be_false

    list.set_filter_state(Bubbles::List::FilterState::Filtering)
    footer = list.view.split('\n').last
    footer.includes?("filter").should be_true
    footer.includes?("more").should be_false

    list.set_filter_state(Bubbles::List::FilterState::FilterApplied)
    footer = list.view.split('\n').last
    footer.includes?("clear").should be_true
  end
end
