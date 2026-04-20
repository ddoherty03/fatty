# frozen_string_literal: true

require "tmpdir"
require "fileutils"

require "spec_helper"

module FatTerm
  RSpec.describe Terminal do
    def write_xdg_config(xdg_home, app:, name:, content:)
      dir = File.join(xdg_home, app)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{name}.yml"), content)
    end

    around do |ex|
      Dir.mktmpdir("fat_term_spec_xdg") do |tmp|
        old = ENV["XDG_CONFIG_HOME"]
        ENV["XDG_CONFIG_HOME"] = tmp

        old_reader = FatTerm::Config.reader
        old_progname = FatTerm::Config.progname
        old_logger = FatTerm::Logger.logger

        FatTerm::Config.progname = "fat_term"
        FatTerm::Config.reader = nil
        FatTerm::Logger.logger = nil

        ex.run
      ensure
        FatTerm::Config.reader = old_reader
        FatTerm::Config.progname = old_progname
        FatTerm::Logger.logger = old_logger
        ENV["XDG_CONFIG_HOME"] = old
      end
    end

    describe "#preflight!" do
      around do |ex|
        Dir.mktmpdir("fat_term_spec_xdg") do |tmp|
          old = ENV["XDG_CONFIG_HOME"]
          ENV["XDG_CONFIG_HOME"] = tmp
          ex.run
          ENV["XDG_CONFIG_HOME"] = old
        end
      end

      it "prints a configuration error and exits(1) on parse error" do
        xdg = ENV.fetch("XDG_CONFIG_HOME")

        # Broken YAML on purpose.
        write_xdg_config(
          xdg,
          app: "fat_term",
          name: "config",
          content: "log: [broken",
        )

        t = Terminal.new

        expect {
          expect { t.send(:preflight!) }.to raise_error(SystemExit) { |e|
            expect(e.status).to eq(1)
          }
        }.to output(/YAML parse error/).to_stderr
      end

      it "includes file/line information in the error message when available" do
        xdg = ENV.fetch("XDG_CONFIG_HOME")

        write_xdg_config(
          xdg,
          app: "fat_term",
          name: "config",
          content: "log: [broken",
        )

        t = Terminal.new

        expect {
          expect { t.send(:preflight!) }.to raise_error(SystemExit)
        }.to output(/at line \d+, column \d+/i).to_stderr
      end
    end

    describe "handling of modals" do
      it "returns the owner of the top modal without popping or closing the modal session" do
        terminal = FatTerm::Terminal.new
        owner = instance_double(FatTerm::ShellSession)
        popup = instance_double(FatTerm::PopUpSession, init: [], close: nil)

        terminal.push_modal(popup, owner: owner)

        expect(terminal.send(:modal_owner)).to eq(owner)
        expect(popup).not_to have_received(:close)
        expect(terminal.instance_variable_get(:@modal_stack).length).to eq(1)
      end

      it "keeps the modal on the stack when init sends a message to the modal owner" do
        terminal = FatTerm::Terminal.new
        owner = instance_double(FatTerm::ShellSession)
        popup = instance_double(FatTerm::PopUpSession, close: nil)

        allow(popup).to receive(:init).and_return([
          [:terminal, :send_modal_owner, [:cmd, :popup_changed, { kind: :history_search }]]
        ])

        allow(owner).to receive(:update).and_return([])

        terminal.push_modal(popup, owner: owner)

        expect(terminal.instance_variable_get(:@modal_stack).length).to eq(1)
        expect(terminal.send(:active_session)).to eq(popup)
        expect(popup).not_to have_received(:close)
      end
    end

    describe "#install_default_sessions!" do
      it "passes history_ctx to ShellSession" do
        history_ctx = -> { { pwd: "/tmp/demo" } }
        terminal = Terminal.new(history_ctx: history_ctx)

        allow(terminal).to receive(:pin)
        allow(terminal).to receive(:push)

        terminal.send(:install_default_sessions!)

        expect(terminal).to have_received(:push) do |session|
          expect(session).to be_a(FatTerm::ShellSession)
          field = session.field
          expect(field.send(:resolve_history_ctx)).to eq({ pwd: "/tmp/demo" })
        end
      end
    end

    describe "#choose method" do
      it "returns the selected plain choice" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:set_status)
        allow(terminal).to receive(:clear_status)
        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive_messages(
          event_source: instance_double("EventSource", next_event: nil),
          active_session: nil,
        )
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:terminal, :popup_result, { item: "Assets" }], terminal: terminal)
        end

        result = terminal.choose(
          "Select account",
          choices: ["Assets", "Liabilities", "Equity"],
        )

        expect(result).to eq("Assets")
      end

      it "returns the mapped value for label value choices" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:set_status)
        allow(terminal).to receive(:clear_status)
        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive_messages(
          event_source: instance_double("EventSource", next_event: nil),
          active_session: nil,
        )
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:terminal, :popup_result, { item: "Liabilities" }], terminal: terminal)
        end

        result = terminal.choose(
          "Select account",
          choices: [
            ["Assets", :assets],
            ["Liabilities", :liabilities],
          ],
        )

        expect(result).to eq(:liabilities)
      end

      it "returns the quit value when the chooser is cancelled" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:set_status)
        allow(terminal).to receive(:clear_status)
        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive_messages(
          event_source: instance_double("EventSource", next_event: nil),
          active_session: nil,
        )
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:terminal, :popup_cancelled, nil], terminal: terminal)
        end

        result = terminal.choose(
          "Select",
          choices: ["A", "B"],
          quit_value: :cancelled,
        )

        expect(result).to eq(:cancelled)
      end

      it "returns nil value when the chooser is cancelled with default value" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:set_status)
        allow(terminal).to receive(:clear_status)
        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive_messages(
          event_source: instance_double("EventSource", next_event: nil),
          active_session: nil,
        )
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:terminal, :popup_cancelled, nil], terminal: terminal)
        end

        expect(terminal.choose("Select", choices: ["A", "B"])).to be_nil
      end
    end

    describe "#confirm method" do
      it "returns true when choose returns true" do
        terminal = FatTerm::Terminal.allocate
        allow(terminal).to receive(:choose).and_return(true)

        expect(terminal.confirm("Delete?")).to be(true)
      end

      it "returns false when choose returns false" do
        terminal = FatTerm::Terminal.allocate
        allow(terminal).to receive(:choose).and_return(false)

        expect(terminal.confirm("Delete?")).to be(false)
      end
    end

    describe "#prompt method" do
      it "returns entered text" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive(:event_source).and_return(instance_double("EventSource", next_event: nil))
        allow(terminal).to receive(:active_session).and_return(nil)
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:cmd, :prompt_result, { text: "Checking" }], terminal: terminal)
        end

        result = terminal.prompt("Rename account:", initial: "Savings")

        expect(result).to eq("Checking")
      end

      it "returns quit_value on cancel" do
        terminal = FatTerm::Terminal.allocate

        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive(:event_source).and_return(instance_double("EventSource", next_event: nil))
        allow(terminal).to receive(:active_session).and_return(nil)
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |_popup, owner:|
          owner.update([:cmd, :prompt_cancelled, {}], terminal: terminal)
        end

        result = terminal.prompt("Rename account:", quit_value: :cancelled)

        expect(result).to eq(:cancelled)
      end

      it "uses prompt text as the default history context" do
        terminal = FatTerm::Terminal.allocate
        popup = nil

        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive(:event_source).and_return(instance_double("EventSource", next_event: nil))
        allow(terminal).to receive(:active_session).and_return(nil)
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |session, owner:|
          popup = session
          owner.update([:cmd, :prompt_cancelled, {}], terminal: terminal)
        end

        terminal.prompt("Rename account:", initial: "Checking")

        expect(popup).to be_a(FatTerm::PromptSession)
        expect(popup.field.send(:resolve_history_ctx)).to eq({ prompt: "Rename account:" })
      end

      it "uses history_key instead of prompt text when provided" do
        terminal = FatTerm::Terminal.allocate
        popup = nil

        allow(terminal).to receive(:render_frame)
        allow(terminal).to receive(:event_source).and_return(instance_double("EventSource", next_event: nil))
        allow(terminal).to receive(:active_session).and_return(nil)
        allow(terminal).to receive(:dispatch_message)
        terminal.instance_variable_set(:@running, true)

        allow(terminal).to receive(:push_modal) do |session, owner:|
          popup = session
          owner.update([:cmd, :prompt_cancelled, {}], terminal: terminal)
        end

        terminal.prompt("Rename account:", initial: "Checking", history_key: :account_name)

        expect(popup).to be_a(FatTerm::PromptSession)
        expect(popup.field.send(:resolve_history_ctx)).to eq({ prompt: "account_name" })
      end
    end
  end
end
