# frozen_string_literal: true

require "spec_helper"

module FatTerm
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
  end
end
