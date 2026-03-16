# frozen_string_literal: true

require "spec_helper"

module FatTerm
  module Curses
    RSpec.describe EventSource do
      let(:window) { instance_double("window") }
      let(:context) { instance_double(Context, input_win: window) }
      let(:key_decoder) { instance_double(KeyDecoder) }

      it "returns a :cmd paste message when read_raw returns paste data" do
        source = EventSource.new(
          context: context,
          key_decoder: key_decoder,
          poll_ms: 10,
        )

        allow(source).to receive(:read_raw).and_return([:paste, "hello\nworld\n"])

        event = source.next_event

        expect(event).to eq([:cmd, :paste, { text: "hello\nworld\n" }])
      end
    end
  end
end
