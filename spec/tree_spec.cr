require "./spec_helper"

# Helper: the sample tree used by the upstream golden tests.
private def new_tree(width : Int32 = 70, height : Int32 = 13) : Bubbles::Tree::Model
  Bubbles::Tree.new(
    Bubbles::Tree::Node.root("~/charm").child(
      "ayman",
      Bubbles::Tree::Node.root("bash").child(
        Bubbles::Tree::Node.root("tools").child(
          "zsh",
          "doom-emacs"
        )
      ),
      Bubbles::Tree::Node.root("carlos").child(
        Bubbles::Tree::Node.root("emotes").child(
          "chefkiss.png",
          "kekw.png"
        )
      ),
      "maas"
    ),
    width,
    height
  )
end

private def golden(name : String) : String
  File.read("#{__DIR__}/testdata/Tree/#{name}")
end

private struct NodeValueStringer
  include Bubbles::Tree::DisplayValue

  def initialize(@value : String)
  end

  def to_s : String
    @value
  end
end

describe Bubbles::Tree do
  # Go: TestTree
  it "renders the default tree" do
    m = new_tree
    Ansi.strip(m.view).should eq(golden("default_tree.golden"))
  end

  # Go: TestTreeMultiLineNodes
  it "keeps the cursor on the selected node when nodes span multiple lines" do
    m = Bubbles::Tree.new(
      Bubbles::Tree::Node.root("~/charm").child(
        "ayman",
        "two\nlines",
        Bubbles::Tree::Node.root("bash").child(
          "zsh",
          "doom\nemacs"
        ),
        "maas"
      ),
      70,
      20
    )

    (m.root.size - 1).times do |i|
      m.down
      node = m.node_at_current_offset
      node.should_not be_nil

      view = Ansi.strip(m.viewport.view)
      cursor_line = -1
      view.lines.each_with_index do |line, j|
        if line.includes?("→")
          cursor_line = j
          break
        end
      end

      want = node.not_nil!.line_offset - m.viewport.y_offset
      cursor_line.should eq(want), "step #{i}: cursor on line #{cursor_line}, want #{want}"
    end
  end

  # Go: TestTreeAdditionalHelp
  it "renders additional short help keys" do
    m = new_tree
    m.set_additional_short_help_keys(-> {
      [Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("v"),
        Bubbles::Key.with_help("v", "select")
      )]
    })

    Ansi.strip(m.view).should eq(golden("additional_help.golden"))
  end

  # Go: TestSetNodesNil
  it "renders an empty tree after SetNodes(nil)" do
    m = Bubbles::Tree.new(
      Bubbles::Tree::Node.root("~/charm").child("ayman", "maas"),
      40,
      10
    )
    m.set_nodes(nil)

    expected = Ansi.strip(Bubbles::Tree.new(nil, 40, 10).view)
    Ansi.strip(m.view).should eq(expected)
  end

  # Go: TestSetNodesRendersReplacement
  it "renders the replacement tree after SetNodes" do
    m = Bubbles::Tree.new(Bubbles::Tree::Node.root("old"), 40, 10)
    m.set_nodes(Bubbles::Tree::Node.root("replacement"))

    view = Ansi.strip(m.view)
    view.should contain("replacement")
    view.should_not contain("old")
  end

  # Go: TestSetNodesPreservesSuppliedNode
  it "keeps the supplied node when setting nodes" do
    node = Bubbles::Tree::Node.root("replacement").child("child")
    m = Bubbles::Tree.new(Bubbles::Tree::Node.root("old"), 40, 10)
    m.set_nodes(node)

    m.root.should be(node)
  end

  # Go: TestNodeSetValue
  describe "Node#set_value" do
    it "stores the given value and renders strings" do
      node = Bubbles::Tree::Node.root("before").child("child")
      node.set_value("after")

      node.given_value.should eq("after")
      Ansi.strip(node.value).should eq("after")
      Ansi.strip(node.to_s).should eq("after\n└── child")
    end

    it "renders numbers" do
      node = Bubbles::Tree::Node.root("before").child("child")
      node.set_value(42)

      node.given_value.should eq(42)
      Ansi.strip(node.value).should eq("42")
      Ansi.strip(node.to_s).should eq("42\n└── child")
    end

    it "renders Stringer-like values" do
      node = Bubbles::Tree::Node.root("before").child("child")
      node.set_value(NodeValueStringer.new("formatted"))

      Ansi.strip(node.value).should eq("formatted")
      Ansi.strip(node.to_s).should eq("formatted\n└── child")
    end
  end

  # Go: TestTreeSetChildValue
  it "renders an updated child value after SetNodes" do
    root = Bubbles::Tree::Node.root("root").child("before")
    model = Bubbles::Tree.new(root, 40, 10)
    model.set_show_help(false)

    root.child_nodes[0].set_value("after")
    model.set_nodes(root)

    view = Ansi.strip(model.view)
    view.should contain("after")
    view.should_not contain("before")
  end
end
