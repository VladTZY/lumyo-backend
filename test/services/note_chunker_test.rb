require "test_helper"

class NoteChunkerTest < ActiveSupport::TestCase
  test "strip_prefix removes a single-line title prefix" do
    assert_equal "Body text", NoteChunker.strip_prefix("title: T\ntags: a, b\n\nBody text")
  end

  test "strip_prefix removes a multi-line title prefix" do
    assert_equal "The body", NoteChunker.strip_prefix("title: A\nB\ntags: x\n\nThe body")
  end

  test "strip_prefix handles empty tags" do
    assert_equal "The body", NoteChunker.strip_prefix("title: A\ntags: \n\nThe body")
  end

  test "strip_prefix leaves text without the prefix unchanged" do
    assert_equal "Just a body\n\nwith paragraphs", NoteChunker.strip_prefix("Just a body\n\nwith paragraphs")
  end

  test "strip_prefix returns an empty string for nil" do
    assert_equal "", NoteChunker.strip_prefix(nil)
  end

  test "strip_prefix round-trips what chunks builds" do
    note = notes(:one)
    note.update_columns(content: "Hello there")
    chunk = NoteChunker.new(note).chunks.first
    assert_equal "Hello there", NoteChunker.strip_prefix(chunk[:text])
  end

  # The mobile editor writes bullets as "• ". They must be grouped into one
  # list block like "-" lists, not merged into the surrounding paragraph.
  def blocks_for(text)
    NoteChunker.new(notes(:one)).send(:extract_blocks, text)
  end

  test "extract_blocks keeps editor bullet lines together as one block" do
    blocks = blocks_for("Intro line\n• first\n• second\n• third\nOutro line\n")
    assert_equal [ "Intro line\n", "• first\n• second\n• third\n", "Outro line\n" ], blocks
  end

  test "extract_blocks still groups dash lists" do
    blocks = blocks_for("Intro\n- a\n- b\n")
    assert_equal [ "Intro\n", "- a\n- b\n" ], blocks
  end

  test "extract_blocks groups a list that mixes bullet styles" do
    blocks = blocks_for("• a\n- b\n• c\n")
    assert_equal [ "• a\n- b\n• c\n" ], blocks
  end

  test "extract_blocks keeps formatted text inside a bullet item" do
    blocks = blocks_for("Notes:\n• **bold** and <u>under</u>\n• *it*\n")
    assert_equal [ "Notes:\n", "• **bold** and <u>under</u>\n• *it*\n" ], blocks
  end

  test "extract_blocks does not treat a bullet glyph without a space as a list" do
    blocks = blocks_for("•not a bullet\nsame paragraph\n")
    assert_equal [ "•not a bullet\nsame paragraph\n" ], blocks
  end

  test "long notes keep an editor bullet list intact in a single chunk" do
    note = notes(:one)
    prose = ([ "This sentence pads the note with enough words to force splitting." ] * 60).join(" ")
    # Items end in a period and follow the prose with no blank line, so
    # without list detection the sentence splitter can cut through the list.
    list = (1..20).map { |i| "• item number #{i} in the list." }.join("\n")
    note.update_columns(content: "#{prose}\n#{list}\n#{prose}")
    chunks = NoteChunker.new(note).chunks.map { |c| NoteChunker.strip_prefix(c[:text]) }
    assert chunks.any? { |c| c.include?(list) },
      "expected one chunk to contain the whole bullet list, line breaks intact"
  end
end
