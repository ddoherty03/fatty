# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Pager do
    def make_pager(lines)
      out = OutputBuffer.new
      out.lines.concat(lines)
      vp = Viewport.new(height: 5)
      Pager.new(output: out, viewport: vp, mode: :paging)
    end

    it "repeats search like vim/less: n uses original direction, N uses opposite" do
      lines = [
        "aaa foo",
        "bbb",
        "ccc foo",
        "ddd",
      ]

      pager = make_pager(lines)

      # Backward search sets origin direction to :backward
      res = pager.search_set!(pattern: "foo", regex: false, direction: :backward)
      expect(res[:status]).to eq(:moved)
      expect(pager.search_last_match[:line]).to eq(2)

      # n repeats in origin direction (backward): should move to the earlier foo at line 0
      res = pager.search_repeat_next!
      expect(res[:status]).to eq(:moved)
      expect(pager.search_last_match[:line]).to eq(0)

      # N repeats opposite direction (forward): should move back to line 2
      res = pager.search_repeat_prev!
      expect(res[:status]).to eq(:moved)
      expect(pager.search_last_match[:line]).to eq(2)

      # After N, n should still repeat in origin direction (backward): back to line 0
      res = pager.search_repeat_next!
      expect(res[:status]).to eq(:moved)
      expect(pager.search_last_match[:line]).to eq(0)
    end

    it "goes to the counted original output line" do
      lines =
        (1..2_000).map do |number|
          Fatty::OutputSession::VisibleLine.new(number: number, text: "line #{number}")
        end
      output = Fatty::OutputBuffer.new
      viewport = Fatty::Viewport.new(height: 20)
      pager = Fatty::Pager.new(
        output: output,
        viewport: viewport,
        lines: -> { lines },
      )
      counter = Fatty::Counter.new
      counter.set(1_050)
      session = instance_double(Fatty::Session, id: :output, terminal: nil)
      env = Fatty::ActionEnvironment.new(session: session, pager: pager, counter: counter)

      pager.act_on(:page_top, env: env)

      expect(viewport.top).to eq(1_049)
      expect(counter).not_to be_active
    end
  end
end
