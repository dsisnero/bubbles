require "./spec_helper"

# Helpers for the v2.2.2 filepicker tests.

# Go: newTestDir
private def new_picker_dir : String
  root = File.tempname("bubbles-filepicker")
  sub = File.join(root, "subdir")
  Dir.mkdir_p(sub)
  File.write(File.join(sub, "file.go"), "package main")
  root
end

private def picker_read_dir(m : Bubbles::Filepicker::Model) : Bubbles::Filepicker::Model
  cmd = m.init
  msg = cmd.call.not_nil!.as(Bubbles::Filepicker::ReadDirMsg)
  m, _ = m.update(msg)
  m
end

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

    # Test through did_select_file API - without files, should return false
    m.current_directory = "/tmp"
    m.allowed_types = [".txt", ".md"]

    # Create a key press message
    key_msg = Tea::KeyPressMsg.new("enter")

    # Without any files loaded and no path set, should return false
    selected, path = m.did_select_file(key_msg)
    selected.should be_false
    path.should eq("")

    # Same for disabled file check
    selected, path = m.did_select_disabled_file(key_msg)
    selected.should be_false
    path.should eq("")

    # Test that path property works
    m.path = "/tmp/test.txt"
    m.path.should eq("/tmp/test.txt")

    # Test that allowed_types property works
    m.allowed_types = [".txt", ".md"]
    m.allowed_types.should eq([".txt", ".md"])
  end

  describe "humanize_bytes" do
    # Expected values come from github.com/dustin/go-humanize Bytes, which the
    # Go filepicker formats sizes with.
    it "uses SI units like Go's humanize.Bytes" do
      Bubbles::Filepicker.humanize_bytes(0_u64).should eq "0 B"
      Bubbles::Filepicker.humanize_bytes(9_u64).should eq "9 B"
      Bubbles::Filepicker.humanize_bytes(999_u64).should eq "999 B"
      Bubbles::Filepicker.humanize_bytes(1_000_u64).should eq "1.0 kB"
      Bubbles::Filepicker.humanize_bytes(1_500_u64).should eq "1.5 kB"
      Bubbles::Filepicker.humanize_bytes(131_072_u64).should eq "131 kB"
      Bubbles::Filepicker.humanize_bytes(999_999_u64).should eq "1000 kB"
      Bubbles::Filepicker.humanize_bytes(1_000_000_u64).should eq "1.0 MB"
    end
  end

  # Go: TestDidSelectFileRequiresPath
  it "requires both an allowed type and a path to select" do
    m = Bubbles::Filepicker.new
    m.current_directory = File.join(new_picker_dir, "subdir")
    m.allowed_types = [".txt"]
    m = picker_read_dir(m)

    enter = Tea.key(Tea::KeyEnter)
    m.did_select_file(enter)[0].should be_false
    m.did_select_disabled_file(enter)[0].should be_false

    m.allowed_types = [".go"]
    m, _ = m.update(enter)
    did_select, path = m.did_select_file(enter)
    did_select.should be_true
    path.ends_with?("file.go").should be_true
  end

  # Go: TestKeysBeforeEntriesLoad
  it "survives navigation keys before entries load" do
    {
      "down"      => Tea.key(Tea::KeyDown),
      "last"      => Tea.key('G'),
      "page down" => Tea.key(Tea::KeyPgDown),
    }.each do |_name, key|
      m = Bubbles::Filepicker.new
      m.current_directory = File.join(new_picker_dir, "subdir")
      m.file_allowed = true
      m.height = 5

      m, _ = m.update(key)
      m = picker_read_dir(m)
      m, _ = m.update(Tea.key(Tea::KeyEnter))

      did_select, path = m.did_select_file(Tea.key(Tea::KeyEnter))
      did_select.should be_true
      path.ends_with?("file.go").should be_true
    end
  end

  # Go: TestLoadedPickerDoesNotNavigatePastLastEntry
  it "does not move past the last entry" do
    m = Bubbles::Filepicker.new
    m.height = 5
    m.current_directory = File.join(new_picker_dir, "subdir")
    m = picker_read_dir(m)

    [Tea.key(Tea::KeyDown), Tea.key('G'), Tea.key(Tea::KeyPgDown)].each do |key|
      m, _ = m.update(key)
      m.selected_index.should eq(0)
    end
  end

  # Go: TestLoadedPickerSelectsFile
  it "selects a file in a loaded picker" do
    m = Bubbles::Filepicker.new
    m.height = 5
    m.current_directory = File.join(new_picker_dir, "subdir")
    m = picker_read_dir(m)

    enter = Tea.key(Tea::KeyEnter)
    m, _ = m.update(enter)
    did_select, path = m.did_select_file(enter)
    did_select.should be_true
    path.ends_with?("file.go").should be_true
  end

  # Go: TestNavigateWithoutWindowSize
  it "renders and navigates without a window size" do
    m = Bubbles::Filepicker.new
    m.current_directory = new_picker_dir
    m = picker_read_dir(m)

    m.view.should contain("subdir")

    m, cmd = m.update(Tea.key('l'))
    m, _ = m.update(cmd.call.not_nil!.as(Bubbles::Filepicker::ReadDirMsg))
    m.current_directory.ends_with?("subdir").should be_true
    m.view.should contain("file.go")
  end
end
