# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe PopUpSession do
    def init_popup_session(session, rows: 24, cols: 80)
      screen = instance_double(Fatty::Screen, rows: rows, cols: cols)
      renderer = instance_double(Fatty::Renderer, screen: screen)
      terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

      stub_curses_window(rows: rows, cols: cols)

      session.init(terminal: terminal)
      session
    end

    describe 'initialization' do
      it "initializes from a static source" do
        session = PopUpSession.new(
          title: "Pick one",
          source: %w[alpha beta gamma]
        )

        expect(session.title).to eq("Pick one")
        expect(session.items).to eq(%w[alpha beta gamma])
      end

      it "initializes from a callable source" do
        session = PopUpSession.new(
          source: ->(_filter) { %w[alpha beta] }
        )

        expect(session.items).to eq(%w[alpha beta])
      end
    end

    describe "#update" do
      it "handles terminal_paste by updating the filter and refreshing items" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta gamma])
        init_popup_session(popup)

        commands = update(popup, :terminal_paste, text: "alp")

        expect(commands).to eq([])
        expect(popup.field.buffer.text).to eq("alp")
        expect(popup.filtered).to eq(%w[alpha])
        expect(popup.displayed).to eq(%w[alpha])
      end

      it "handles key actions" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta gamma])
        init_popup_session(popup)

        commands = update(popup, :key, event: key(:down))

        expect(commands.length).to eq(1)
        expect(commands.first.action).to eq(:send_modal_owner)
        expect(popup.state[3]).to eq(1) # selected
      end

      it "edits the filter for text keys" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta gamma])
        init_popup_session(popup)

        commands = update(popup, :key, event: key(:a, text: "a"))

        expect(commands.length).to eq(1)
        expect(commands.first.action).to eq(:send_modal_owner)
        expect(popup.field.buffer.text).to eq("a")
        expect(popup.filtered).to eq(%w[alpha beta gamma])
      end

      it "returns the current item in multi-select mode when nothing is selected" do
        session = Fatty::PopUpSession.new(
          source: ["one", "two", "three"],
          selection_mode: :multiple,
          kind: :terminal_choose_multi,
        )

        commands = session.send(:accept_selection)

        result_command = commands.first.payload[:command]
        expect(result_command.payload[:items]).to eq({ "one" => "one" })
      end

      it "ignores unknown commands" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta gamma])
        init_popup_session(popup)

        expect(update(popup, :bogus)).to eq([])
      end
    end

    describe "#move_current_by" do
      def build_popup(items)
        PopUpSession.new(
          source: items,
          kind: :completion,
          title: "Completions",
          prompt: "Complete: ",
          order: :as_given,
          current: :top,
        )
      end

      it "wraps backward from the first item to the last" do
        popup = build_popup(%w[alpha beta gamma])

        popup.instance_variable_set(:@displayed, %w[alpha beta gamma])
        popup.instance_variable_set(:@current, 0)

        popup.send(:move_current_by, -1)

        expect(popup.instance_variable_get(:@current)).to eq(2)
      end

      it "wraps forward from the last item to the first" do
        popup = build_popup(%w[alpha beta gamma])

        popup.instance_variable_set(:@displayed, %w[alpha beta gamma])
        popup.instance_variable_set(:@current, 2)

        popup.send(:move_current_by, 1)

        expect(popup.instance_variable_get(:@current)).to eq(0)
      end

      it "notifies the owner when tab is pressed in a completion popup" do
        popup = Fatty::PopUpSession.new(
          source: %w[alpha beta],
          kind: :completion,
        )
        init_popup_session(popup)

        commands = apply_action(popup, :popup_tab)

        owner_command = commands.first.payload.fetch(:command)

        expect(commands.first.action).to eq(:send_modal_owner)
        expect(owner_command.action).to eq(:popup_tab)
        expect(owner_command.payload[:kind]).to eq(:completion)
        expect(owner_command.payload[:item]).to eq("alpha")
        expect(owner_command.payload[:session]).to be(popup)
      end
    end

    describe "renderer-facing public helpers" do
      it "reports whether counts are present" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta])
        expect(popup.counts_present?).to be(true)
      end

      it "clamps scroll_start for the visible list height" do
        popup = Fatty::PopUpSession.new(source: %w[a b c d e])
        popup.instance_variable_set(:@scroll_start, 99)
        expect(popup.scroll_start(list_h: 3)).to eq(2)
      end

      it "returns a blank gutter for single-select popups" do
        popup = Fatty::PopUpSession.new(source: %w[alpha])
        expect(popup.gutter_for(item: "alpha", selected: true)).to eq(" ")
      end

      it "returns counts" do
        popup = Fatty::PopUpSession.new(source: %w[alpha beta gamma])
        expect(popup.counts)
          .to eq(
            total: 3,
            selected: 1,
            matching: 3,
            showing: 3,
          )
      end
    end

    describe "#call_source" do
      it "returns literal array sources unchanged as an array" do
        popup = PopUpSession.new(source: %w[alpha beta gamma])
        expect(popup.send(:call_source, "alp")).to eq(%w[alpha beta gamma])
      end

      it "calls arity-0 sources with no argument" do
        popup = PopUpSession.new(source: -> { %w[alpha beta] })
        expect(popup.send(:call_source, "ignored")).to eq(%w[alpha beta])
      end

      it "calls arity-1 sources with the query" do
        popup = PopUpSession.new(source: ->(q) { [q, q.upcase] })
        expect(popup.send(:call_source, "alp")).to eq(%w[alp ALP])
      end
    end
  end
end
