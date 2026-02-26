require "./spec_helper"
require "../src/bubbles/filepicker"

describe Bubbles::Filepicker do
  it "supports SetHeight and Height" do
    m = Bubbles::Filepicker::Model.new
    m.set_height(10)
    m.height.should eq(10)
  end

  it "returns highlighted path" do
    m = Bubbles::Filepicker::Model.new
    m.current_directory = "/tmp"
    m.files = [Bubbles::Filepicker::Entry.new("a.txt"), Bubbles::Filepicker::Entry.new("b.txt")]
    m.selected = 1
    m.highlighted_path.should eq("/tmp/b.txt")
  end

  it "returns empty highlighted path for invalid selection" do
    m = Bubbles::Filepicker::Model.new
    m.highlighted_path.should eq("")
  end

  it "detects did_select_file" do
    m = Bubbles::Filepicker::Model.new
    m.current_directory = "/tmp"
    m.files = [Bubbles::Filepicker::Entry.new("a.txt")]
    m.key_map = Bubbles::Filepicker::KeyMap.new(
      Bubbles::Key.new_binding(Bubbles::Key.with_keys("enter"))
    )

    selected, path = m.did_select_file(Tea::KeyPressMsg.new("enter"))
    selected.should be_true
    path.should eq("/tmp/a.txt")
  end

  it "detects did_select_disabled_file when extension disallowed" do
    m = Bubbles::Filepicker::Model.new
    m.current_directory = "/tmp"
    m.files = [Bubbles::Filepicker::Entry.new("a.txt")]
    m.allowed_types = [".md"]
    m.key_map = Bubbles::Filepicker::KeyMap.new(
      Bubbles::Key.new_binding(Bubbles::Key.with_keys("enter"))
    )

    selected, path = m.did_select_disabled_file(Tea::KeyPressMsg.new("enter"))
    selected.should be_true
    path.should eq("/tmp/a.txt")
  end

  it "detects hidden files" do
    hidden, err = Bubbles::Filepicker.hidden?(".env")
    hidden.should be_true
    err.should be_nil

    shown, _ = Bubbles::Filepicker.hidden?("main.cr")
    shown.should be_false
  end
end
