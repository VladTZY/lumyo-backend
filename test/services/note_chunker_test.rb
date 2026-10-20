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
end
