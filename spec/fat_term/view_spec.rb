# frozen_string_literal: true

require "support/null_view"

module FatTerm
  RSpec.describe View do
    describe "#render" do
      # it "is abstract by default" do
      #   v = View.new
      #   expect {
      #     v.render(screen: :screen, renderer: :renderer, terminal: :terminal, session: :session)
      #   }.to raise_error(NotImplementedError)
      # end

      it "can be implemented by a concrete subclass (NullView)" do
        v = NullView.new
        expect {
          v.render(screen: :screen, renderer: :renderer, terminal: :terminal, session: :session)
        }.not_to raise_error
      end

      it "records render calls in NullView" do
        v = NullView.new
        v.render(screen: :screen, renderer: :renderer, terminal: :terminal, session: :session)

        expect(v.renders.size).to eq(1)
        expect(v.renders.first).to include(
                                     screen: :screen,
                                     renderer: :renderer,
                                     terminal: :terminal,
                                     session: :session,
                                   )
      end
    end

    describe "id" do
      it "defaults id from the class name" do
        v = View.new
        expect(v.id).to eq("View")
      end

      it "accepts an explicit id" do
        v = View.new(id: "minibuffer")
        expect(v.id).to eq("minibuffer")
      end
    end

    describe "z" do
      it "defaults to 0" do
        v = View.new
        expect(v.z).to eq(0)
      end

      it "coerces z to an Integer" do
        v = View.new(z: "10")
        expect(v.z).to eq(10)
      end

      it "raises if z is not integer-coercible" do
        expect { View.new(z: "nope") }.to raise_error(ArgumentError)
      end
    end
  end
end
