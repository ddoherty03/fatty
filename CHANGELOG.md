- [Version 0.99.10.0 and 0.99.11.0](#orgc877e67)
- [Version 0.99.9.0](#orga3cb069)
- [Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>](#org7ebd8c8)
- [Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>](#orgb2ee05a)
- [Version 1.0.0](#org9181e0d)


<a id="orgc877e67"></a>

# Version 0.99.10.0 and 0.99.11.0

-   Rotate log files after 5M; keep 20
-   Add markdown\_now for immediate rendering of markdown to output.


<a id="orga3cb069"></a>

# Version 0.99.9.0

Handle raw CSI sequences and extend keydefs.yml to handle them.

Fatty recognizes raw CSI navigation sequences, including modified arrows, Home/End, Insert/Delete, and PageUp/PageDown. An unsupported complete CSI sequence is reported as an undefined key, rather than


<a id="org7ebd8c8"></a>

# Version 0.99.8.7 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-06 Tue]</span></span>

-   Recognize Backspace and Meta-Backspace when terminals send raw DEL (127), including FreeBSD's XFCE terminal, without requiring custom key definitions.
-   Preserve the forward Delete key and user-defined key mappings.


<a id="orgb2ee05a"></a>

# Version 0.99.8.6 <span class="timestamp-wrapper"><span class="timestamp">[2026-10-04 Sun]</span></span>

-   Fix the truecolor display going blank after returning from an external command.
-   Add `clear_now` to clear and immediately redraw the output pane from a callback.


<a id="org9181e0d"></a>

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
