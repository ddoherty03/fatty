- [Introduction](#orgb68fb47)
- [Quick Start](#org50e1cc4)
  - [Installing](#org0a7054b)
  - [Trying it Out with the \`fatty\` Demo](#org15bd3b0)
    - [Builtin commands](#orgb57e388)
    - [Screenshots](#orgda569a2)
- [Usage](#orgac624f0)
  - [Launching a Fatty Terminal](#org3d4daaf)
    - [`on_accept`](#org6de319c)
    - [Other parameters to `Terminal.new`](#orga944390)
  - [The Callback API](#orgaf2b2a8)
    - [`append(text, follow: true)`](#orgffeedd8)
    - [`append_now(text, follow: true)`](#org6ef8df0)
    - [`markdown(text)`](#org8c667db)
    - [`status(text, role: :info)`](#orge943a9a)
    - [`good(text)`](#org92b4405)
    - [`info(text)`](#orga373bc9)
    - [`warn(text)`](#orga812595)
    - [`error(text)`](#orge27e09a)
    - [`oops(text)`](#org9fba7ce)
    - [`alert(text, role: :info)`](#orgf558347)
    - [`prompt(prompt, initial: "", cancel_value: nil, history_key: nil, save_history: true)`](#org9dfef73)
    - [`add_progress(label:, total: nil, style: :percent, role: :info, width: 40)`](#orge6891ad)
    - [`choose(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`](#orga9c88fe)
    - [`choose_multi(prompt, choices:, cancel_value: nil)`](#org8ae4976)
    - [`confirm(prompt, yes_label: "Yes", no_label: "No", cancel_value: false)`](#org560df15)
    - [`menu(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`](#org64d2c3d)
    - [`environment`](#orge474630)
- [Default Interaction](#org6404575)
  - [Parts of the Screen](#org1abaacf)
    - [Input Field](#orgbb0692f)
    - [Output Pane](#org401bb99)
    - [Status Area](#orgc26e524)
    - [Alert  Area](#org2d2fa91)
  - [Command-line Editing](#org7090550)
  - [Keybindings](#org5b9771f)
    - [Input Context](#org44ce39d)
    - [Paging Context](#org04b24c6)
  - [Markdown](#org4a236fa)
    - [Forced line breaks](#org546d253)
  - [History](#org378aeb8)
  - [Completion](#org54f6da5)
    - [From the `completion_proc`](#org99dcd04)
    - [From History](#orge274370)
    - [From partial filenames](#orgf1d41e6)
- [Configuration](#orgb04a838)
  - [General Configuration `config.yml`](#orga6c6d2d)
    - [`word_char_re`](#orgc790827)
    - [`esc_delay`](#org6413a1c)
    - [`history`](#org1dfa5e0)
    - [`theme`](#org3c40aca)
    - [`truecolor`](#orgd68b975)
    - [`log`](#org61e33b0)
  - [Key code definitions `keydefs.yml`](#orgc8a783a)
  - [Key bindings  `keybindings.yml`](#orgf938edb)
    - [Key Names](#orgca2c4fd)
    - [Mouse Events](#org58b466e)
    - [Modifiers](#org11be0fd)
    - [Contexts](#org178df34)
    - [Actions](#orgcb0c617)
  - [Themes `themes/`](#orgb3fbff4)
    - [Distributed Themes](#org490854a)
    - [Custom Themes](#orga1c6598)
  - [Plugins](#orga5dda0b)



<a id="orgb68fb47"></a>

# Introduction

`Fatty` aims to provide a full-featured command-line environment that provides:

1.  an emacs-like editing command-line input, including undo/redo and kill/yank
2.  a history facility,
3.  command completion,
4.  completion of partially-typed file path names,
5.  output into a paging environment,
6.  searching within the paged output,
7.  issuing messages to a "status" area separate from the output pane,
8.  binding keys to pre-defined actions,
9.  defining unrecognized key-codes as named keys,
10. color themes that can be selected in real time,
11. a way to define new themes,
12. processing completed command lines with a callback procedure of your choosing,
13. several user-interface widgets such a selection popups, text prompts, menus, progress bars, etc.,
14. a set of progress indicators you can use to display to the end user,
15. a way to render markdown to the output pane,

In other words, fatty allows you to write a terminal-based REPL of your choosing but takes care of all the difficult parts.

`Fatty` is written entirely in Ruby and was born from my frustrations at the limitations of libraries like `readline` and `reline`. It relies on `curses` and `truecolor` for low-level rendering and is surprisingly snappy.

`Fatty` is *not* a terminal emulator but runs on top of one.


<a id="org50e1cc4"></a>

# Quick Start


<a id="org0a7054b"></a>

## Installing

`Fatty` is a ruby gem, so it can be installed with

```sh
$ gem install fatty
```


<a id="org15bd3b0"></a>

## Trying it Out with the \`fatty\` Demo

Once installed, you can try out `fatty` with the included program called `fatty`. It allows you to easily exercise all of the important features of the `fatty` library. At a normal shell prompt simply type `fatty`, and it will launch the `fatty` demo program.

Once inside `fatty` you will be prompted with a prompt that names your current directory. Type `help` to get a summary of the builtin commands available to you. If you type anything other than a builtin command, `fatty` attempts to run it as a shell command and displays the output.


<a id="orgb57e388"></a>

### Builtin commands

Here are the commands builtin to `fatty`

| Command                      | Description                                                             |
|---------------------------- |----------------------------------------------------------------------- |
| help                         | Display this file on the output pane                                    |
| cd                           | Change the current directory used by the shell                          |
| choose                       | Present a series of choices in a popup window                           |
| choosevals                   | Also present choices in a popup window but return an associated value   |
| choose\_multi                | Present choices with a "checkbox" for selecting multiple values         |
| choosevals\_multi            | Also present a checkbox but return associated values                    |
| menu                         | Present a menu of labeled routines to run                               |
| info                         | Display an "info" message on the status line                            |
| good                         | Display a "good" message colored to indicate success                    |
| warn                         | Display a "warn" message colored to indicate caution                    |
| oops                         | Display an "oops" message colored to indicate failure                   |
| prompt                       | Popup a text box for entering a value in response to a prompt           |
| progress count <N>           | Display an animated progress indicator counting up to 40 or the given N |
| progress percent <N>         | Same but also show the percent complete                                 |
| progress simple\_percent <N> | Same but show only the percent complete                                 |
| progress trail               | Show progress by displaying an "indicator" character for each step      |
| progress bar                 | Show progress by a filling bar using ASCII characters                   |
| progress unicode\_bar        | Same, but using unicode characters                                      |
| progress braille\_bar        | Same, but using braille characters                                      |
| progress spinner             | Animate a "spinner" showing a busy state                                |
| markdown <file.md>           | Render the markdown file to the output pane; defaults to a demo file    |
| keytest                      | Enter key diagnostic mode report keycodes, key names, and bindings      |
| colors                       | Display ANSI, 256-color, and X11 color diagnostics                      |


<a id="orgda569a2"></a>

### Screenshots

1.  Command line editing

    Here is the command line, mid-edit showing a region selected and, in dim text to the right, a predictive completion based on history.
    
    ![img](images/input_editing.png "Input editing showing region and predictive completion.")

2.  Searchable Output

    While paging output, you can search for words, as here the user searches for the word `tty` in the output. The current match is highlighted in yellow with other matches highlighted in gray. The paging status line shows the search term and the direction of search. The user can navigate for other matches in the output using `n` and `N`.
    
    ![img](images/search_output.png "Searching for instances of `tty` in the output.")

3.  Paging Markdown

    The `fatty` demo running the `markdown` command and paging the output. It shows `fatty's` ability to render markdown using ANSI codes, including colorizing code blocks, as well as its paging interface.
    
    ![img](images/page_markdown.png "Running the `fatty` demo `markdown` command.")

4.  Popup Selection

    One of the many "widgets" available through `fatty` is the ability to present the user with a set of choices to select from. After running the demo's `choose "AAA" "BBB" "CCC" "DDD" "EEE"`
    
    ![img](images/choose_popup.png "Running the `fatty` demo `choose` command.")


<a id="orgac624f0"></a>

# Usage


<a id="org3d4daaf"></a>

## Launching a Fatty Terminal


<a id="org6de319c"></a>

### `on_accept`

You can launch a `Fatty` terminal session that does arbitrary processing of an edited command line and returns a String to be displayed on the output pane by providing an `on_accept` proc as a parameter as shown in this file that we'll call `loudrev`:

```ruby
#! /usr/bin/env ruby
# -*- mode: ruby -*-

require 'fatty'

loud_reversal = lambda do |line|
  line.upcase.reverse
end

Fatty::Terminal.new(
  on_accept: loud_reversal,
).go
```

Now you have an interactive application that allows you to type text and see what it looks like when written backwards in uppercase letters. It's as easy as that!

Text passed to the output pane, the status area, and the alert pane may contain ANSI SGR color/style sequences. Fatty interprets those sequences relative to the current theme and role, so an ANSI reset returns to the active Fatty role rather than to the terminal's physical default colors. `fatty` includes the nice [`Rainbow` gem](https://github.com/ku1ik/rainbow) for colorizing text as a convenience.

When a `fatty` application runs, `fatty` installs a few files if they do not exists:

-   a history file at `~/.fatty_history`
-   a config directory at `~/.config/fatty` that contains
    -   `config.yml`, the main configuration file
    -   `keydefs.yml`, a file for associating keycodes emitted by the underlying terminal with names when curses does not do so automatically,
    -   `keybindings.yml`, a file for associating named keys with actions above and beyond the emacs bindings that are used by default, and
    -   `themes`, a directory of pre-defined theme definitions that you can choose from and add to by adding your own themes.

1.  Parameters to `on_accept`

    The `on_accept` proc passed to an instance of `Fatty::Terminal` can take one or two parameters: (1) `line`, the edited line as it exists when the user types `RETURN` and (2) an optional callback parameter that you can use to access the facilities of `fatty`.

2.  The `line` parameter to `on_accept`

    `Fatty` does not parse command lines for your application. When the user accepts a `line`, `Fatty` passes the line to `on_accept` as text. It is up to your callback to decide whether to strip whitespace, split words, interpret quotes, parse options, recognize subcommands, or treat punctuation specially.
    
    This keeps `Fatty` useful for many different kinds of REPLs. Some applications want shell-like parsing. Others want to preserve the user's input exactly.
    
    For shell-like parsing, Ruby's standard `Shellwords` library is often useful:
    
    ```ruby
    #! /usr/bin/env ruby
    # -*- mode: ruby -*-
    
    require 'fatty'
    require 'shellwords'
    
    runner = lambda do |line, fatty|
      words = Shellwords.split(line)
    
      case words
      when ["echo", *rest]
        fatty.append("#{rest.join(" ")}\n")
      when ["count", *rest]
        fatty.append("#{rest.length}\n")
      when []
        fatty.status("Blank line", role: :info)
      else
        fatty.alert("Unknown command: #{words.first}", role: :warn)
      end
    rescue ArgumentError => e
      fatty.alert("Could not parse line: #{e.message}", role: :error)
    end
    
    Fatty::Terminal.new(
      prompt: "shellwords> ",
      on_accept: runner,
    ).go
    ```

3.  The callback parameter to `on_accept`

    The `on_accept` proc can have a second parameter named whatever you like that serves as a callback into certain facilities provided by `fatty`. In this README we use the name `fatty` for the callback parameter since it provides access to the facilities provided by the `fatty` library. Here is a variation of the prior example that also echoes the original typed string into the so-called status area:
    
    ```ruby
    #! /usr/bin/env ruby
    # -*- mode: ruby -*-
    
    require 'fatty'
    
    loud_reversal = lambda do |line, fatty|
      fatty.good(line)
      line.upcase.reverse
    end
    
    Fatty::Terminal.new(
      on_accept: loud_reversal,
    ).go
    ```
    
    The callback parameter responds to several methods that allow your application to interact with the user. They are documented below.

4.  Output Ordering

    The `on_accept` callback can send text to the output pane in three ways:
    
    1.  by returning a value from the callback;
    2.  by calling `append` or `markdown` on the callback environment; or
    3.  by calling `append_now` on the callback environment.
    
    A returned `String` is the simplest output mechanism. It is displayed after the callback finishes:
    
    ```ruby
    Fatty::Terminal.new(
      on_accept: ->(line) { line.upcase.reverse },
    ).go
    ```
    
    Calls to `append` and `markdown` also queue output until the callback finishes. If a callback both calls `append` or `markdown` and returns a `String`, the queued output is displayed first and the returned string is displayed after it.
    
    Calls to `append_now` are different. They append text and immediately render a frame, so the user can see output while the callback is still running. Use `append_now` for long-running callbacks that should stream progress to the output pane.
    
    At the end of the callback, `Fatty` finishes the command and updates the pager state. Output produced with `append_now` may therefore appear during the callback, while output from `append`, `markdown`, and the callback's return value appears after the callback returns.

5.  ANSI Colors in Output

    Text passed to `append`, `append_now`, `status`, and `alert` may contain ANSI SGR color/style sequences. Fatty interprets those sequences relative to the current theme role, so an ANSI reset returns to the active Fatty role rather than to the terminal's physical default colors. `fatty` includes the nice [`Rainbow` gem](https://github.com/ku1ik/rainbow) for colorizing text as a convenience.


<a id="orga944390"></a>

### Other parameters to `Terminal.new`

When building a REPL with `Terminal.new` you can also supply several other parameters:

-   **`prompt:`:** a `String` or a zero-argument callable such as a `Proc` or `lambda` that returns the prompt used for the input line to be edited. Because it can be a callable, it can change after each run of `on_accept`; if not given, it defaults to '> ';
-   **`app_name`:** the name for the "app" using the `fatty` library; this allows app-specific configuration under `~/.config/fatty/apps/<app_name>` or a different directory specified by `app_config_dir`;
-   **`app_config_dir`:** an alternative directory for app-specific configuration instead of the default;
-   **`completion_proc`:** a callable that takes the current text of the input field's buffer and returns an `Array` of possible completions at that point in the input; by default, there is no completion proc;
-   **`history_path`:** a `String` for the file path where command history is loaded from and saved. The default, `:default`, uses `history.file` from Fatty's configuration, falling back to `~/.fatty_history` if no history file is configured. Passing `nil` or `false` disables persistent history and keeps history in memory only. Passing a string uses that path directly.
-   **`history_ctx`:** optional history context used to prefer relevant history entries. It may be a hash or a callable returning a hash. The context is stored in the history file with each accepted line and is used by history navigation and history autosuggestions. Matching context entries are preferred, but history is not strictly partitioned; Fatty can still fall back to other entries. This is useful when the same application wants different history behavior in different directories, ledgers, projects, modes, or accounts.

For example, the `fatty` demo executable uses the current working directory as history context:

```ruby
Fatty::Terminal.new(
history_ctx: -> { { pwd: Dir.pwd } },
on_accept: ->(line, env) {
# ...
},
).go
```

With that setup, commands entered in `~/src/byr` are favored when the terminal is again in `~/src/byr`, while commands entered elsewhere remain available as fallback history.


<a id="orgaf2b2a8"></a>

## The Callback API

Here are the details on the messages that you can send to the callback parameter to the `on_accept` proc.


<a id="orgffeedd8"></a>

### `append(text, follow: true)`

Add the given text to the output pane. After a full page of output is produced, enter paging mode so the user can view the output at leisure and search the output. If `follow` is true, keep the output pane's viewport covering the last lines of output.


<a id="org6ef8df0"></a>

### `append_now(text, follow: true)`

Like `append`, but display output as it is produced rather than wait for a full page to be produced.


<a id="org8c667db"></a>

### `markdown(text)`

Render the given text as markdown source according to the current theme then `append` the result to the output pane.


<a id="orge943a9a"></a>

### `status(text, role: :info)`

Display the text in the "status" area, the lines immediately above the input field, using one of the following "roles":

-   **:good:** colored according something affirming according to the theme, usually something greenish;
-   **:info:** colored something neutral simply for informational purposes;
-   **:warn:** colored something to suggest caution, usually something in the orange to yellow range;
-   **:error:** colored something to suggest danger, usually some tone of red.


<a id="org92b4405"></a>

### `good(text)`

Display the text in the status area with the role :good.


<a id="orga373bc9"></a>

### `info(text)`

Display the text in the status area with the role :info.


<a id="orga812595"></a>

### `warn(text)`

Display the text in the status area with the role :warn.


<a id="orge27e09a"></a>

### `error(text)`

Display the text in the status area with the role :error.


<a id="org9fba7ce"></a>

### `oops(text)`

An alias for `error(text)`


<a id="orgf558347"></a>

### `alert(text, role: :info)`

Display the text in the one-line alert panel just below the input field. In the alert panel, the role only controls the foreground color, not the background.


<a id="org9dfef73"></a>

### `prompt(prompt, initial: "", cancel_value: nil, history_key: nil, save_history: true)`

Display a popup dialog box that allows the user to type in any string and return it. Combine the input line with a prompted-for string and shuffle their letters together:

```ruby
#! /usr/bin/env -S ruby -Ilib
# -*- mode: ruby -*-

require 'fatty'

weaver = lambda do |line, fatty|
  str = fatty.prompt("Secondary string to weave in with '#{line}'")
  (line + str).downcase.gsub(/[^a-z]/, '').split('').shuffle.join
end

Fatty::Terminal.new(
  on_accept: weaver,
  prompt: "Primary String> "
).go
```

You can pre-fill the prompt's input line by passing in an `initial:` parameter.

The `prompt` input has its own history facility separate from the history in the main input command line. You can turn it off by setting `save_history` to `false`.

`prompt` returns whatever the user typed and returns `nil` if the user cancels with C-c or C-g unless you specify an alternative `cancel_value`.


<a id="orge6891ad"></a>

### `add_progress(label:, total: nil, style: :percent, role: :info, width: 40)`

Display a progress widget in the status area to show the user that the system is working, not frozen. The `add_progress` method returns a `Progress` object on which the `#update` method can be called to cause it to animate one step. To the left of the widget the `label:` is displayed, followed by the widget. For processes where the total size is known in advance, the `total:` parameter indicates that size. The `role:` parameter controls the styling of the widget. The `width:` parameter places a limit on the size of the widget. `Fatty` supports several styles of progress widgets:

-   **:spinner:** a simple busy-wait indicator that just animates on every call;
-   **:count:** count up to `total` on each call of `update(current: <count>)`
-   **:percent:** count up to percent of `total` on each call of `update(current: <count>)`
-   **:count\_percent:** count up and show percent of `total` on each call of `update(current: <count>)`
-   **:bar:** display a filling ASCII progress bar with percent and count
-   **:unicode\_bar:** display a filling Unicode progress bar with percent and count
-   **:braille\_bar:** display a filling progress bar with percent and count using braille characters
-   **:trail:** display an "indicator" on each call of `update(indicator: <string>)`

1.  Initialization `add_progress(label:, style: :percent, total: nil, role: :info, width: 40)`

    -   **`label:`:** Text displayed before the progress widget, "Progress" by default.
    -   **`style:`:** The style of the progress widget from one of those named above.
    -   **`total:`:** For all styles except :trail and :spinner, the number that represents the size of the task. As the `#update` calls increase the value of `current` towards `total`, the widget indicates increasing completion.
    -   **`role:`:** One of :good, :info, :warn, or :error to color the widget according to the theme's idea of these roles. By default, :info.
    -   **`width`:** The number of characters for the full widget display: it is only relevant for the bar styles and the trail style; otherwise it is ignored.

2.  Update `update(current: nil, indicator: nil, render: false)`

    You update the progress widget by calling `#update` on the Progress object, passing as the `current:` parameter a number that indicates progress so far.
    
    ```ruby
    #! /usr/bin/env -S ruby -Ilib
    # -*- mode: ruby -*-
    
    require 'fatty'
    require 'prime'
    
    primer = lambda do |input, fatty|
      if input.match?(/\A[1-9]\d*\z/)
        k = input.to_i
        prog = fatty.add_progress(label: "Thinking...", total: k, style: :bar)
        out_line = +""
        num_primes = 0
        Prime.each do |p|
          num_primes += 1
          out = "#{p} "
    
          if out_line.length + out.length > 100
            fatty.append_now("#{out_line}\n", mode: :scrolling)
            out_line.clear
          end
    
          out_line << out
          prog.update(current: num_primes)
          break if num_primes >= k
        end
        fatty.append_now("#{out_line}\n", mode: :scrolling) unless out_line.empty?
        prog.finish("Done")
      else
        fatty.alert "Give me a positive integer", role: :error
      end
    end
    
    Fatty::Terminal.new(
      on_accept: primer,
      prompt: 'How many primes? ',
    ).go
    ```
    
    For the trail-style progress, you can use an arbitrary string to indicate progress by adding an `indicator:` parameter to the `#update` call.
    
    Suppose, for example, you wanted to print a trail in which the last digit of the prime is displayed to indicate progress and colored so it stands out:
    
    ```ruby
    #! /usr/bin/env -S ruby -Ilib
    # -*- mode: ruby -*-
    
    require 'fatty'
    require 'prime'
    require "rainbow/refinement"
    
    using Rainbow
    
    primer = lambda do |input, fatty|
      if input.match?(/\A[1-9]\d*\z/)
        k = input.to_i
        prog = fatty.add_progress(label: "Thinking...", total: k, style: :trail, width: 100)
        out_line = +""
        num_primes = 0
        Prime.each do |p|
          num_primes += 1
          out = "#{p} "
    
          if out_line.length + out.length > 100
            fatty.append_now("#{out_line}\n", mode: :scrolling)
            out_line.clear
          end
    
          out_line << out
          last_dig = p.to_s.split('').last
          sig =
            case last_dig
            when '1'
              last_dig.red
            when '3'
              last_dig.blue
            when '7'
              last_dig.green
            when '9'
              last_dig.yellow
            else
              '!'
            end
          prog.update(current: num_primes, indicator: sig)
          break if num_primes >= k
        end
        fatty.append_now("#{out_line}\n", mode: :scrolling) unless out_line.empty?
      else
        fatty.alert "Give me a positive integer", role: :error
      end
      prog.finish("Done")
    end
    
    Fatty::Terminal.new(
      on_accept: primer,
      prompt: 'How many primes? ',
    ).go
    ```

3.  Finish

    As the prior examples illustrate, you can issue an ending message at the end of the process by calling `#finish` on the Progress object.

4.  Clear

    And, if you have occasion, you can clear the Progress by calling `#clear` on the Progress object.


<a id="orga9c88fe"></a>

### `choose(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`

Present a set of `choices:`, which can be either:

-   an `Array` of `String` choices, where the selected string is returned; or
-   a `Hash` whose keys are converted to `String` labels and whose values are returned.

`choose` returns:

-   the selected `String` when `choices:` is an `Array`;
-   the associated value when `choices:` is a `Hash`; or
-   `cancel_value` when the user cancels with C-c or C-g.

The `prompt` String (by default "Choose") can guide the user about the purpose of the choices.

If you want to set one of the choices as the initial choice, set `initial_choice_idx:` to the Integer index of one of the choices.

If you want a value associated with the user's cancellation of the chooser with C-c or C-g, set `cancel_value:` to that value.

With an Array of Strings:

```ruby
#! /usr/bin/env -S ruby -Ilib
# -*- mode: ruby -*-

require 'fatty'

rgb = lambda do |_line, fatty|
  color = fatty.choose(
    "Choose a color",
    choices: ["red", "green", "blue"],
  )
  fatty.status("If you say so: #{Rainbow(color).send(color.to_sym)} it is!\n")
end

Fatty::Terminal.new(
  prompt: "Hit RETURN to choose a color> ",
  on_accept: rgb,
).go
```

Or with a Hash:

```ruby
#! /usr/bin/env -S ruby -Ilib
# -*- mode: ruby -*-

require 'fatty'

nums = lambda do |_line, fatty|
  const = fatty.choose(
    "Choose a constant",
    choices: { "Pi" => 3.14159, "Euler" => 2.718281828, "Golden Ratio" => 1.61803398875 }
  )
  fatty.status("Somewhere around #{const}\n")
end

Fatty::Terminal.new(
  prompt: "Hit RETURN to choose a constant> ",
  on_accept: nums,
).go
```


<a id="org8ae4976"></a>

### `choose_multi(prompt, choices:, cancel_value: nil)`

Present a set of `choices:`, which can either be

-   an Array whose items are converted to `Strings` and presented as choices
-   a Hash whose keys converted to `Strings` and presented as choices

`choose_multi` returns

-   a `Hash` whose keys and values are the user's selections if `choices:` was an `Array` of `Strings`,
-   a `Hash` whose keys and values are those selected from the `choices:` `Hash` if `choices:` was an `Hash`,
-   or the `cancel_value` if the user canceled the selection with C-c or C-g.

The `prompt` String (by default "Choose Many") can guide the user about the purpose of the choices.


<a id="org560df15"></a>

### `confirm(prompt, yes_label: "Yes", no_label: "No", cancel_value: false)`

Present the user with a simple Yes/No choice using your choice of ways to express "Yes" or "No" with `yes_label:` and `no_label:`.

`confirm` returns `true` for "Yes" and `false` for "No."

`confirm` will return `false` on cancellation with C-c or C-g unless you provide an alternative `cancel_value:`, in which case it returns that.


<a id="org64d2c3d"></a>

### `menu(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`

Present the user with a set of `choices:` representing actions to execute.

`choices:` is a `Hash` whose keys are labels presented to the user and whose values are procs, lambdas, or other objects that respond to `#call`.

```ruby
#! /usr/bin/env -S ruby -Ilib
# -*- mode: ruby -*-

require 'fatty'

asker = lambda do |_line, fatty|
  result = fatty.menu(
    "Pick an action",
    choices: {
      "Self Echo" => ->(fatty, label) {
        fatty.append("You chose #{label}\n")
        :echoed
      },
      "Say Hello" => ->(fatty, _label) {
        name = fatty.prompt("Name?")
        fatty.append("Hello, #{name}\n")
        :greeted
      },
    },
  )
  fatty.good(result)
end

Fatty::Terminal.new(
  on_accept: asker,
  prompt: "Type RETURN for some action> ",
).go
```

Each callable has access to the `CallbackEnvironment`, called `fatty` here and the `String` label that the user selected.

Each callable can return a value that the `@on_accept` proc can process as it pleases. In the example, they are printed to the status area.

If you want to set one of the choices as the initial choice, set `initial_choice_idx:` to the Integer index of one of the choices.

If you want a value associated with the user's cancellation of the chooser with C-c or C-g, set `cancel_value:` to that value.


<a id="orge474630"></a>

### `environment`

This returns a `Hash` of runtime conditions detected by `Fatty`:

| Key                   | Description                                          |
|--------------------- |---------------------------------------------------- |
| `:arch`               | System CPU architecture, e.g., `x86_64`              |
| `:os`                 | Operating system detected                            |
| `:ruby_platform`      | Ruby platform, e.g., `x86_64-linux`                  |
| `:screen`             | Whether the terminal is running under `screen`       |
| `:ssh`                | Whether the terminal is running under SSH            |
| `:tmux`               | Whether the terminal is running under `tmux`         |
| `:terminal`           | Detected underlying terminal, e.g., `kitty`          |
| `:terminal_version`   | Version of the terminal, if known                    |
| `:term`               | The `TERM` terminal type                             |
| `:truecolor_detected` | Whether truecolor capability appears to be available |
| `:truecolor_enabled`  | Whether Fatty is actually using truecolor rendering  |
| `:curses`             | Runtime curses capabilities and parameters           |

The environment report also includes a nested `:curses` hash:

| Key                 | Description                                          |
|------------------- |---------------------------------------------------- |
| `:started`          | Whether curses has been initialized                  |
| `:truecolor`        | Whether the active curses context is using truecolor |
| `:key_min`          | Lowest keycode with a curses name                    |
| `:key_max`          | Highest keycode with a curses name                   |
| `:lines`            | Number of terminal rows available                    |
| `:cols`             | Number of terminal columns available                 |
| `:has_colors`       | Whether curses reports color support                 |
| `:colors`           | Number of colors available to curses                 |
| `:color_pairs`      | Number of color pairs available to curses            |
| `:can_change_color` | Whether curses can redefine color values             |


<a id="org6404575"></a>

# Default Interaction


<a id="org1abaacf"></a>

## Parts of the Screen


<a id="orgbb0692f"></a>

### Input Field

Just above the bottom of the screen where all the action takes place: it is a line for editing the input. It displays a prompt followed by an area in which you build the command line using `fatty's` editing facilities.


<a id="org401bb99"></a>

### Output Pane

Most of the top part of the screen is reserved for displaying whatever output is sent to it with the `on_accept` callback to the `Terminal`. It can render colored ANSI-encoded strings and will page long output so you can view it a page at a time and even search the output.


<a id="orgc26e524"></a>

### Status Area

The one to four lines just above the Input Field that displays output to the user that is out of band for the Output Pane. Brief messages of confirmation, warning, or error can be displayed there so as to get the user's immediate attention. Progress bars also render there where their visibility is made prominent.


<a id="org2d2fa91"></a>

### Alert  Area

Alerts are short-lived, non-scrolling messages shown below the input field. They are intended for user-visible conditions that require attention. `Fatty` uses this area to warn the user of unrecognized key codes and of unbound key presses.


<a id="org7090550"></a>

## Command-line Editing


<a id="org5b9771f"></a>

## Keybindings

The following tables explain the keybindings available in \`fatty\` in different contexts. Named keys are indicated by \`:name\` and key categories, such as \`<digits>\` are indicated with brackets.


<a id="org44ce39d"></a>

### Input Context

When editing the input line or text input for widgets like the \`prompt\`, \`fatty\` provides emacs-like editing keybindings by default. Many of these commands can take a count prefix argument to repeat the command count times. For example, \`M-8 M-0 #\` will insert 80 '#' characters at the cursor.

| Key        | Description                                            |
|---------- |------------------------------------------------------ |
| C-a        | move to the beginning of the line                      |
| :home      | move to the beginning of the line                      |
| C-e        | move to the end of the line                            |
| :end       | move to the end of the line                            |
| C-f        | move cursor right one character                        |
| :right     | move cursor right one character                        |
| C-b        | move cursor left one character                         |
| :left      | move cursor left one character                         |
| M-f        | move cursor right one word                             |
| M-:right   | move cursor right one word                             |
| C-:right   | move cursor right one word                             |
| M-b        | move cursor left one word                              |
| M-:left    | move cursor left one word                              |
| C-:left    | move cursor left one word                              |
| C-t        | transpose characters                                   |
| M-t        | transpose words                                        |
|            |                                                        |
| C-d        | delete character at cursor                             |
| :delete    | delete character at cursor                             |
| :backspace | delete character before cursor                         |
| M-d        | kill word at cursor                                    |
| C-w        | kill word before cursor                                |
| C-k        | kill to end of line                                    |
|            |                                                        |
| C-/        | undo                                                   |
| C-\_       | undo                                                   |
| C-M-/      | redo                                                   |
| M-/        | redo                                                   |
|            |                                                        |
| C-:space   | set the mark at the current cursor position            |
| C-@        | set the mark at the current cursor position            |
| C-g        | clear the mark                                         |
| C-w        | kill the region                                        |
| M-w        | copy the region                                        |
|            |                                                        |
| C-y        | yank last kill at cursor                               |
| M-y        | replace last yank with next in kill ring               |
|            |                                                        |
| C-u        | universal count argument (time 4 each press)           |
| M-`digit`  | accumulate count argument                              |
|            |                                                        |
| C-p        | replace the line with the prior history item           |
| :up        | replace the line with the prior history item           |
| C-n        | replace the line with the next history item            |
| :down      | replace the line with the next history item            |
| C-r        | search the history in a popup                          |
|            |                                                        |
| :enter     | feed the line to the on\_accept proc and page output   |
| M-:enter   | feed the line to the on\_accept proc and scroll output |
| C-c        | quit \`fatty\`                                         |
| C-d        | quit \`fatty\` only if the input line is empty         |
| C-l        | clear the output pane                                  |
|            |                                                        |


<a id="org04b24c6"></a>

### Paging Context

By default, \`fatty\` sends output to the large output pane, and if the output is more than one screen long presents a paging environment for viewing and searching the environment.

| Key   | Description                             |
|----- |--------------------------------------- |
| :up   | move output one line up                 |
| k     | move output one line up                 |
| :down | move output one line down               |
| j     | move output one line down               |
| M-s   | toggle between paging and scrolling     |
| ?     | initiate a fixed-string search backward |
| C-s   | initiate an Isearch session forward     |
| C-r   | initiate an Isearch session backward    |
| C-M-s | initiate an Regexp session forward      |
| C-M-r | initiate an Regexp session backward     |
| C-/   | initiate an Regexp session forward      |


<a id="org4a236fa"></a>

## Markdown


<a id="org546d253"></a>

### Forced line breaks

Use `<br>` to force a line break.

```
This line has a forced line break <br> and this should appear on the next line.
```

will render as

```
This line has a forced line break
and this should appear on the next line.
```


<a id="org378aeb8"></a>

## History


<a id="org54f6da5"></a>

## Completion


<a id="org99dcd04"></a>

### From the `completion_proc`


<a id="orge274370"></a>

### From History


<a id="orgf1d41e6"></a>

### From partial filenames


<a id="orgb04a838"></a>

# Configuration

When a Fatty application starts, Fatty installs default configuration files under `~/.config/fatty` if they do not already exist. Fatty does not overwrite files that are already there, so you can edit these files directly and keep them under version control.

The config files are:

-   **`config.yml`:** general configuration;
-   **`keydefs.yml`:** terminal-specific keycode naming;
-   **`keybindings.yml`:** user-defined keybindings;
-   **`themes/`:** YAML theme files.

The default user-specific configuration directory follows `XDG_CONFIG_HOME` if it is set. Otherwise it is `~/.config/fatty`.

In addition to the user-specific configuration, fatty will read app-specific configuration files from `~/.config/fatty/apps/<app_name>` if `Terminal` was given an `app_name` parameter. It will use a different directory of your choosing if `Terminal` was given an `app_config_dir` directory name.


<a id="orga6c6d2d"></a>

## General Configuration `config.yml`

`config.yml` controls general behavior such as word movement, ESC handling, logging, history, the initial theme, and truecolor rendering.

A small configuration might look like this:

```yaml
word_char_re: "[[:alnum:]_.:-]"

esc_delay: 0

history:
  file: "~/.fatty_history"
  max: 10000

theme: wordperfect

truecolor: auto
```


<a id="orgc790827"></a>

### `word_char_re`

This setting is a Ruby regular expression fragment used to decide what counts as a word in the input buffer. It must be a `String` representing a `Regexp` that matches a single character that is meant to be a part of a "word" for purposes of cursor movement. The default setting treats letters, digits, and underscore as word characters:

```yaml
word_char_re: "[[:alnum:]_]"
```

For command-line applications, you may want dashes to be part of a word:

```yaml
word_char_re: "[[:alnum:]_-]"
```

For Ruby constants, hostnames, or command-like tokens, you may want a broader definition:

```yaml
word_char_re: "[[:alnum:]_.:-]"
```


<a id="org6413a1c"></a>

### `esc_delay`

`esc_delay` controls how long curses waits after receiving `ESC` before deciding whether another key is part of the same Meta-key sequence. The value is in milliseconds.

```yaml
esc_delay: 0
```


<a id="org1dfa5e0"></a>

### `history`

1.  `file`

    The path to the history file to use, by default `~/.fatty_history`

2.  `max`

    The maximim number of lines of history retained, by default 10,000.


<a id="org3c40aca"></a>

### `theme`

The `theme` setting names the theme Fatty applies at startup:

```yaml
theme: nordic
```


<a id="orgd68b975"></a>

### `truecolor`

The `truecolor` setting controls whether Fatty uses truecolor escape sequences for rendering colors. The usual setting is `auto`, meaning that `truecolor` is enabled if available. It can be set to `true`, `false`, `on`, `off` or `auto`.

```yaml
truecolor: auto
```


<a id="org61e33b0"></a>

### `log`

Logging is configured under `log`:

```yaml
log:
file: "~/log/fatty.log"
level: debug
tags:
- keycode
- keyevent
- keybinding
- action
- command
- session
- render
- perf
```

1.  `file`

    The path to the log file to use.

2.  `level`

    Can be one of the following
    
    -   **`info`:** only informational messages
    -   **`warn`:** only non-fatal warning messages and `info` messages
    -   **`error`:** only fatal error messages and `warn` and `info` messages
    -   **`debug`:** detailed messages to assist debugging `fatty` plus all of the above.

3.  `tags`

    `log.tags` controls which tagged log messages are written. Tags are ordinary symbolic labels used by Fatty's logging calls; they are not checked against a fixed registry. A tag is useful if Fatty logs messages with that tag.
    
    The special tag `all` enables all tagged log messages except `perf`. Performance logging is intentionally noisy and must be enabled explicitly with `perf`.
    
    ```yaml
    log:
    tags:
    - keycode
    - keybinding
    - render
    - perf
    ```


<a id="orgc8a783a"></a>

## Key code definitions `keydefs.yml`

Most keys are named correctly by curses. Some terminal emulators, multiplexers, or keyboard modes emit numeric keycodes that curses does not name usefully. The `keydefs.yml` file lets you assign names and modifiers to those numeric codes.

When Fatty runs inside `tmux`, key definitions are looked up under `tmux`, not under the outer terminal emulator. `tmux` translates the outer terminal's input before Fatty sees it, so keycodes observed inside `tmux` may differ from keycodes observed directly under GNOME Terminal, Kitty, Alacritty, or another terminal. Use `keytest` in the same environment where the application will normally run. The same comment applies to `screen`.

A key definition is terminal-specific. For example:

```yaml
tmux:
  555:
    key: left
    meta: true
  570:
    key: right
    meta: true
  557:
    key: left
    ctrl: true
  572:
    key: right
    ctrl: true
```

This says that, when Fatty detects that the terminal is `tmux`, curses keycode `555` should be treated as `M-left`, keycode `570` as `M-right`, and so on.

The demo executable has a `keytest` command that is useful when building this file. Run `fatty`, use the `keytest` command, press the key you want to identify, and add an entry for the numeric code if Fatty does not already know what to call it.

Here is what I found running `keytest` on a variety of popular terminals to determine how each reported `PageDown`, `C-PageDown`, `M-PageDown`, and `C-M-PageDown`:

| Terminal       | Key Pressed | Ctrl? | Meta? | Code   | Status            |
|-------------- |----------- |----- |----- |------ |----------------- |
| gnome-terminal | PageDown    | no    | no    | 338    | Defined and bound |
| gnome-terminal | PageDown    | yes   | no    | 559    | Undefined         |
| gnome-terminal | PageDown    | no    | yes   | 557    | Undefined         |
| gnome-terminal | PageDown    | yes   | yes   | 561    | Undefined         |
| alacritty      | PageDown    | no    | no    | 338    | Defined and bound |
| alacritty      | PageDown    | yes   | no    | 559    | Undefined         |
| alacritty      | PageDown    | no    | yes   | 557    | Undefined         |
| alacritty      | PageDown    | yes   | yes   | 561    | Undefined         |
| kitty          | PageDown    | no    | no    | 338    | Defined and bound |
| kitty          | PageDown    | yes   | no    | 565    | Undefined         |
| kitty          | PageDown    | no    | yes   | 563    | Undefined         |
| kitty          | PageDown    | yes   | yes   | 567    | Undefined         |
| terminator     | PageDown    | no    | no    | 338    | Defined and bound |
| terminator     | PageDown    | yes   | no    | <none> | Undefinable       |
| terminator     | PageDown    | no    | yes   | 557    | Undefined         |
| terminator     | PageDown    | yes   | yes   | 561    | Undefined         |
| ghostty        | PageDown    | no    | no    | 338    | Defined and bound |
| ghostty        | PageDown    | yes   | no    | 564    | Undefined         |
| ghostty        | PageDown    | no    | yes   | 562    | Undefined         |
| ghostty        | PageDown    | yes   | yes   | 566    | Undefined         |
| konsole        | PageDown    | no    | no    | 338    | Defined and bound |
| konsole        | PageDown    | yes   | no    | 559    | Undefined         |
| konsole        | PageDown    | no    | yes   | 557    | Undefined         |
| konsole        | PageDown    | yes   | yes   | 561    | Undefined         |

I could turn this into a `keydefs.yml` file that would allow me to define all those keys:

```yaml
gnome-terminal:
  559:
    key: page_down
    ctrl: true
  557:
    key: page_down
    meta: true
  561:
    key: page_down
    ctrl: true
    meta: true

alacritty:
  559:
    key: page_down
    ctrl: true
  557:
    key: page_down
    meta: true
  561:
    key: page_down
    ctrl: true
    meta: true

kitty:
  565:
    key: page_down
    ctrl: true
  563:
    key: page_down
    meta: true
  567:
    key: page_down
    ctrl: true
    meta: true

terminator:
  # 559:
  #   key: page_down
  #   ctrl: true
  557:
    key: page_down
    meta: true
  561:
    key: page_down
    ctrl: true
    meta: true

ghostty:
  564:
    key: page_down
    ctrl: true
  562:
    key: page_down
    meta: true
  566:
    key: page_down
    ctrl: true
    meta: true

konsole:
  559:
    key: page_down
    ctrl: true
  557:
    key: page_down
    meta: true
  561:
    key: page_down
    ctrl: true
    meta: true
```

After installing that keydefs, I find that the PageDown variants are all recognized by name and modifiers (except for the strange failure of `terminator` to recognize `C-PageDown`!).


<a id="orgf938edb"></a>

## Key bindings  `keybindings.yml`

Fatty has built-in Emacs-style bindings for ordinary input editing, history, completion, popup navigation, and paging. The `keybindings.yml` file lets you add or override bindings without changing Ruby code.

A keybinding names a key chord, the context in which it applies, and the Fatty action to run:

```yaml
- key: left
  meta: true
  action: move_word_left

- key: right
  meta: true
  action: move_word_right

- key: space
  context: paging
  action: page_down

- key: backspace
  context: paging
  action: page_up
```


<a id="orgca2c4fd"></a>

### Key Names

A keybinding uses the unmodified key name under the `key` field:

```yaml
- key: f
  meta: true
  context: text
  action: move_word_right
```

1.  Printable Keys

    Most printable keys can be written as the character itself. Quote keys that YAML might otherwise treat specially or make hard to read, such as `":"`, `"#"`, `"["`, `"]"`, `"{"`, `"}"`, `"\""`, and `"\\"`.
    
    ```yaml
    - key: a
    - key: /
    - key: .
    - key: =
    - key: "\\"
    - key: "\""
    ```

2.  Curses and Fatty Named Keys

    `Fatty` translates codes returned by curses for special keys into names:
    
    |                |                |                 |                   |                |
    |-------------- |-------------- |--------------- |----------------- |-------------- |
    | `tab`          | `insert`       | `delete`        | `home`            | `end`          |
    | `left`         | `right`        | `page_up`       | `page_down`       | `up`           |
    | `down`         | `f1`           | `f2`            | `f3`              | `f4`           |
    | `f8`           | `f9`           | `f10`           | `f11`             | `f12`          |
    | `keypad_0`     | `keypad_1`     | `keypad_2`      | `keypad_3`        | `keypad_4`     |
    | `keypad_8`     | `keypad_9`     | `keypad_divide` | `keypad_multiply` | `keypad_minus` |
    | `keypad_enter` | `keypad_comma` |                 |                   |                |
    
    Some terminals can report application-keypad sequences such as `keypad_divide`, `keypad_multiply`, or `keypad_enter`, but numeric keypad digits are often not distinguishable from ordinary digits when NumLock is on, and are often reported as navigation keys such as `end`, `down`, `page_down`, or `left` when NumLock is off. Use `keytest` to see what your terminal actually sends.
    
    `Fatty` also provides convenient names to other keys common keys:
    
    |         |          |         |
    |------- |-------- |------- |
    | `enter` | `escape` | `space` |

3.  Possibly Invisible Keys

    Some physical keys may never reach Fatty at all. They may be handled by the keyboard firmware, the kernel, the desktop environment, the window manager, or the terminal emulator before curses can report them. Common examples include `Print Screen`, `Scroll Lock`, `Pause/Break`, `Caps Lock`, `Num Lock`, `Fn`, `Menu/Application`, `Super/Windows`, power/sleep/wake keys, brightness keys, volume/media keys, keyboard-backlight keys, airplane-mode keys, and touchpad toggle keys.
    
    Use `keytest` to check. If Fatty sees a key as a raw numeric code, you can name it in `keydefs.yml` and bind it. If `keytest` shows nothing, the key is being intercepted before Fatty receives it.

4.  Unnamed but Recognized Keys

    Some terminals report modified special keys as distinct numeric keycodes that `fatty` and `curses` do not name. Use `keytest` to discover those codes, then assign names to them in `keydefs.yml`. The name can be one of Fatty's usual names, or a new name of your own.
    
    For example, if a keyboard has an extra thumb key and `keytest` reports it as an uncoded keycode `601`, you could name it:
    
    ```yaml
    gnome-terminal:
    601:
    key: thumb_left
    ```
    
    Then bind it in `keybindings.yml`:
    
    ```yaml
    - key: thumb_left
      context: text
      action: move_word_left
    ```
    
    Fatty does not require custom key names to come from a fixed registry. A custom name only needs to be used consistently between `keydefs.yml` and `keybindings.yml`.


<a id="org58b466e"></a>

### Mouse Events

Mouse events can also be bound:

```yaml
- button: left_clicked
  context: popup
  action: choose
```

Recognized mouse button names include:

```org
left_pressed
left_released
left_clicked
left_double_clicked
left_triple_clicked
middle_pressed
middle_released
middle_clicked
middle_double_clicked
middle_triple_clicked
right_pressed
right_released
right_clicked
right_double_clicked
right_triple_clicked
scroll_up
scroll_down
```


<a id="org11be0fd"></a>

### Modifiers

A binding may include these modifiers:

```yaml
ctrl: true
meta: true
shift: true
```


<a id="org178df34"></a>

### Contexts

In `Fatty`, the key map is partitioned by "contexts" and in different environments the contexts are tried in order from highest priority to lowest and the first binding found wins. The following table lists the contexts associated with each interaction environment:

| Environment        | Contexts High to Low                    |
|------------------ |--------------------------------------- |
| Input Field        | :input, :text, :terminal                |
| Output Paging      | :paging, :terminal                      |
| Output Scrolling   | :terminal                               |
| String Search      | :search, :text, :terminal               |
| Incremental Search | :isearch, :text, :terminal              |
| Prompt Popup       | :prompt, :text, :terminal               |
| Popup Choose       | :popup, :text, :terminal                |
| Popup Multi-Choose | :popup\_multi, :popup, :text, :terminal |

The available contexts are:

| Context        | Meaning                                               |
|-------------- |----------------------------------------------------- |
| `:terminal`    | global terminal/session commands                      |
| `:text`        | ordinary text-editing commands shared by input fields |
| `:input`       | the main command input field                          |
| `:paging`      | output pager navigation                               |
| `:search`      | non-incremental search field                          |
| `:isearch`     | incremental search field                              |
| `:prompt`      | prompt popup input                                    |
| `:popup`       | popup selection/navigation                            |
| `:popup_multi` | multi-select popup behavior                           |

The \`:terminal\` context is the lowest-priority fallback context for terminal-wide commands. It is where Fatty puts bindings that are not specific to text editing, paging, search, or popup selection, such as theme selection, key testing, and quitting. Because \`:terminal\` is searched last, any more specific context can override a terminal-wide binding.


<a id="orgcb0c617"></a>

### Actions

A keybinding connects a key event in a context to an "action." An action is a named Fatty command such as \`move\_left\`, \`delete\_backward\`, \`accept\_line\`, \`page\_down\`, \`choose\_theme\`, or \`quit\`.

A binding entry names the action with the \`action\` field:

```yaml
- key: left
  context: text
  action: move_left

- key: f
  meta: true
  context: text
  action: move_word_right

- key: page_down
  context: paging
  action: page_down
```

Most movement, deletion, history, completion, paging, and popup-navigation actions honor Fatty's numeric count argument. The count is entered before the command, Emacs-style. For example, `M-5 C-f` moves forward five characters if `C-f` is bound to move\_right, and `M-3 C-n` moves down three items if `C-n` is bound to the current environment's `next-item` action.

Use \`keytest\` to check what action is currently bound to a key. If a key is bound, \`keytest\` reports the matching context, action name, arguments, and the object that handles the action.

1.  Input buffer actions

    Input buffer actions edit the contents of a text buffer. These are the ordinary line-editing operations shared by the main input field, search fields, prompt popups, and other text-like interactions. Many of these actions honor the numeric prefix count.
    
    Terminology notes:
    
    -   **kill ring:** like emacs, `fatty` keeps a "clipboard" of items with the newest item in the current position and older items "before" it but in a "ring" that return to the beginning;
    -   **yank:** retrieve the most recent item from the kill ring
    -   **yank pop:** retrieve successively older items from the kill ring
    -   **delete:** removes text without copying it to the kill ring;
    -   **kill:** removes text and copies it to the kill ring for later yank;
    -   **word:** a sequence of contiguous characters that are each matched by the `word_char_re` from the config file or "[[:alnum]\_]" by default;
    
    | Action Name            | Count? | Description                                |
    |---------------------- |------ |------------------------------------------ |
    | bol                    | No     | Move cursor to beginning of buffer         |
    | clear                  | No     | Clear the buffer                           |
    | clear\_mark            | No     | Clear the region mark                      |
    | copy\_region           | No     | Copy the text in the region to kill ring   |
    | delete\_char\_backward | Yes    | Delete char to the left of cursor          |
    | delete\_char\_forward  | Yes    | Delete char to the right of cursor         |
    | delete\_region         | No     | Delete the text in the region              |
    | eol                    | No     | Move cursor to end of buffer               |
    | kill\_region           | No     | Kill the text in the region                |
    | kill\_to\_bol          | No     | Kill the text from cursor to end           |
    | kill\_to\_eol          | No     | Kill the text from cursor to beginning     |
    | kill\_word\_backward   | Yes    | Kill the word to the left of  cursor       |
    | kill\_word\_forward    | Yes    | Kill the word to the right of  cursor      |
    | move\_left             | Yes    | Move cursor one char left                  |
    | move\_right            | Yes    | Move cursor one char right                 |
    | move\_word\_left       | Yes    | Move cursor one word left                  |
    | move\_word\_right      | Yes    | Move cursor one word right                 |
    | redo                   | No     | Redo an undone action                      |
    | set\_mark              | No     | Set the region mark at cursor              |
    | transpose\_chars       | Yes    | Switch position of char with prior char    |
    | transpose\_words       | Yes    | Switch position of word with prior char    |
    | undo                   | No     | Revert last edit action                    |
    | yank                   | No     | Copy kill ring to buffer at cursor         |
    | yank\_pop              | Yes    | Copy next kill ring item and replace prior |

2.  Input field actions

    Input field actions operate on an editable input field. An input field occurs at the main input prompt, but also in things like search-narrowing input, incremental-search, a prompt for text, etc. It is lower level than the shell session input described in the next section. In particular, it can have its own history attached to it depending on its purpose. They handle accepting the current line, moving through history, and receiving pasted text.
    
    | Action Name   | Count? | Description                                               |
    |------------- |------ |--------------------------------------------------------- |
    | accept\_line  | No     | Accept the current text as the input                      |
    | history\_prev | No     | Insert the prior relevant history item in the input field |
    | history\_next | No     | Insert the next relevant history item in the input field  |

3.  Shell session actions

    Shell session actions operate at the session level around the main command input and output area. They submit input, interrupt running work, clear output, start completion, open completion/history popups, and manage numeric prefix entry.
    
    | Action Name          | Count? | Description                                                      |
    |-------------------- |------ |---------------------------------------------------------------- |
    | submit\_line         | No     | Pass the current text to the on\_accept proc and page output     |
    | submit\_and\_scroll  | No     | Pass the current text to the on\_accept proc and scroll output   |
    | interrupt            | No     | End the current session                                          |
    | interrupt\_if\_empty | No     | End the current session only if the current text is empty        |
    | clear\_output        | No     | Clear the output pane                                            |
    | complete             | No     | Suggest the next possible completion as an autosuggestion        |
    | complete\_previous   | No     | Suggest the prior possible completion as an autosuggestion       |
    | completion\_popup    | No     | Display all possible completions in a popup for selection        |
    | history\_search      | No     | Display history item starting with the text-so-far for selection |
    | count\_digit         | No     | Add a digit to the numeric prefix                                |
    | universal\_argument  | No     | Set the numeric argument to 4 or multiply the current one by 4   |

4.  Pager actions

    Pager actions navigate output when the output area is in paging mode. They move by line, page, top, bottom, or end of output, handle mouse-wheel scrolling, and switch between paging and scrolling behavior. Most movement actions honor the numeric prefix count.
    
    | Action Name           | Count? | Description                                      |
    |--------------------- |------ |------------------------------------------------ |
    | page\_up              | Yes    | Move the output view one page up                 |
    | page\_down            | Yes    | Move the output view one page down               |
    | end\_of\_output       | No     | Move the output to the end of output and scroll  |
    | line\_up              | Yes    | Move the output view one line up                 |
    | line\_down            | Yes    | Move the output view one line down               |
    | scroll\_up            | Yes    | Move the output view six lines up                |
    | scroll\_down          | Yes    | Move the output view six lines down              |
    | page\_top             | No     | Move the output to the beginning of output       |
    | page\_bottom          | No     | Move the output to the end of output             |
    | paging\_to\_scrolling | No     | Quit paging and scroll output as it is produced  |
    | toggle\_paging        | No     | Toggle output mode between paging and scrolling  |
    | quit\_paging          | No     | Quit paging and return control to the input line |

5.  Pager search actions

    Pager search actions can *initiate* a search session within the pager: a string search, a regular expression search, or an incremental-search. Once a search session is entered, other actions navigate matches in the output. There are also actions to end a search session.
    
    While the search session is active, accepting commits the current match and canceling restores the pager to the position it had when the search began. After the search is accepted, `n` and `N` repeat the committed search in the pager; at that point the search session is no longer active.
    
    | Action Name                    | Count? | Description                                                         |
    |------------------------------ |------ |------------------------------------------------------------------- |
    | pager\_search\_forward         | No     | Initiate a string search forward from current output point          |
    | pager\_search\_backward        | No     | Initiate a string search backward from current output point         |
    | pager\_regex\_search\_forward  | No     | Initiate a regex search forward from current output point           |
    | pager\_regex\_search\_backward | No     | Initiate a regex search backward from current output point          |
    | pager\_isearch\_forward        | No     | Initiate an incremental search forward from current output point    |
    | pager\_isearch\_backward       | No     | Initiate an incremental search backward from current output point   |
    | pager\_search\_next            | No     | Move output to the next search match                                |
    | pager\_search\_prev            | No     | Move output to the prior search match                               |
    | search\_toggle\_regex          | No     | Toggle between regex and string search                              |
    | search\_step\_forward          | No     | Preview the next match using the current search text                |
    | search\_step\_backward         | No     | Preview the prior match using the current search text               |
    | isearch\_next                  | No     | Move output to the next isearch match                               |
    | isearch\_prev                  | No     | Move output to the prior isearch match                              |
    | search\_accept                 | No     | Commit the current search and close the search session              |
    | search\_cancel                 | No     | Cancel the active search session and restore its starting point     |
    | isearch\_accept                | No     | Commit the current incremental search and close the search session  |
    | isearch\_cancel                | No     | Cancel the active incremental search and restore its starting point |

6.  Popup actions

    Popup actions control selection and narrowing popups such as choose, menu, completion, and history popups. You can narrow the selections presented by typing in the input field presented. You can move through the list, accept or cancel the selection, page through choices, jump to the top or bottom, recenter the selection, and toggle selection in multi-select popups.
    
    | Action Name             | Count? | Description                                               |
    |----------------------- |------ |--------------------------------------------------------- |
    | popup\_cancel           | No     | Close the popup and return its cancel\_value              |
    | popup\_accept           | No     | Close the popup and return the selection                  |
    | popup\_next             | No     | Move the selection cursor to the next item                |
    | popup\_prev             | No     | Move the selection cursor to the prior item               |
    | popup\_page\_down       | No     | Move the selection list down one page                     |
    | popup\_page\_up         | No     | Move the selection list up one page                       |
    | popup\_top              | No     | Move to the top of the selection list                     |
    | popup\_bottom           | No     | Move to the bottom of the selection list                  |
    | popup\_recenter         | No     | Recenter the selection list on the current item           |
    | popup\_toggle\_selected | No     | In multi-select, toggle the selection of the current item |

7.  Prompt popup actions

    Prompt popup actions control prompt dialogs that collect a string from the user. They accept the prompt, cancel it, or cancel only when the prompt is empty.
    
    | Action Name               | Count? | Description                                          |
    |------------------------- |------ |---------------------------------------------------- |
    | prompt\_accept            | No     | Close the prompt popup and return the current string |
    | prompt\_cancel            | No     | Close the prompt popup and return its cancel\_value  |
    | prompt\_cancel\_if\_empty | No     | Cancel only if the input buffer is empty             |

8.  Utility Actions

    Some actions exist to support `Fatty`'s own input machinery and are not normally useful as ordinary user bindings. For example, `insert`, `replace`, and `paste` need text supplied by code: `paste` is used for bracketed paste events from the terminal and normalizes pasted text for a one-line input field; `self_insert` is selected automatically for printable characters. They are listed her for completeness.
    
    | Action Name  | Args | Count? | Description                        |
    |------------ |---- |------ |---------------------------------- |
    | insert       | str  | Yes    | Insert the string at point         |
    | self\_insert |      | Yes    | Insert the bound key at point      |
    | replace      | str  | No     | Replace the buffer with the string |
    | set          | str  | No     | Alias for `replace`                |
    | paste        | str  | No     | Insert pasted text at point        |


<a id="orgb3fbff4"></a>

## Themes `themes/`


<a id="org490854a"></a>

### Distributed Themes

As distributed, `fatty` comes with the following themes, most of which are based on popular themes used in many text editors and IDEs.

Within a `fatty` terminal, themes can be changed interactively. The default Emacs-style bindings include:

| Key     | Action                                  |
|------- |--------------------------------------- |
| `C-M-t` | cycle to the next loaded theme          |
| `M-=`   | preview and choose a theme from a popup |

Here are the builtin themes:

| Name              | Description                                        |
|----------------- |-------------------------------------------------- |
| capuchin\_monk    | A tribute to St. Francis of Assisi                 |
| catppuccin\_latte | Pastel theme of the latte flavor                   |
| catppuccin\_mocha | Pastel theme of the mocha flavor                   |
| cyberpunk         | Brash colorful theme                               |
| dracula           | Dark theme inspired by the Count                   |
| everforest\_dark  | Dark green-esque theme                             |
| gruvbox\_dark     | Engineered for focus, built for developers         |
| gruvbox\_light    | Engineered for focus, built for developers         |
| mono              | Minimal black-and-white theme                      |
| monokai           | Based on <https://monokai.pro/history>             |
| nordic            | Shiver me timbers, its northern                    |
| onedark           | Shameless imitation of Atom editor theme           |
| solarized\_dark   | Ethan Schoonover's famous terminal theme           |
| solarized\_light  | And its light variant                              |
| terminal          | Use the terminal's color scheme                    |
| tokyo\_night      | Celebrates the neon lights and dark vibes of Tokyo |
| wordperfect       | Nostalgic nod to the good old word processor       |


<a id="orga1c6598"></a>

### Custom Themes

1.  Theme Name

    A Fatty theme is a YAML file in the user-specific config directory (normally `~/.config/fatty/themes`) or the app-specific config directory (by default `~/.config/fatty/apps/<app_name>/themes`). The file name does not matter to the renderer, but the theme must have a `name` field, and the name is what you put in `config.yml`:
    
    ```yaml
    theme: nordic
    ```

2.  Inheritance from Another Theme

    Themes can inherit from other themes with the `inherit:` tag:
    
    ```yaml
    name: my_nordic
    inherit: nordic
    
    output:
    fg: "#eeeeee"
    ```
    
    This means that all the theme setting from the `nordic` theme apply except to the extent changed by the rest of the `my_nordic` theme file.

3.  Inheritance within a Theme

    Not only may one theme inherit from another theme, some roles within a theme inherit from other roles. For example, the `input` role inherits from the `output` role.
    
    Thus, a minimal theme can define only `output` and inherit everything else through Fatty's role defaults:
    
    ```yaml
    name: simple_dark
    inherit: null
    
    output:
      fg: white
      bg: black
    ```
    
    This means that the input field will have the same coloring and attributes as the output pane.

4.  Theme Roles

    Here is a listing of what roles act as the parent for each of the roles, their purpose, and the role, if any, from which they inherit.
    
    | Role name                | Used for                                  | Parent Role             |
    |------------------------ |----------------------------------------- |----------------------- |
    | output:                  | Main output area text.                    | <none>                  |
    | input:                   | Main command/input field.                 | :output,                |
    | input\_suggestion:       | Autosuggestion or completion suffix text. | :input,                 |
    | cursor:                  | Cursor cell styling where applicable.     | :input,                 |
    | region:                  | Selected text / active region.            | :output,                |
    | status:                  | Status area base role.                    | :output,                |
    | info:                    | Informational messages.                   | :output,                |
    | good:                    | Success messages.                         | :info,                  |
    | warn:                    | Warning messages.                         | :info,                  |
    | error:                   | Error messages.                           | :warn,                  |
    | alert:                   | Alert panel base role.                    | :output,                |
    | pager\_status:           | Pager status / prompt row.                | :status,                |
    | search\_input:           | Search input field.                       | :popup,                 |
    | match\_current:          | Current search match.                     | :region,                |
    | match\_other:            | Other search matches.                     | :region,                |
    | popup:                   | Popup body.                               | :output,                |
    | popup\_frame:            | Popup border/frame.                       | :popup,                 |
    | popup\_input:            | Popup filter/input field.                 | :input,                 |
    | popup\_selection:        | Selected popup item row.                  | :region,                |
    | popup\_counts:           | Popup counts/status row.                  | :popup,                 |
    | markdown\_h1:            | Markdown level-1 headings.                | :output                 |
    | markdown\_h2:            | Markdown level-2 headings.                | :markdown\_h1           |
    | markdown\_h3:            | Markdown level-3 headings.                | :markdown\_h2           |
    | markdown\_code:          | Inline markdown code.                     | :output,                |
    | markdown\_code\_block:   | Markdown fenced-code block base role.     | :markdown\_code,        |
    | markdown\_code\_gutter:  | Code block gutter/prefix.                 | :markdown\_code\_block, |
    | markdown\_strong:        | Markdown strong/bold text.                | :output,                |
    | markdown\_emphasis:      | Markdown emphasized text.                 | :output,                |
    | markdown\_link:          | Markdown link text.                       | :output,                |
    | markdown\_url:           | Markdown displayed URL text.              | :markdown\_link,        |
    | markdown\_quote\_gutter: | Markdown block quote gutter.              | :output,                |
    | markdown\_highlight:     | Markdown highlight / marked text.         | :output,                |
    | markdown\_table\_header: | Markdown table header cells.              | :markdown\_strong,      |
    | markdown\_table\_cell:   | Markdown table body cells.                | :output,                |
    | markdown\_underline:     | Markdown underline text.                  | :output,                |
    | markdown\_hrule:         | Markdown horizontal rules.                | :output,                |

5.  Role Colors and Attributes and Frame Style

    Each role can have assigned to it a foreground color (`fg:`), a background color (`bg:`), and one or more "attributes" (`attrs:`).
    
    1.  Colors
    
        The colors can be a hex string of the form "#RRGGBB", that is a mixture of red, green, and blue at level given by three valid hexadecimal numbers RR, GG, and BB. For example "#FF0000" is pure red, "#330044" is a middling mixture of red and blue, a shade of purple. In addition, `fatty` recognizes color names defined as 16 ANSI colors, 256 xterm colors, and X11 colors, all of which you can see by invoking `fatty`'s CLI command `colors`.
        
        The special color `default` means to inherit colors from the underlying terminal program.
    
    2.  Attributes
    
        Each role can also have non-color attributes applied by specifying an `attrs` list. Supported attributes are `bold`, `dim`, `italic`, `underline`, and `reverse`. Italic is emitted by the truecolor renderer and by markdown ANSI output, but curses terminals may display it inconsistently or not at all.
    
    3.  Frame Style
    
        In addition, one role, `popup_frame:`, in addition to these have two attributes for styling the "frame" drawn around popup:
        
        | `border:`  | single or double  |
        | `corners:` | rounded or square |
    
    4.  An Example Theme
    
        ```yaml
        name: example
        inherit: null
        
        output:
          fg: "#d8dee9"
          bg: "#2e3440"
        
        input:
          fg: "#eceff4"
          bg: "#3b4252"
          attrs: [bold]
        
        input_suggestion:
          fg: "#81a1c1"
          bg: "#3b4252"
        
        cursor:
          fg: "#2e3440"
          bg: "#88c0d0"
        
        region:
          fg: "#2e3440"
          bg: "#88c0d0"
        
        info:
          fg: "#d8dee9"
          bg: "#2e3440"
        
        good:
          fg: green
          bg: "#2e3440"
        
        warn:
          fg: "#2e3440"
          bg: "#ebcb8b"
        
        error:
          fg: "#eceff4"
          bg: "#bf616a"
        
        pager_status:
          fg: black
          bg: lightgreen
        
        search_input:
          fg: black
          bg: cyan
        
        match_current:
          fg: black
          bg: yellow
        
        match_other:
          fg: black
          bg: lightgray
        
        popup:
          fg: "#d8dee9"
          bg: "#3b4252"
        
        popup_input:
          fg: "#eceff4"
          bg: "#434c5e"
        
        popup_selection:
          fg: "#2e3440"
          bg: "#88c0d0"
        
        popup_counts:
          fg: "#2e3440"
          bg: white
        
        popup_frame:
          fg: "#81a1c1"
          bg: "#3b4252"
          border: single
          corners: rounded
        ```
        
        Fatty synthesizes alert variants from the base `alert` role and the semantic roles:
        
        ```org
        alert_info
        alert_good
        alert_warn
        alert_error
        ```
        
        You normally do not need to define those directly.
        
        Markdown rendering uses additional roles. You can define them directly:
        
        ```yaml
        markdown_h1:
        fg: yellow
        bg: navy
        attrs: [bold]
        
        markdown_code:
        fg: lightgreen
        bg: black
        ```
        
        Or you can group them under `markdown` without the `markdown_` prefix:
        
        ```yaml
        markdown:
        h1:
        fg: yellow
        bg: navy
        attrs: [bold]
        code:
        fg: lightgreen
        bg: black
        link:
        fg: cyan
        bg: navy
        attrs: [underline]
        ```
        
        Useful markdown roles include:
        
        ```org
        markdown_h1
        markdown_h2
        markdown_h3
        markdown_code
        markdown_code_gutter
        markdown_strong
        markdown_emphasis
        markdown_link
        markdown_url
        markdown_quote_gutter
        markdown_highlight
        markdown_table_header
        markdown_table_cell
        markdown_underline
        markdown_hrule
        ```
        
        The `popup_frame` role also accepts border options:
        
        ```yaml
        popup_frame:
        fg: yellow
        bg: navy
        border: single
        corners: rounded
        ```
        
        Available border and corner values are intentionally small and portable. The current built-in themes use:
        
        ```yaml
        border: single
        corners: rounded
        ```
        
        and:
        
        ```yaml
        border: ascii
        corners: square
        ```
        
        Theme changes update the renderer immediately.


<a id="orga5dda0b"></a>

## Plugins
