# frozen_string_literal: true

module Fatty
  RSpec.describe Terminal::PopupOwner do
    describe "#update" do
      it "returns an empty array for unhandled commands" do
        owner = Fatty::Terminal::PopupOwner.new
        command = Fatty::Command.session(:owner, :unknown)

        expect(owner.update(command)).to eq([])
      end

      it "calls on_result for popup_result and returns normalized commands" do
        returned = Fatty::Command.session(:output, :append, text: "ok")
        owner = Fatty::Terminal::PopupOwner.new(
          on_result: ->(payload) {
            expect(payload).to eq(item: "One")
            returned
          },
        )
        command = Fatty::Command.session(:owner, :popup_result, item: "One")

        expect(owner.update(command)).to eq([returned])
      end

      it "calls on_result for prompt_result and compacts returned arrays" do
        first = Fatty::Command.session(:output, :append, text: "first")
        second = Fatty::Command.session(:status, :show, text: "done")
        owner = Fatty::Terminal::PopupOwner.new(
          on_result: ->(payload) {
            expect(payload).to eq(text: "hello")
            [first, nil, second]
          },
        )
        command = Fatty::Command.session(:owner, :prompt_result, text: "hello")

        expect(owner.update(command)).to eq([first, second])
      end

      it "calls on_cancel for popup_cancelled" do
        returned = Fatty::Command.session(:alert, :clear)
        owner = Fatty::Terminal::PopupOwner.new(on_cancel: -> { returned })
        command = Fatty::Command.session(:owner, :popup_cancelled)

        expect(owner.update(command)).to eq([returned])
      end

      it "calls on_cancel for prompt_cancelled" do
        returned = Fatty::Command.session(:alert, :clear)
        owner = Fatty::Terminal::PopupOwner.new(on_cancel: -> { returned })
        command = Fatty::Command.session(:owner, :prompt_cancelled)

        expect(owner.update(command)).to eq([returned])
      end

      it "calls on_change for popup_changed" do
        returned = Fatty::Command.terminal(:set_theme, name: "nordic")
        owner = Fatty::Terminal::PopupOwner.new(
          on_change: ->(payload) {
            expect(payload).to eq(item: "nordic")
            returned
          },
        )
        command = Fatty::Command.session(:owner, :popup_changed, item: "nordic")

        expect(owner.update(command)).to eq([returned])
      end

      it "returns an empty array when callbacks return nil" do
        owner = Fatty::Terminal::PopupOwner.new(
          on_result: ->(_payload) {},
          on_cancel: -> {},
          on_change: ->(_payload) {},
        )

        expect(owner.update(Fatty::Command.session(:owner, :popup_result))).to eq([])
        expect(owner.update(Fatty::Command.session(:owner, :popup_cancelled))).to eq([])
        expect(owner.update(Fatty::Command.session(:owner, :popup_changed))).to eq([])
      end
    end
  end
end
