# frozen_string_literal: true

module Fatty
  RSpec.describe ISearchSession do
    def key(key, text: nil, ctrl: false, meta: false, shift: false)
      Fatty::KeyEvent.new(key: key, text: text, ctrl: ctrl, meta: meta, shift: shift)
    end

    def update(session, action, **payload)
      session.update(Fatty::Command.session(session.id, action, **payload))
    end

    describe "#initialize" do
      it "sets direction, last pattern, prompt, and field" do
        session = Fatty::ISearchSession.new(
          direction: :backward,
          last_pattern: "needle",
        )

        expect(session.id).to eq(:isearch)
        expect(session.direction).to eq(:backward)
        expect(session.last_pattern).to eq("needle")
        expect(session.field.prompt_text).to include("↑")
        expect(session.field.prompt_text).to include("I-search")
      end
    end

    describe "#update" do
      it "previews ordinary text changes" do
        session = Fatty::ISearchSession.new(direction: :forward)

        commands = update(session, :key, event: key(:a, text: "a"))

        expect(session.field.buffer.text).to eq("a")
        expect(commands.length).to eq(1)
        expect(commands.first.action).to eq(:send_modal_owner)

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(:focused)
        expect(owner_command.action).to eq(:pager_isearch_update)
        expect(owner_command.payload).to include(
          pattern: "a",
          direction: :forward,
        )
      end

      it "does not preview when text is unchanged" do
        session = Fatty::ISearchSession.new(direction: :forward)

        update(session, :key, event: key(:a, text: "a"))
        commands = update(session, :key, event: key(:left))

        expect(commands).to eq([])
      end

      it "accepts the incremental search" do
        session = Fatty::ISearchSession.new(direction: :forward)

        session.field.buffer.replace("needle")

        commands = update(session, :key, event: key(:enter))

        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(:focused)
        expect(owner_command.action).to eq(:pager_isearch_commit)
        expect(owner_command.payload).to include(
          pattern: "needle",
          direction: :forward,
        )
      end

      it "handles terminal_paste by previewing the pasted pattern" do
        session = Fatty::ISearchSession.new(direction: :forward)

        commands = update(session, :terminal_paste, text: "hello\nworld\n")

        expect(session.field.buffer.text).to eq("hello world ")
        expect(commands.length).to eq(1)
        expect(commands.first.action).to eq(:send_modal_owner)

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(:focused)
        expect(owner_command.action).to eq(:pager_isearch_update)
        expect(owner_command.payload).to include(
                                           pattern: "hello world ",
                                           direction: :forward,
                                         )
      end

      it "cancels the incremental search" do
        session = Fatty::ISearchSession.new

        commands = update(session, :key, event: key(:escape))

        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(:focused)
        expect(owner_command.action).to eq(:pager_isearch_cancel)
      end

      it "steps forward" do
        session = Fatty::ISearchSession.new(direction: :backward)

        commands = update(session, :key, event: key(:s, ctrl: true))

        expect(session.direction).to eq(:forward)

        owner_command = commands.last.payload.fetch(:command)

        expect(owner_command.action).to eq(:pager_isearch_step)
        expect(owner_command.payload[:direction]).to eq(:forward)
      end

      it "steps backward" do
        session = Fatty::ISearchSession.new(direction: :forward)

        commands = update(session, :key, event: key(:r, ctrl: true))

        expect(session.direction).to eq(:backward)

        owner_command = commands.last.payload.fetch(:command)

        expect(owner_command.action).to eq(:pager_isearch_step)
        expect(owner_command.payload[:direction]).to eq(:backward)
      end

      it "prefills the last pattern when stepping from an empty field" do
        session = Fatty::ISearchSession.new(
          direction: :forward,
          last_pattern: "needle",
        )

        commands = update(session, :key, event: key(:s, ctrl: true))

        expect(session.field.buffer.text).to eq("needle")
        expect(commands.map(&:action)).to eq(
          [:send_modal_owner, :send_modal_owner]
        )

        preview_command = commands.first.payload.fetch(:command)
        step_command = commands.last.payload.fetch(:command)

        expect(preview_command.action).to eq(:pager_isearch_update)
        expect(preview_command.payload[:pattern]).to eq("needle")

        expect(step_command.action).to eq(:pager_isearch_step)
        expect(step_command.payload[:direction]).to eq(:forward)
      end

      it "updates failed state from owner feedback" do
        session = Fatty::ISearchSession.new

        commands = update(session, :isearch_set_failed, failed: true)

        expect(commands).to eq([])
        expect(session.field.prompt_text).to include("Failing I-search")
      end

      it "records accepted incremental searches in string search history context" do
        history = Fatty::History.new(path: nil)
        session = Fatty::ISearchSession.new(direction: :forward, history: history)
        session.field.buffer.replace("needle")

        update(session, :key, event: key(:enter))

        entry = history.entries.last
        expect(entry.text).to eq("needle")
        expect(entry.kind).to eq(:search_string)
        expect(entry.ctx).to eq({ "kind" => :search, "regex" => false })
      end

      it "does not record canceled incremental searches" do
        history = Fatty::History.new(path: nil)
        session = Fatty::ISearchSession.new(direction: :forward, history: history)
        session.field.buffer.replace("needle")

        update(session, :key, event: key(:escape))

        expect(history.entries).to be_empty
      end

      it "ignores unknown commands" do
        session = Fatty::ISearchSession.new

        expect(update(session, :bogus)).to eq([])
      end
    end

    describe "#view" do
      it "renders the incremental search field on the pager status row" do
        session = Fatty::ISearchSession.new
        output_rect = instance_double("OutputRect", rows: 10)
        screen = instance_double(Fatty::Screen, output_rect: output_rect)
        renderer = instance_double(Fatty::Renderer::Truecolor)
        terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

        session.init(terminal: terminal)
        expect(renderer)
          .to receive(:show_cursor)
        expect(renderer)
          .to receive(:render_pager_field)
          .with(session.field, row: 9, role: :search_input)
        expect(renderer)
          .to receive(:restore_output_cursor)
          .with(session.field, row: 9)
        session.view
      end
    end
  end
end
