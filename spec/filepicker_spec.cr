require "./spec_helper"
require "../src/bubbles/filepicker"

describe Bubbles::Filepicker do
  it "supports height property" do
    m = Bubbles::Filepicker::Model.new
    m.height = 10
    m.height.should eq(10)
  end

  it "returns empty highlighted path for empty files" do
    m = Bubbles::Filepicker::Model.new
    m.highlighted_path.should eq("")
  end

  it "detects hidden files" do
    hidden, err = Bubbles::Filepicker.hidden?(".env")
    hidden.should be_true
    err.should be_nil

    shown, _ = Bubbles::Filepicker.hidden?("main.cr")
    shown.should be_false
  end

  it "has default key map" do
    key_map = Bubbles::Filepicker.default_key_map
    key_map.should be_a(Bubbles::Filepicker::KeyMap)
    key_map.go_to_top.should be_a(Bubbles::Key::Binding)
    key_map.select.should be_a(Bubbles::Key::Binding)
  end

  it "has default styles" do
    styles = Bubbles::Filepicker.default_styles
    styles.should be_a(Bubbles::Filepicker::Styles)
    styles.cursor.should be_a(Lipgloss::Style)
    styles.file.should be_a(Lipgloss::Style)
  end

  it "creates model with default values" do
    m = Bubbles::Filepicker::Model.new
    m.current_directory.should eq(".")
    m.file_allowed?.should be_true
    m.dir_allowed?.should be_false
    m.show_permissions?.should be_true
    m.show_size?.should be_true
    m.show_hidden?.should be_false
    m.auto_height?.should be_true
    m.cursor.should eq(">")
  end

  it "has can_select logic through public API" do
    m = Bubbles::Filepicker::Model.new

    # Test through did_select_file API
    m.current_directory = "/tmp"
    m.allowed_types = [".txt", ".md"]

    # Create a mock file entry
    file_info = File.info(".")
    entry = Bubbles::Filepicker::Entry.new("test.txt", file_info)
    m.instance_variable_set("@files", [entry])
    m.instance_variable_set("@selected", 0)

    # Set path to simulate selection
    m.path = "/tmp/test.txt"

    # Create a key press message
    key_msg = Tea::KeyPressMsg.new("enter")

    # .txt should be selectable
    selected, _ = m.did_select_file(key_msg)
    selected.should be_true

    # Change to .png file
    entry2 = Bubbles::Filepicker::Entry.new("image.png", file_info)
    m.instance_variable_set("@files", [entry2])
    m.path = "/tmp/image.png"

    # .png should not be selectable (returns false for did_select_file)
    selected, _ = m.did_select_file(key_msg)
    selected.should be_false

    # But did_select_disabled_file should return true
    selected, path = m.did_select_disabled_file(key_msg)
    selected.should be_true
    path.should eq("/tmp/image.png")
  end
end
