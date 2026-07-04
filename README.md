- [Introduction](#org13cd0c8)
- [Quick Start](#org06b4cd9)
  - [Installing](#org3d31238)
  - [Trying it Out with the \`fatty\` Demo](#orgdf2c44e)
    - [Builtin commands](#orgffb34cf)
    - [Screenshots](#org73fe5da)
- [Quick Start](#orge7ddb7e)
- [Usage](#orgd96d7c5)
  - [Launching a Fatty Terminal with `on_accept`](#org7547b15)
  - [Adding a Callback to `on_accept`](#orgfad0791)
    - [`append(text, follow: true)`](#org2b3de59)
    - [`append_now(text, follow: true)`](#org04a8160)
    - [`markdown(text)`](#orge1164e1)
    - [`status(text, role: :info)`](#orgf4f444a)
    - [`good(text)`](#org1c68603)
    - [`info(text)`](#orgafd8644)
    - [`warn(text)`](#org4e41c0e)
    - [`error(text)`](#org31d8bbd)
    - [`oops(text)`](#orgdb99288)
    - [`alert(text, role: :info)`](#org7fb2a00)
    - [ANSI Colors in Output](#org1da9625)
    - [`prompt(prompt, initial: "", cancel_value: nil, history_key: nil, save_history: true)`](#org13b4535)
    - [`add_progress(label:, total: nil, style: :percent, role: :info, width: 40)`](#orgcb70526)
    - [`choose(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`](#orgdf2b8ef)
    - [`choose_multi(prompt, choices:, cancel_value: nil)`](#org880e8e8)
    - [`confirm(prompt, yes_label: "Yes", no_label: "No", cancel_value: false)`](#orgc8a5fae)
    - [`menu(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)`](#orga4e7e2e)
    - [`environment`](#orgbf4a3e3)
- [Default Interaction](#org52e579d)
  - [Parts of the Screen](#orgd6fdd60)
    - [Input Field](#org5469986)
    - [Output Pane](#org7995b10)
    - [Status Area](#orga9c83b4)
    - [Alert  Area](#org6179d0b)
  - [Command-line Editing](#org88ab464)
  - [Keybindings](#org68ad2f1)
    - [Input Context](#orgc3aa8b4)
    - [Paging Context](#org6ab7492)
  - [Paging](#orga1370f7)
  - [Markdown](#orga55c0a0)
    - [Forced line breaks](#org0b726e9)
- [Configuration](#orge1c2a32)
  - [Key Codes](#org0119c82)
  - [Key Bindings](#org354efac)
  - [Themes](#orgcbd4fa2)
  - [Plugins](#orgce67592)

#+PROPERTY: header-args:ruby :results value :colnames no :hlines yes :exports both :dir "./"
#+PROPERTY: header-args:ruby+ :wrap example :session fatty_session :eval yes
#+PROPERTY: header-args:ruby+ :prologue "$:.unshift('./lib') unless $:.first == './lib'; require 'fatty'"
#+PROPERTY: header-args:ruby+ :ruby "bundle exec irb"
#+PROPERTY: header-args:sh :exports code :eval no
#+PROPERTY: header-args:bash :exports code :eval no

[![CI](https://github.com/ddoherty03/fatty/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ddoherty03/fatty/actions/workflows/main.yml)


<a id="org13cd0c8"></a>

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


<a id="org06b4cd9"></a>

# Quick Start


<a id="org3d31238"></a>

## Installing

`Fatty` is a ruby gem, so it can be installed with

```sh
$ gem install fatty
```


<a id="orgdf2c44e"></a>

## Trying it Out with the \`fatty\` Demo

Once installed, you can try out `fatty` with the included program called `fatty`. It allows you to easily exercise all of the important features of the `fatty` library. At a normal shell prompt simply type `fatty`, and it will launch the `fatty` demo program.

Once inside `fatty` you will be prompted with a prompt that names your current directory. Type `help` to get a summary of the builtin commands available to you. If you type anything other than a builtin command, `fatty` attempts to run it as a shell command and displays the output.


<a id="orgffb34cf"></a>

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


<a id="org73fe5da"></a>

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


<a id="orge7ddb7e"></a>

# Quick Start


<a id="orgd96d7c5"></a>

# Usage


<a id="org7547b15"></a>

## Launching a Fatty Terminal with `on_accept`

You can launch a `Fatty` terminal session that does arbitrary processing of an edited command line and returns a String to be displayed on the output pane, as shown in this file that we'll call `loudrev`:

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

When a `fatty` application runs, `fatty` installs a few files if they do not exists:

-   a history file at `~/.fatty_history`
-   a config directory at `~/.config/fatty` that contains
    -   `config.yml`, the main configuration file
    -   `keydefs.yml`, a file for associating keycodes emitted by the underlying terminal with names when curses does not do so automatically,
    -   `keybindings.yml`, a file for associating named keys with actions above and beyond the emacs bindings that are used by default, and
    -   `themes`, a directory of pre-defined theme definitions that you can choose from and add to by adding your own themes.


<a id="orgfad0791"></a>

## Adding a Callback to `on_accept`

The `on_accept` proc can have a second parameter named whatever you like that serves as a callback into certain facilities provided by `fatty`. Here is a variation of the prior example that also echoes the original typed string into the so-called status area:

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

This callback parameter responds to several methods that allow your application to interact with the user:


<a id="org2b3de59"></a>

### `append(text, follow: true)`

Add the given text to the output pane. After a full page of output is produced, enter paging mode so the user can view the output at leisure and search the output. If `follow` is true, keep the output pane's viewport covering the last lines of output.


<a id="org04a8160"></a>

### `append_now(text, follow: true)`

Like `append`, but display output as it is produced rather than wait for a full page to be produced.


<a id="orge1164e1"></a>

### `markdown(text)`

Render the given text as markdown source according to the current theme then `append` the result to the output pane.


<a id="orgf4f444a"></a>

### `status(text, role: :info)`

Display the text in the "status" area, the lines immediately above the input field, using one of the following "roles":

-   **:good:** colored according something affirming according to the theme, usually something greenish;
-   **:info:** colored something neutral simply for informational purposes;
-   **:warn:** colored something to suggest caution, usually something in the orange to yellow range;
-   **:error:** colored something to suggest danger, usually some tone of red.


<a id="org1c68603"></a>

### `good(text)`

Display the text in the status area with the role :good.


<a id="orgafd8644"></a>

### `info(text)`

Display the text in the status area with the role :info.


<a id="org4e41c0e"></a>

### `warn(text)`

Display the text in the status area with the role :warn.


<a id="org31d8bbd"></a>

### `error(text)`

Display the text in the status area with the role :error.


<a id="orgdb99288"></a>

### `oops(text)`

An alias for `error(text)`


<a id="org7fb2a00"></a>

### `alert(text, role: :info)`

Display the text in the one-line alert panel just below the input field. In the alert panel, the role only controls the foreground color, not the background.


<a id="org1da9625"></a>

### ANSI Colors in Output

Text passed to `append`, `append_now`, `status`, and `alert` may contain ANSI SGR color/style sequences. Fatty interprets those sequences relative to the current theme role, so an ANSI reset returns to the active Fatty role rather than to the terminal's physical default colors. `fatty` includes the nice [`Rainbow` gem](https://github.com/ku1ik/rainbow) for colorizing text as a convenience.


<a id="org13b4535"></a>

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


<a id="orgcb70526"></a>

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


<a id="orgdf2b8ef"></a>

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


<a id="org880e8e8"></a>

### `choose_multi(prompt, choices:, cancel_value: nil)`

Present a set of `choices:`, which can either be

-   an Array whose items are converted to `Strings` and presented as choices
-   a Hash whose keys converted to `Strings` and presented as choices

`choose_multi` returns

-   a `Hash` whose keys and values are the user's selections if `choices:` was an `Array` of `Strings`,
-   a `Hash` whose keys and values are those selected from the `choices:` `Hash` if `choices:` was an `Hash`,
-   or the `cancel_value` if the user canceled the selection with C-c or C-g.

The `prompt` String (by default "Choose Many") can guide the user about the purpose of the choices.


<a id="orgc8a5fae"></a>

### `confirm(prompt, yes_label: "Yes", no_label: "No", cancel_value: false)`

Present the user with a simple Yes/No choice using your choice of ways to express "Yes" or "No" with `yes_label:` and `no_label:`.

`confirm` returns `true` for "Yes" and `false` for "No."

`confirm` will return `false` on cancellation with C-c or C-g unless you provide an alternative `cancel_value:`, in which case it returns that.


<a id="orga4e7e2e"></a>

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


<a id="orgbf4a3e3"></a>

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


<a id="org52e579d"></a>

# Default Interaction


<a id="orgd6fdd60"></a>

## Parts of the Screen


<a id="org5469986"></a>

### Input Field

Just above the bottom of the screen where all the action takes place: it is a line for editing the input. It displays a prompt followed by an area in which you build the command line using `fatty's` editing facilities.


<a id="org7995b10"></a>

### Output Pane

Most of the top part of the screen is reserved for displaying whatever output is sent to it with the `on_accept` callback to the `Terminal`. It can render colored ANSI-encoded strings and will page long output so you can view it a page at a time and even search the output.


<a id="orga9c83b4"></a>

### Status Area

The one to four lines just above the Input Field that displays output to the user that is out of band for the Output Pane. Brief messages of confirmation, warning, or error can be displayed there so as to get the user's immediate attention. Progress bars also render there where their visibility is made prominent.


<a id="org6179d0b"></a>

### Alert  Area

Alerts are short-lived, non-scrolling messages shown below the input field. They are intended for user-visible conditions that require attention. `Fatty` uses this area to warn the user of unrecognized key codes and of unbound key presses.


<a id="org88ab464"></a>

## Command-line Editing


<a id="org68ad2f1"></a>

## Keybindings

The following tables explain the keybindings available in \`fatty\` in different contexts. Named keys are indicated by \`:name\` and key categories, such as \`<digits>\` are indicated with brackets.


<a id="orgc3aa8b4"></a>

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
| M-<digit>  | accumulate count argument                              |
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


<a id="org6ab7492"></a>

### Paging Context

By default, \`fatty\` sends output to the large output pane, and if the output is more than one screen long presents a paging environment for viewing and searching the environment.

| Key   | Description               |
|----- |------------------------- |
| :up   | move output one line up   |
| k     | move output one line up   |
| :down | move output one line down |
| j     | move output one line down |
|       |                           |


<a id="orga1370f7"></a>

## Paging


<a id="orga55c0a0"></a>

## Markdown


<a id="org0b726e9"></a>

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


<a id="orge1c2a32"></a>

# Configuration


<a id="org0119c82"></a>

## Key Codes


<a id="org354efac"></a>

## Key Bindings


<a id="orgcbd4fa2"></a>

## Themes


<a id="orgce67592"></a>

## Plugins
