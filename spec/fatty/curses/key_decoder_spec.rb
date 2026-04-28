# frozen_string_literal: true

module Fatty
  module Curses
    RSpec.describe KeyDecoder do
      # Helper to stub a small built-in map without depending on curses.
      def stub_builtin_map
        stub_const(
          "Fatty::CURSES_TO_EVENT",
          {
            9 => KeyEvent.new(key: :tab, raw: 9),
            260 => KeyEvent.new(key: :left, raw: 260),
            261 => KeyEvent.new(key: :right, raw: 261),
          },
        )
      end

      def env(term = :xterm)
        { terminal: term }
      end

      describe "#decode" do
        it "returns nil for nil raw" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          expect(kd.decode(nil)).to be_nil
        end

        it "decodes a known integer using CURSES_TO_EVENT" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(260)

          expect(e).to be_a(KeyEvent)
          expect(e.key).to eq(:left)
          expect(e.raw).to eq(260)
          expect(e.meta?).to be(false)
        end

        it "decodes printable strings with self text payload" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode("a")

          expect(e.key).to eq(:a)
          expect(e.text).to eq("a")
          expect(e.raw).to eq("a")
        end

        it "decodes printable punctuation as self-insert (text set)" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode("@")

          expect(e.key).to eq(:'@')
          expect(e.text).to eq('@')
          expect(e.raw).to eq('@')
        end

        it "treats tab (9) as an action key (:tab) with no text" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(9)

          expect(e.key).to eq(:tab)
          expect(e.text).to be_nil
          expect(e.raw).to eq(9)
        end

        it "decodes control keys 1..26 as ctrl-letter with no text" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(1) # C-a

          expect(e.key).to eq(:a)
          expect(e.ctrl?).to be(true)
          expect(e.text).to be_nil
          expect(e.raw).to eq(1)
        end

        it "treats a lone ESC (27) as :escape (not meta)" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(27)

          expect(e.key).to eq(:escape)
          expect(e.raw).to eq(27)
          expect(e.meta?).to be(false)
        end

        it "decodes meta-letter when raw is [27, 'x'] without text" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode([27, "f"])

          expect(e.key).to eq(:f)
          expect(e.text).to be_nil
          expect(e.meta?).to be(true)
          expect(e.raw).to eq([27, "f"])
        end

        it "decodes meta-known-key when raw is [27, code]" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode([27, 260])

          expect(e.key).to eq(:left)
          expect(e.meta?).to be(true)
          expect(e.text).to be_nil
          expect(e.raw).to eq([27, 260])
        end

        it "decodes meta-unknown-key when raw is [27, code]" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode([27, 999])

          expect(e.key).to eq(999)
          expect(e.meta?).to be(true)
          expect(e.raw).to eq([27, 999])
        end

        it "decodes NUL (0) as ctrl-@ with key :@ and no text" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(0)

          expect(e.key).to eq(:'@')
          expect(e.ctrl?).to be(true)
          expect(e.meta?).to be(false)
          expect(e.text).to be_nil
          expect(e.raw).to eq(0)
        end

        it "decodes meta-ctrl-@ when raw is [27, 0]" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode([27, 0])

          expect(e.key).to eq(:'@')
          expect(e.ctrl?).to be(true)
          expect(e.meta?).to be(true)
          expect(e.text).to be_nil
          expect(e.raw).to eq([27, 0])
        end

        it "decodes unknown integer as integer key with no text" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)

          kd = KeyDecoder.new(env: env)
          e  = kd.decode(999)

          expect(e.key).to eq(999)
          expect(e.text).to be_nil
          expect(e.raw).to eq(999)
          expect(e.coded?).to be(false)
        end

        it "provides text for printable ASCII even when a keydef maps the integer code" do
          decoder = Fatty::Curses::KeyDecoder.new(env: { terminal: :test })
          # Simulate a user keydef that maps 97 ("a") to a KeyEvent without text.
          decoder.instance_variable_set(:@map, { 97 => Fatty::KeyEvent.new(key: :a, raw: 97) })

          ev = decoder.decode(97)

          expect(ev.key).to eq(:a)
          expect(ev.text).to eq("a")
          expect(ev.ctrl?).to be(false)
          expect(ev.meta?).to be(false)
        end
      end

      describe "user keydefs override" do
        it "overrides built-in map for the current terminal" do
          stub_builtin_map

          allow(Fatty::Config)
            .to receive(:keydefs)
                  .and_return(
                    {
                      terminal: {
                        xterm: {
                          map: {
                            "260" => { "key" => "right" }, # swap left->right
                          },
                        },
                      },
                    },
                  )
          kd = KeyDecoder.new(env: env(:xterm))
          e  = kd.decode(260)
          expect(e.key).to eq(:right)
        end

        it "ignores config if terminal section is missing" do
          stub_builtin_map
          allow(Fatty::Config).to receive(:keydefs).and_return({ terminal: {} })

          kd = KeyDecoder.new(env: env(:xterm))
          e  = kd.decode(260)

          expect(e.key).to eq(:left) # built-in remains
        end

        it "normalizes spec key string to symbol" do
          stub_builtin_map

          allow(Fatty::Config)
            .to receive(:keydefs)
                  .and_return(
                    {
                      terminal: {
                        xterm: {
                          map: {
                            "999" => { "key" => "home", "shift" => true, "ctrl" => false },
                          },
                        },
                      },
                    },
                  )

          kd = KeyDecoder.new(env: env(:xterm))
          e  = kd.decode(999)

          expect(e.key).to eq(:home)
          expect(e.shift?).to be(true)
          expect(e.ctrl?).to be(false)
        end

        it "applies modifiers from user keydefs spec" do
          stub_builtin_map

          allow(Fatty::Config)
            .to receive(:keydefs)
                  .and_return(
                    {
                      terminal: {
                        xterm: {
                          map: {
                            "260" => { "key" => "left", "ctrl" => true, "shift" => true },
                          },
                        },
                      },
                    },
                  )

          kd = KeyDecoder.new(env: env(:xterm))
          e  = kd.decode(260)

          expect(e.key).to eq(:left)
          expect(e.ctrl?).to be(true)
          expect(e.shift?).to be(true)
          expect(e.meta?).to be(false)
          expect(e.text).to be_nil
        end

        it "allows user keydefs to remap tab code to another action key" do
          stub_builtin_map

          allow(Fatty::Config)
            .to receive(:keydefs)
                  .and_return(
                    {
                      terminal: {
                        xterm: {
                          map: {
                            "9" => { "key" => "right" },
                          },
                        },
                      },
                    },
                  )

          kd = KeyDecoder.new(env: env(:xterm))
          e  = kd.decode(9)

          expect(e.key).to eq(:right)
          expect(e.text).to be_nil
        end
      end
    end
  end
end
