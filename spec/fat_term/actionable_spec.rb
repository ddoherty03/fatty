# frozen_string_literal: true

module FatTerm
  RSpec.describe Actionable do
    around do |ex|
      saved = FatTerm::Actions.snapshot
      begin
        FatTerm::Actions.reset!
        ex.run
      ensure
        FatTerm::Actions.restore(saved)
      end
    end

    def defn(name)
      FatTerm::Actions.lookup(name)
    end

    describe "action class method" do
      it "defines an instance method when action is given a block" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :__t_insert do |str|
            @text ||= +""
            @text << str
          end

          def text
            @text ||= +""
          end
        end

        obj = klass.new
        obj.__t_insert("a")
        obj.__t_insert("b")
        expect(obj.text).to eq("ab")
      end

      it "registers an action and dispatches it via Actions.call" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :__t_bol do
            @cursor = 0
          end

          def cursor = @cursor
        end

        expect(defn(:__t_bol)).to include(owner: klass, on: :buffer, method: :__t_bol)

        buf = klass.new
        buf.instance_variable_set(:@cursor, 5)
        ctx = ActionEnvironment.new(buffer: buf)

        FatTerm::Actions.call(:__t_bol, ctx)
        expect(buf.cursor).to eq(0)
      end

      it "registers an alias action name to a different method with to:" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          def move_left
            :ok
          end

          action :backward_char, to: :move_left
        end

        expect(defn(:backward_char)).to include(owner: klass, on: :buffer, method: :move_left)
        expect(klass.new.backward_char).to eq(:ok)
      end

      it "supports alias form: action :set, to: :replace defines #set and registers action" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :replace do |str|
            @text = str.dup
          end

          action :set, to: :replace

          def text = @text
        end

        obj = klass.new
        obj.set("hello")
        expect(obj.text).to eq("hello")

        ctx = ActionEnvironment.new(buffer: obj)
        FatTerm::Actions.call(:set, ctx, "world")
        expect(obj.text).to eq("world")
      end

      it "registers an action and defines the underlying method when given a block" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :bol do
            @cursor = 0
          end

          attr_reader :cursor
        end

        expect(defn(:bol)).to include(owner: klass, on: :buffer, method: :bol)

        obj = klass.new
        obj.bol
        expect(obj.cursor).to eq(0)
      end

      it "uses on: to select the target in ctx" do
        buffer_klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :__t_buf_mark do
            @marked = true
          end

          def marked? = !!@marked
        end

        field_klass = Class.new do
          include FatTerm::Actionable

          action_on :field

          action :__t_field_mark, on: :field do
            @marked = true
          end

          def marked? = !!@marked
        end

        buf = buffer_klass.new
        fld = field_klass.new
        ctx = ActionEnvironment.new(buffer: buf, field: fld)

        FatTerm::Actions.call(:__t_buf_mark, ctx)
        FatTerm::Actions.call(:__t_field_mark, ctx)

        expect(buf.marked?).to be(true)
        expect(fld.marked?).to be(true)
      end

      it "desc applies to the next action only and then resets" do
        Class.new do
          include FatTerm::Actionable

          action_on :buffer

          desc "first doc"
          action :__t_first do
          end
          action :__t_second do
          end
        end

        first  = FatTerm::Actions.lookup(:__t_first)
        second = FatTerm::Actions.lookup(:__t_second)
        first_doc =
          first.respond_to?(:doc) ? first.doc : first[:doc]
        second_doc =
          second.respond_to?(:doc) ? second.doc : second[:doc]

        expect(first_doc).to eq("first doc")
        expect(second_doc).to be_nil
      end

      it "uses desc() as the doc for the next action and consumes it" do
        Class.new do
          include FatTerm::Actionable

          action_on :buffer

          desc "beginning of line"
          action :bol do
            :ok
          end

          action :eol do
            :ok
          end
        end

        expect(defn(:bol)[:doc]).to eq("beginning of line")
        expect(defn(:eol)[:doc]).to be_nil
      end

      it "action doc: kwarg is used when no desc is provided" do
        Class.new do
          include FatTerm::Actionable

          action_on :buffer

          action :__t_doc_kw, doc: "kw doc" do
          end
        end
        entry = FatTerm::Actions.lookup(:__t_doc_kw)
        doc =
          entry.respond_to?(:doc) ? entry.doc : entry[:doc]

        expect(doc).to eq("kw doc")
      end

      it "infers default action target from class name, including special cases" do
        # special-cased name -> :buffer
        Class.new do
          include FatTerm::Actionable

          def self.name = "FatTerm::InputBuffer"
          action :bol do
            :ok
          end
        end

        expect(defn(:bol)[:on]).to eq(:buffer)

        # generic CamelCase -> snake_case
        Class.new do
          include FatTerm::Actionable

          def self.name = "FatTerm::FooBar"
          action :zap do
            :ok
          end
        end

        expect(defn(:zap)[:on]).to eq(:foo_bar)
      end

      it "unknown action raises" do
        ctx = ActionEnvironment.new(buffer: Object.new)
        expect { FatTerm::Actions.call(:__t_no_such_action, ctx) }.to raise_error(ActionError)
      end

      it "alias can be declared before the target method (delegator fallback)" do
        klass = Class.new do
          include FatTerm::Actionable

          action_on :buffer

          # alias first
          action :__t_set, to: :__t_replace

          # define later
          action :__t_replace do |str|
            @text = str.dup
          end

          def text = @text
        end

        obj = klass.new
        obj.__t_set("x")
        expect(obj.text).to eq("x")
      end
    end
  end
end
