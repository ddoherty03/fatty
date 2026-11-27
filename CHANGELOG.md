- [Version 0.99.12.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-27 Fri]</span></span>](#org5c6950f)
- [Version 0.99.12.5 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>](#org0adaf1f)
- [Version 0.99.12.4 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>](#orga80383a)
- [Version 0.99.12.3 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-25 Wed]</span></span>](#org40c42f2)
- [Version 0.99.12.2 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>](#orgf81d41c)
- [Version 0.99.12.1 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>](#org051c612)
- [Version 0.99.12.0 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-21 Sat]</span></span>](#orgb9a830a)
- [Version 0.99.10.0 and 0.99.11.0](#org4eef614)
- [Version 0.99.9.0](#org2ee023e)
- [Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>](#org2b30c37)
- [Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>](#orgf65182b)
- [Version 1.0.0](#orga0b2c38)


<a id="org5c6950f"></a>

# Version 0.99.12.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-27 Fri]</span></span>

-   Keybindings help&mdash;and several other modal screens&mdash;don’t own a popup window. The fix now falls back to the normal input window for those screens


<a id="org0adaf1f"></a>

# Version 0.99.12.5 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>

-   fix losing of cursor in popups during scrolling.


<a id="orga80383a"></a>

# Version 0.99.12.4 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-26 Thu]</span></span>

-   further tweaks to terminal background restore manifested in Windows terminal


<a id="org40c42f2"></a>

# Version 0.99.12.3 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-25 Wed]</span></span>

-   fixed failure of full-width background for certain messages to output.


<a id="orgf81d41c"></a>

# Version 0.99.12.2 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>

-   fixed errant bracketed-paste code leak in Windows


<a id="org051c612"></a>

# Version 0.99.12.1 <span class="timestamp-wrapper"><span class="timestamp">[2026-11-24 Tue]</span></span>

-   Install the patched curses binding automatically through fatty-curses; no separate fork installation is needed for Windows suspension.
-   Restore normal colors, line breaks, and wrapping for external Windows commands while Fatty is suspended.
-   Avoid printing a stray cursor-reset character when exiting on Windows.


<a id="orgb9a830a"></a>

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


<a id="org4eef614"></a>

# Version 0.99.10.0 and 0.99.11.0

-   Rotate log files after 5M; keep 20
-   Add markdown\_now for immediate rendering of markdown to output.


<a id="org2ee023e"></a>

# Version 0.99.9.0

Handle raw CSI sequences and extend keydefs.yml to handle them.

Fatty recognizes raw CSI navigation sequences, including modified arrows, Home/End, Insert/Delete, and PageUp/PageDown. An unsupported complete CSI sequence is reported as an undefined key, rather than


<a id="org2b30c37"></a>

# Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>

-   Recognize Backspace and Meta-Backspace when terminals send raw DEL (127), including FreeBSD's XFCE terminal, without requiring custom key definitions.
-   Preserve the forward Delete key and user-defined key mappings.


<a id="orgf65182b"></a>

# Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>

-   Fix the truecolor display going blank after returning from an external command.
-   Add `clear_now` to clear and immediately redraw the output pane from a callback.


<a id="orga0b2c38"></a>

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
