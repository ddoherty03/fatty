- [Version 0.99.12.4 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>](#org09909ed)
- [Version 0.99.12.3 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-25 Wed]</span></span>](#org7afca9c)
- [Version 0.99.12.2 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>](#org57b90a8)
- [Version 0.99.12.1 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>](#orgf4ec6fb)
- [Version 0.99.12.0 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-21 Sat]</span></span>](#org03e6834)
- [Version 0.99.10.0 and 0.99.11.0](#org6c9fc39)
- [Version 0.99.9.0](#org3b676b4)
- [Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>](#orgb83f503)
- [Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>](#orge5d46af)
- [Version 1.0.0](#orgff5b791)


<a id="org09909ed"></a>

# Version 0.99.12.4 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>

-   further tweaks to terminal background restore manifested in Windows terminal


<a id="org7afca9c"></a>

# Version 0.99.12.3 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-25 Wed]</span></span>

-   fixed failure of full-width background for certain messages to output.


<a id="org57b90a8"></a>

# Version 0.99.12.2 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>

-   fixed errant bracketed-paste code leak in Windows


<a id="orgf4ec6fb"></a>

# Version 0.99.12.1 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>

-   Install the patched curses binding automatically through fatty-curses; no separate fork installation is needed for Windows suspension.
-   Restore normal colors, line breaks, and wrapping for external Windows commands while Fatty is suspended.
-   Avoid printing a stray cursor-reset character when exiting on Windows.


<a id="org03e6834"></a>

# Version 0.99.12.0 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-21 Sat]</span></span>

-   Improve Windows support, with all demo commands tested on Windows 11.
-   Complete Windows paths with backslashes, quoted filenames, and case-insensitive matching.
-   Recognize combined Control/Alt keyboard shortcuts while preserving AltGr text entry.
-   Improve Backspace, navigation, function-key, and numeric-keypad handling, including keypad Enter.
-   Detect truecolor support in Windows Terminal.
-   Fix missing or delayed Windows prompts and colors.
-   Fix Windows hangs during shell commands and shutdown.
-   Display Windows shell output containing accented characters without crashing.
-   Support terminal suspension with the patched Windows curses build; report clearly when suspension is unavailable.
-   Allow keyboard-only operation when mouse support is unavailable.
-   Include the Markdown demo files in the installed gem.
-   Require fat\_config 0.8.1 or later for Windows configuration paths.


<a id="org6c9fc39"></a>

# Version 0.99.10.0 and 0.99.11.0

-   Rotate log files after 5M; keep 20
-   Add markdown\_now for immediate rendering of markdown to output.


<a id="org3b676b4"></a>

# Version 0.99.9.0

Handle raw CSI sequences and extend keydefs.yml to handle them.

Fatty recognizes raw CSI navigation sequences, including modified arrows, Home/End, Insert/Delete, and PageUp/PageDown. An unsupported complete CSI sequence is reported as an undefined key, rather than


<a id="orgb83f503"></a>

# Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>

-   Recognize Backspace and Meta-Backspace when terminals send raw DEL (127), including FreeBSD's XFCE terminal, without requiring custom key definitions.
-   Preserve the forward Delete key and user-defined key mappings.


<a id="orge5d46af"></a>

# Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>

-   Fix the truecolor display going blank after returning from an external command.
-   Add `clear_now` to clear and immediately redraw the output pane from a callback.


<a id="orgff5b791"></a>

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
