# Carnival of Consructs

These are samples of the kinds of constructs the ANSI renderer for `fatty` are capable of.


## Unordered Lists

-   builtin commands are handled by the `fatty` demo, Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
-   other commands are handled by `/bin/sh`
-   keybindings are listed below


## Ordered Lists

1.  builtin commands are handled by the `fatty` demo, Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
2.  other commands are handled by `/bin/sh`
3.  keybindings are listed below


## Description Lists

-   **bold:** **this text is bold**
-   **italic:** *this text is italic*
-   **code:** `this text is code`
-   **verbatim:** `this text is verbatim`
-   **strike:** ~~this text is strike-through~~

```ruby
    def wrap(text, first_prefix: "", rest_prefix: first_prefix)
      width = [@width.to_i, 20].max

      words = text.to_s.split(/\s+/)
      lines = []
      line = +""

      words.each do |word|
        prefix = lines.empty? ? first_prefix : rest_prefix
        available = width - Fatty::Ansi.visible_length(prefix)
        available = 20 if available < 20

        candidate = line.empty? ? word : "#{line} #{word}"

        if Fatty::Ansi.visible_length(candidate) > available && !line.empty?
          lines << "#{prefix}#{line}"
          line = word.dup
        else
          line = candidate
        end
      end

      unless line.empty?
        prefix = lines.empty? ? first_prefix : rest_prefix
        lines << "#{prefix}#{line}"
      end

      lines.join("\n")
    end
```
