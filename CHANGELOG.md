- [Unreleased](#orgcf68a0c)
- [Version 0.99.10.0 and 0.99.11.0](#org6089e3e)
- [Version 0.99.9.0](#org9bfc742)
- [Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>](#orgc10f16e)
- [Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>](#org3c058eb)
- [Version 1.0.0](#org4297ad4)


<a id="orgcf68a0c"></a>

# Unreleased

-   Complete Windows backslash paths, quoted filenames, and case-insensitive prefixes.
-   Ship the markdown demo files and report missing files accurately.
-   Include Windows modified navigation, keypad, function-key, and Alt-character definitions.
-   Recognize native Windows Alt-Backspace as delete-previous-word.
-   Accept Control-h as Backspace in text fields, including Windows consoles.
-   Show the truecolor prompt immediately at startup and preserve Windows ANSI colors.
-   Avoid a Windows hang when capturing shell-command output such as dir.
-   Fix Windows truecolor output appearing only after leaving the interface.
-   Stop loading the Ruby debugger during normal startup, avoiding a Windows shutdown hang. Load console sizing support explicitly.
-   Prefer the portable Curses.endwin binding for suspension when available.
-   Require fat\_config 0.8.1 for Windows configuration paths.
-   Allow keyboard-only operation when curses has no mouse support.
-   Report unsupported terminal suspension when requested instead of failing while loading Fatty.
-   Recognize Windows PATH separators in the demonstration shell.


<a id="org6089e3e"></a>

# Version 0.99.10.0 and 0.99.11.0

-   Rotate log files after 5M; keep 20
-   Add markdown\_now for immediate rendering of markdown to output.


<a id="org9bfc742"></a>

# Version 0.99.9.0

Handle raw CSI sequences and extend keydefs.yml to handle them.

Fatty recognizes raw CSI navigation sequences, including modified arrows, Home/End, Insert/Delete, and PageUp/PageDown. An unsupported complete CSI sequence is reported as an undefined key, rather than


<a id="orgc10f16e"></a>

# Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>

-   Recognize Backspace and Meta-Backspace when terminals send raw DEL (127), including FreeBSD's XFCE terminal, without requiring custom key definitions.
-   Preserve the forward Delete key and user-defined key mappings.


<a id="org3c058eb"></a>

# Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>

-   Fix the truecolor display going blank after returning from an external command.
-   Add `clear_now` to clear and immediately redraw the output pane from a callback.


<a id="org4297ad4"></a>

# Version 1.0.0

Initial stable release.

-   Curses and truecolor renderers
-   Shell, output, prompt, menu, search, and progress sessions
-   Command-based terminal and session routing
-   Completion, autosuggestion, and history support
-   Status and alert displays
-   Modal workflows
-   Pager and scrolling modes
-   Resize handling
-   Configurable themes and key maps
