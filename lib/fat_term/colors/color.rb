# frozen_string_literal: true

module FatTerm
  module Color
    DEFAULT_INDEX = -1

    # Expected location for a bundled X11 rgb.txt (you provide it in the repo).
    # Recommended path:
    #   lib/fat_term/color/rgb.txt
    RGB_TXT_PATH = File.expand_path("rgb.txt", __dir__)

    # ANSI 0..15 names (de-facto standard names)
    ANSI_NAMES = {
      "black"          => 0,
      "red"            => 1,
      "green"          => 2,
      "yellow"         => 3,
      "blue"           => 4,
      "magenta"        => 5,
      "cyan"           => 6,
      "white"          => 7,
      "bright_black"   => 8,
      "bright_red"     => 9,
      "bright_green"   => 10,
      "bright_yellow"  => 11,
      "bright_blue"    => 12,
      "bright_magenta" => 13,
      "bright_cyan"    => 14,
      "bright_white"   => 15,
      "gray"           => 8,
      "grey"           => 8,
      "bright_gray"    => 15,
      "bright_grey"    => 15,
      "default"        => DEFAULT_INDEX,
    }.freeze

    # Small alias set (xterm-256 indices). Keep this small + opinionated.
    # Users can always use integers/hex/X11 names.
    ALIASES_256 = {
      "navy"       => 17,
      "dark_blue"  => 18,
      "orange"     => 208,
      "pink"       => 205,
      "violet"     => 141,
      "sky"        => 117,
      "teal"       => 37,
      "lime"       => 118,
      "dark_grey"  => 238,
      "dark_gray"  => 238,
      "grey"       => 244,
      "gray"       => 244,
      "light_grey" => 250,
      "light_gray" => 250,
    }.freeze

    # Approximate RGB for xterm-style ANSI 0..15.
    # Used only when down-mapping to <=16 colors.
    ANSI_RGB = {
      0  => [0, 0, 0],
      1  => [205, 0, 0],
      2  => [0, 205, 0],
      3  => [205, 205, 0],
      4  => [0, 0, 238],
      5  => [205, 0, 205],
      6  => [0, 205, 205],
      7  => [229, 229, 229],
      8  => [127, 127, 127],
      9  => [255, 0, 0],
      10 => [0, 255, 0],
      11 => [255, 255, 0],
      12 => [92, 92, 255],
      13 => [255, 0, 255],
      14 => [0, 255, 255],
      15 => [255, 255, 255],
    }.freeze

    # Resolve a color specification to an integer color index suitable for curses init_pair.
    #
    # Accepts:
    # - Integer (e.g. 17, 226, -1)
    # - ANSI name (e.g. "yellow", "bright_blue", "default")
    # - Alias (e.g. "navy")
    # - Hex string (#RRGGBB or #RGB)
    # - X11 name (e.g. "MidnightBlue") resolved via bundled rgb.txt
    #
    # available_colors:
    # - If <= 16, any resolved 256-color index is down-mapped to nearest ANSI 0..15.
    # - If > 16, returns xterm-256 indices 0..255 (or -1 for default).
    def self.resolve(spec, available_colors: 256)
      spec_norm = spec

      idx =
        if spec_norm.is_a?(Integer)
          spec_norm
        elsif spec_norm.nil?
          DEFAULT_INDEX
        else
          resolve_stringish(spec_norm.to_s, available_colors: available_colors)
        end

      if idx == DEFAULT_INDEX
        idx
      else
        clamp_index(idx, available_colors: available_colors)
      end
    end

    def self.resolve_stringish(str, available_colors: 256)
      s = normalize_name(str)
      # Disambiguation prefixes:
      # - "ansi:yellow" forces ANSI 0..15 names
      # - "x11:yellow" forces X11 rgb.txt lookup
      #
      # Without a prefix, prefer X11 names when 256 colors are available so
      # common names like "yellow" match X11 "#FFFF00" rather than ANSI 3.
      mode = nil
      if s.start_with?("ansi:")
        mode = :ansi
        s = s.delete_prefix("ansi:")
      elsif s.start_with?("x11:")
        mode = :x11
        s = s.delete_prefix("x11:")
      end

      idx = ALIASES_256[s]
      return idx unless idx.nil?

      rgb = parse_hex(s)
      return xterm_index_for_rgb(rgb[0], rgb[1], rgb[2]) if rgb

      prefer_x11 = (mode == :x11) || (mode.nil? && available_colors.to_i >= 256)

      if prefer_x11
        rgb2 = x11_rgb_for_name(s)
        return xterm_index_for_rgb(rgb2[0], rgb2[1], rgb2[2]) if rgb2
      end

      idx = ANSI_NAMES[s]
      return idx unless idx.nil?

      unless prefer_x11
        rgb2 = x11_rgb_for_name(s)
        return xterm_index_for_rgb(rgb2[0], rgb2[1], rgb2[2]) if rgb2
      end

      # Unknown name: treat as default.
      DEFAULT_INDEX
    end

    def self.normalize_name(str)
      # normalize spaces/underscores/hyphens and case, so:
      # "Light Sky Blue" == "light_sky_blue" == "lightskyblue"
      s = str.to_s.strip.downcase
      s = s.tr("-", "_")
      s = s.gsub(/\s+/, "")
      s
    end

    def self.parse_hex(s)
      # Accept "#rgb" or "#rrggbb"
      hex = s
      if hex.start_with?("#")
        hex = hex[1..]
      end

      if hex.match?(/\A[0-9a-f]{3}\z/i)
        r = (hex[0] * 2).to_i(16)
        g = (hex[1] * 2).to_i(16)
        b = (hex[2] * 2).to_i(16)
        [r, g, b]
      elsif hex.match?(/\A[0-9a-f]{6}\z/i)
        r = hex[0, 2].to_i(16)
        g = hex[2, 2].to_i(16)
        b = hex[4, 2].to_i(16)
        [r, g, b]
      end
    end

    def self.clamp_index(idx, available_colors:)
      max = available_colors.to_i - 1
      max = 0 if max < 0

      i = idx.to_i

      if available_colors.to_i <= 16
        downmap_to_ansi16(i)
      else
        if i < 0
          0
        elsif i > 255
          255
        else
          i
        end
      end
    end

    # Convert any RGB to an xterm-256 index (16..255).
    # We consider both the 6x6x6 cube and the grayscale ramp and pick the closer.
    def self.xterm_index_for_rgb(r, g, b)
      rr = clamp_byte(r)
      gg = clamp_byte(g)
      bb = clamp_byte(b)

      cube = xterm_cube_index(rr, gg, bb)
      gray = xterm_gray_index(rr, gg, bb)

      cube_rgb = xterm_rgb_for_index(cube)
      gray_rgb = xterm_rgb_for_index(gray)

      if dist2(rr, gg, bb, gray_rgb[0], gray_rgb[1], gray_rgb[2]) <
         dist2(rr, gg, bb, cube_rgb[0], cube_rgb[1], cube_rgb[2])
        gray
      else
        cube
      end
    end

    def self.xterm_cube_index(r, g, b)
      levels = [0, 95, 135, 175, 215, 255]
      ri = nearest_index(levels, r)
      gi = nearest_index(levels, g)
      bi = nearest_index(levels, b)
      16 + (36 * ri) + (6 * gi) + bi
    end

    def self.xterm_gray_index(r, g, b)
      # grayscale ramp 232..255 maps to levels 8 + 10*n
      avg = (r + g + b) / 3
      if avg < 8
        16 # near black; keep in extended palette, not ANSI black
      elsif avg > 238
        231 # near white; a cube white
      else
        n = ((avg - 8) / 10.0).round
        n = 0 if n < 0
        n = 23 if n > 23
        232 + n
      end
    end

    def self.xterm_rgb_for_index(idx)
      i = idx.to_i

      if i >= 232 && i <= 255
        v = 8 + (i - 232) * 10
        [v, v, v]
      elsif i >= 16 && i <= 231
        j = i - 16
        r = j / 36
        g = (j % 36) / 6
        b = j % 6
        levels = [0, 95, 135, 175, 215, 255]
        [levels[r], levels[g], levels[b]]
      else
        # for 0..15 we use ANSI_RGB as an approximation
        ANSI_RGB[i] || [0, 0, 0]
      end
    end

    def self.downmap_to_ansi16(idx)
      if idx == DEFAULT_INDEX
        DEFAULT_INDEX
      elsif idx >= 0 && idx <= 15
        idx
      else
        rgb = xterm_rgb_for_index(idx)
        nearest_ansi_index(rgb[0], rgb[1], rgb[2])
      end
    end

    def self.nearest_ansi_index(r, g, b)
      best = 0
      best_d = nil

      ANSI_RGB.each do |i, rgb|
        d = dist2(r, g, b, rgb[0], rgb[1], rgb[2])
        if best_d.nil? || d < best_d
          best_d = d
          best = i
        end
      end

      best
    end

    def self.nearest_index(levels, value)
      v = value.to_i
      best_i = 0
      best_d = nil

      levels.each_with_index do |lvl, i|
        d = (lvl - v).abs
        if best_d.nil? || d < best_d
          best_d = d
          best_i = i
        end
      end

      best_i
    end

    def self.clamp_byte(v)
      x = v.to_i
      x = 0 if x < 0
      x = 255 if x > 255
      x
    end

    def self.dist2(r1, g1, b1, r2, g2, b2)
      dr = r1 - r2
      dg = g1 - g2
      db = b1 - b2
      (dr * dr) + (dg * dg) + (db * db)
    end

    def self.x11_rgb_for_name(name_norm)
      table = x11_table
      table[name_norm]
    end

    def self.x11_table
      @x11_table ||= load_x11_rgb_txt(RGB_TXT_PATH)
    end

    def self.load_x11_rgb_txt(path)
      table = {}

      if File.file?(path)
        File.foreach(path) do |line|
          next if line.strip.empty?
          next if line.lstrip.start_with?("!")

          # Format: R G B <name...>
          parts = line.strip.split(/\s+/)
          next if parts.length < 4

          r = parts[0].to_i
          g = parts[1].to_i
          b = parts[2].to_i
          name = parts[3..].join(" ")
          key = normalize_name(name)
          table[key] = [r, g, b]
        end
      end

      table
    end
  end
end
