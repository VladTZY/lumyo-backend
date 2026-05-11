class GenerateNoteSummaryJob < ApplicationJob
  queue_as :default

  def perform(note_summary_id)
    note_summary = NoteSummary.find(note_summary_id)
    note = note_summary.note

    note_summary.update!(status: "generating")

    chat = RubyLLM.chat(model: "anthropic/claude-3-haiku")
    result = chat.ask(<<~PROMPT)
      Summarize the following note in 2-3 concise sentences. Focus on the key points and any action items. Be direct and informative.

      Title: #{note.title}

      Content:
      #{note.content}
    PROMPT

    note_summary.update!(status: "completed", content: result.content, error_message: nil)
  rescue => e
    note_summary&.update!(status: "failed", error_message: e.message)
    raise
  end
end
