# frozen_string_literal: true

require "spec_helper"
require_relative "../renderer_spec"

module Fatty
  RSpec.describe Renderer::Curses do
    let(:screen) { instance_double(Screen) }
    let(:palette) { {} }
    let(:curses_context) { instance_double(Curses::Context) }

    subject(:renderer) do
      Renderer::Curses.new(
        screen: screen,
        palette: palette,
        context: curses_context,
      )
    end

    it_behaves_like "renderer interface"
  end
end
