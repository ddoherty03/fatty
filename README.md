- [Introduction](#org73a5f3b)
- [Quick Start](#orgbe386ea)
  - [Installing](#org534febf)
  - [Trying it Out](#orga167ece)
- [Usage](#orgf62f7db)
  - [Launching a Fatty Terminal with `on_accept`](#org6a0caf7)
- [Reading Keys](#orga33015f)
- [Fatty Help](#org835b5dd)
  - [The `fatty` demo command](#org6b6022e)
  - [Builtin commands](#org17bbd3b)
  - [Keybindings](#org5b7d045)
    - [Input Context](#org741c122)
    - [Paging Context](#orga15f377)
- [Alerts](#orgdc3e51a)
- [Markdown](#orga6f279a)
  - [Forced line breaks](#org191a975)

#+PROPERTY: header-args:ruby :results value :colnames no :hlines yes :exports both :dir "./"
#+PROPERTY: header-args:ruby+ :wrap example :session fatty_session :eval yes
#+PROPERTY: header-args:ruby+ :prologue "$:.unshift('./lib') unless $:.first == './lib'; require 'fatty'"
#+PROPERTY: header-args:ruby+ :ruby "bundle exec irb"
#+PROPERTY: header-args:sh :exports code :eval no
#+PROPERTY: header-args:bash :exports code :eval no

[![CI](https://github.com/ddoherty03/fatty/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ddoherty03/fatty/actions/workflows/main.yml)


<a id="org73a5f3b"></a>

# Introduction

`Fatty` aims to provide a full-featured command-line environment that provides:

1.  an editing command-line input,
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
12. processes completed command-lines with a callback procedure of your choosing,
13. several user-interface widgets such a selection popups, prompt for input, etc.,
14. a set of progress indicators you can use to display to the end user,
15. a way to render markdown to the output pane,

In other words, fatty allows you to write a terminal-based REPL of your choosing but takes care of all the difficult parts.

`Fatty` is written entirely in Ruby and was born from my frustrations at the limitations of libraries like `readline` and `reline`. It relies on `curses` and `truecolor` for low-level rendering and is surprisingly snappy.

`Fatty` is *not* a terminal emulator but runs on top of one.


<a id="orgbe386ea"></a>

# Quick Start


<a id="org534febf"></a>

## Installing

`Fatty` is a ruby gem, so it can be installed with

```sh
$ gem install fatty
```


<a id="orga167ece"></a>

## Trying it Out

Once installed, you can try out `fatty` with the included program called `fatty`. It allows you to easily exercise all of the important features of the `fatty` library. At a normal shell prompt simply type `fatty`, and it will launch the `fatty` demo program.

Once inside `fatty` you will be prompted with a prompt that names your current directory. Type `help` to get a summary of the builtin commands available to you. If you type anything other than a builtin command, `fatty` attempts to run it as a shell command and displays the output.


<a id="orgf62f7db"></a>

# Usage


<a id="org6a0caf7"></a>

## Launching a Fatty Terminal with `on_accept`

You can launch a `Fatty` terminal session that does arbitrary processing of an edited command line as show in this file that we'll call `loudrev`:

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

```

```

Now you have an interactive application that allows you to type text and see what it looks like when written backwards in uppercase letters. It's as easy as that!

On running a fatty application, it installs a few files if they do not exists:

-   a history file at `~/.fatty_history`
-   a config directory at `~/.config/fatty` that contains
    -   `config.yml`, the main configuration file
    -   `keydefs.yml`, a file for associating keycodes emitted by the underlying terminal with names when curses does not do so automatically,
    -   `keybindings.yml`, a file for associating named keys with actions above and beyond the emacs bindings that are used by default, and
    -   `themes`, a directory of pre-defined theme definitions that you can choose from and add to by adding your own themes.


<a id="orga33015f"></a>

# Reading Keys

Shift/Ctrl/Meta F-keys are normalized when ncurses provides distinct constants.


<a id="org835b5dd"></a>

# Fatty Help


<a id="org6b6022e"></a>

## The `fatty` demo command

When you `fatty`, it operates as a simple demo of the `fatty` gem by presenting an editable command-line using emacs key bindings. It has several builtin commands to demonstrate `fatty` features, and any command it does not recognized is handed off to the shell.


<a id="org17bbd3b"></a>

## Builtin commands

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


<a id="org5b7d045"></a>

## Keybindings

The following tables explain the keybindings available in \`fatty\` in different contexts. Named keys are indicated by \`:name\` and key categories, such as \`<digits>\` are indicated with brackets.


<a id="org741c122"></a>

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
| :down      | replace the line with the prior history item           |
| C-r        | search the history in a popup                          |
|            |                                                        |
| :enter     | feed the line to the on\_accept proc and page output   |
| M-:enter   | feed the line to the on\_accept proc and scroll output |
| C-c        | quit \`fatty\`                                         |
| C-d        | quit \`fatty\` only if the input line is empty         |
| C-l        | clear the output pane                                  |
|            |                                                        |


<a id="orga15f377"></a>

### Paging Context

By default, \`fatty\` sends output to the large output pane, and if the output is more than one screen long presents a paging environment for viewing and searching the environment.

| Key   | Description               |
|----- |------------------------- |
| :up   | move output one line up   |
| k     | move output one line up   |
| :down | move output one line down |
| j     | move output one line down |
|       |                           |


<a id="orgdc3e51a"></a>

# Alerts

Alerts are short-lived, non-scrolling messages shown below the input line. They are intended for user-visible conditions that require attention.


<a id="orga6f279a"></a>

# Markdown


<a id="org191a975"></a>

## Forced line breaks

Use `<br>` to force a line break.

```
This line has a forced line break <br> and this should appear on the next line.
```

will render as

```
This line has a forced line break
and this should appear on the next line.
```
