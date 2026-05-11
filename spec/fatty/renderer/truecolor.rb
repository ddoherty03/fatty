module Fatty
  class TruecolorSpecWindow
    attr_reader :maxx, :maxy, :writes

    def initialize(maxx: 12, maxy: 1, origin: [0, 0])
      @maxx = maxx
      @maxy = maxy
      @origin = origin
      @writes = []
    end

    def origin
      @origin
    end

    def bkgdset(attr) = @writes << [:bkgdset, attr]
    def erase = @writes << [:erase]
    def attrset(attr) = @writes << [:attrset, attr]
    def setpos(row, col) = @writes << [:setpos, row, col]
    def addstr(text) = @writes << [:addstr, text]
    def noutrefresh = @writes << [:noutrefresh]
  end

  class TruecolorSpecContext
    attr_reader :status_win, :output_win, :input_win, :alert_win
    attr_reader :palette, :truecolor

    def initialize(truecolor:)
      @truecolor = truecolor

      @status_win = TruecolorSpecWindow.new(maxx: 12, maxy: 1, origin: [9, 0])
      @output_win = TruecolorSpecWindow.new(maxx: 12, maxy: 8, origin: [0, 0])
      @input_win = TruecolorSpecWindow.new(maxx: 12, maxy: 1, origin: [8, 0])
      @alert_win = TruecolorSpecWindow.new(maxx: 12, maxy: 1, origin: [9, 0])

      @palette = {
        status: {
          pair: 2,
          fg_rgb: [255, 255, 255],
          bg_rgb: [0, 0, 80],
          attrs: [],
        },
        good: {
          pair: 1,
          fg_rgb: [0, 0, 0],
          bg_rgb: [240, 248, 255],
          attrs: [],
        },
        output: { pair: 3, fg_rgb: [255, 255, 255], bg_rgb: [0, 0, 0], attrs: [] },
        input:  { pair: 4, fg_rgb: [255, 255, 255], bg_rgb: [0, 0, 0], attrs: [] },
        info:   { pair: 5, fg_rgb: [255, 255, 255], bg_rgb: [0, 0, 0], attrs: [] },
      }
    end
  end

  RSpec.describe Color do
    it "renders a truecolor status overlay when truecolor is enabled" do
      screen = Fatty::Screen.new(rows: 10, cols: 12, status_rows: 1)
      context = TruecolorSpecContext.new(truecolor: true)

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      allow(::Curses).to receive(:color_pair).and_return(0)

      renderer = Fatty::Renderer::Truecolor.new(
        context: context,
        screen: screen,
        palette: context.palette,
      )

      renderer.begin_frame
      renderer.render_status("good hello", role: :good)

      pending = renderer.instance_variable_get(:@pending_ansi_draws)
      expect(pending.length).to eq(1)

      draw = pending.first
      expect(draw[:row]).to eq(screen.status_rect.row)
      expect(draw[:col]).to eq(screen.status_rect.col)
      expect(draw[:width]).to eq(screen.status_rect.cols)
      expect(draw[:text]).to eq("good hello")
      expect(draw[:spec][:fg_rgb]).to eq([0, 0, 0])
      expect(draw[:spec][:bg_rgb]).to eq([0, 0, 80])

      renderer.finish_frame

      expect(out.string).to include("38;2;0;0;0")
      expect(out.string).to include("48;2;0;0;80")
      expect(out.string).to include("good hello")
    ensure
      $stdout = original_stdout
    end
  end
end
