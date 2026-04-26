# frozen_string_literal: true
#
# These are the constants the Curses library defines for keys:
#
# - KEY_A1 :: A1 Upper left of keypad
# - KEY_A3 :: A3 Upper right of keypad
# - KEY_B2 :: B2 Center of keypad
# - KEY_BACKSPACE :: BACKSPACE Backspace
# - KEY_BEG :: BEG Beginning key
# - KEY_BREAK :: BREAK Break key
# - KEY_BTAB :: KEY_BTAB Back tab key
# - KEY_C1 :: C1 Lower left of keypad
# - KEY_C3 :: C3 Lower right of keypad
# - KEY_CANCEL :: CANCEL Cancel key
# - KEY_CATAB :: CATAB Clear all tabs
# - KEY_CLEAR :: CLEAR Clear Screen
# - KEY_CLOSE :: CLOSE Close key
# - KEY_COMMAND :: COMMAND Cmd (command) key
# - KEY_COPY :: COPY Copy key
# - KEY_CREATE :: CREATE Create key
# - KEY_CTAB :: CTAB Clear tab
# - KEY_CTRL_A :: Control A
# - KEY_CTRL_B :: Control B
# - KEY_CTRL_C :: Control C
# - KEY_CTRL_D :: Control D
# - KEY_CTRL_E :: Control E
# - KEY_CTRL_F :: Control F
# - KEY_CTRL_G :: Control G
# - KEY_CTRL_H :: Control H
# - KEY_CTRL_I :: Control I
# - KEY_CTRL_J :: Control J
# - KEY_CTRL_K :: Control K
# - KEY_CTRL_L :: Control L
# - KEY_CTRL_M :: Control M
# - KEY_CTRL_N :: Control N
# - KEY_CTRL_O :: Control O
# - KEY_CTRL_P :: Control P
# - KEY_CTRL_Q :: Control Q
# - KEY_CTRL_R :: Control R
# - KEY_CTRL_S :: Control S
# - KEY_CTRL_T :: Control T
# - KEY_CTRL_U :: Control U
# - KEY_CTRL_V :: Control V
# - KEY_CTRL_W :: Control W
# - KEY_CTRL_X :: Control X
# - KEY_CTRL_Y :: Control Y
# - KEY_CTRL_Z :: Control Z
# - KEY_DC :: DC Delete character
# - KEY_DL :: DL Delete line
# - KEY_DOWN :: DOWN the down arrow key
# - KEY_EIC :: EIC Enter insert char mode
# - KEY_END :: END End key
# - KEY_ENTER :: ENTER Enter or send
# - KEY_EOL :: EOL Clear to end of line
# - KEY_EOS :: EOS Clear to end of screen
# - KEY_EXIT :: EXIT Exit key
# - KEY_F0 :: Function 0
# - KEY_F1 :: Function 1
# - KEY_F10 :: Function 10
# - KEY_F11 :: Function 11
# - KEY_F12 :: Function 12
# - KEY_F13 :: Function 13
# - KEY_F14 :: Function 14
# - KEY_F15 :: Function 15
# - KEY_F16 :: Function 16
# - KEY_F17 :: Function 17
# - KEY_F18 :: Function 18
# - KEY_F19 :: Function 19
# - KEY_F2 :: Function 2
# - KEY_F20 :: Function 20
# - KEY_F21 :: Function 21
# - KEY_F22 :: Function 22
# - KEY_F23 :: Function 23
# - KEY_F24 :: Function 24
# - KEY_F25 :: Function 25
# - KEY_F26 :: Function 26
# - KEY_F27 :: Function 27
# - KEY_F28 :: Function 28
# - KEY_F29 :: Function 29
# - KEY_F3 :: Function 3
# - KEY_F30 :: Function 30
# - KEY_F31 :: Function 31
# - KEY_F32 :: Function 32
# - KEY_F33 :: Function 33
# - KEY_F34 :: Function 34
# - KEY_F35 :: Function 35
# - KEY_F36 :: Function 36
# - KEY_F37 :: Function 37
# - KEY_F38 :: Function 38
# - KEY_F39 :: Function 39
# - KEY_F4 :: Function 4
# - KEY_F40 :: Function 40
# - KEY_F41 :: Function 41
# - KEY_F42 :: Function 42
# - KEY_F43 :: Function 43
# - KEY_F44 :: Function 44
# - KEY_F45 :: Function 45
# - KEY_F46 :: Function 46
# - KEY_F47 :: Function 47
# - KEY_F48 :: Function 48
# - KEY_F49 :: Function 49
# - KEY_F5 :: Function 5
# - KEY_F50 :: Function 50
# - KEY_F51 :: Function 51
# - KEY_F52 :: Function 52
# - KEY_F53 :: Function 53
# - KEY_F54 :: Function 54
# - KEY_F55 :: Function 55
# - KEY_F56 :: Function 56
# - KEY_F57 :: Function 57
# - KEY_F58 :: Function 58
# - KEY_F59 :: Function 59
# - KEY_F6 :: Function 6
# - KEY_F60 :: Function 60
# - KEY_F61 :: Function 61
# - KEY_F62 :: Function 62
# - KEY_F63 :: Function 63
# - KEY_F7 :: Function 7
# - KEY_F8 :: Function 8
# - KEY_F9 :: Function 9
# - KEY_FIND :: FIND Find key
# - KEY_HELP :: HELP Help key
# - KEY_HOME :: HOME Home key (upward+left arrow)
# - KEY_IC :: IC Insert char or enter insert mode
# - KEY_IL :: IL Insert line
# - KEY_LEFT :: LEFT the left arrow key
# - KEY_LL :: LL Home down or bottom (lower left)
# - KEY_MARK :: MARK Mark key
# - KEY_MAX :: MAX The maximum allowed curses key value.
# - KEY_MESSAGE :: MESSAGE Message key
# - KEY_MIN :: MIN The minimum allowed curses key value.
# - KEY_MOUSE :: MOUSE Mouse event read
# - KEY_MOVE :: MOVE Move key
# - KEY_NEXT :: NEXT Next object key
# - KEY_NPAGE :: NPAGE Next page
# - KEY_OPEN :: OPEN Open key
# - KEY_OPTIONS :: OPTIONS Options key
# - KEY_PPAGE :: PPAGE Previous page
# - KEY_PREVIOUS :: PREVIOUS Previous object key
# - KEY_PRINT :: PRINT Print or copy
# - KEY_REDO :: REDO Redo key
# - KEY_REFERENCE :: REFERENCE Reference key
# - KEY_REFRESH :: REFRESH Refresh key
# - KEY_REPLACE :: REPLACE Replace key
# - KEY_RESET :: RESET Reset or hard reset
# - KEY_RESIZE :: RESIZE Screen Resized
# - KEY_RESTART :: RESTART Restart key
# - KEY_RESUME :: RESUME Resume key
# - KEY_RIGHT :: RIGHT the right arrow key
# - KEY_SAVE :: SAVE Save key
# - KEY_SBEG :: SBEG Shifted beginning key
# - KEY_SCANCEL :: SCANCEL Shifted cancel key
# - KEY_SCOMMAND :: SCOMMAND Shifted command key
# - KEY_SCOPY :: SCOPY Shifted copy key
# - KEY_SCREATE :: SCREATE Shifted create key
# - KEY_SDC :: SDC Shifted delete char key
# - KEY_SDL :: SDL Shifted delete line key
# - KEY_SELECT :: SELECT Select key
# - KEY_SEND :: SEND Shifted end key
# - KEY_SEOL :: SEOL Shifted clear line key
# - KEY_SEXIT :: SEXIT Shifted exit key
# - KEY_SF :: SF Scroll 1 line forward
# - KEY_SFIND :: SFIND Shifted find key
# - KEY_SHELP :: SHELP Shifted help key
# - KEY_SHOME :: SHOME Shifted home key
# - KEY_SIC :: SIC Shifted input key
# - KEY_SLEFT :: SLEFT Shifted left arrow key
# - KEY_SMESSAGE :: SMESSAGE Shifted message key
# - KEY_SMOVE :: SMOVE Shifted move key
# - KEY_SNEXT :: SNEXT Shifted next key
# - KEY_SOPTIONS :: SOPTIONS Shifted options key
# - KEY_SPREVIOUS :: SPREVIOUS Shifted previous key
# - KEY_SPRINT :: SPRINT Shifted print key
# - KEY_SR :: SR Scroll 1 line backward (reverse)
# - KEY_SREDO :: SREDO Shifted redo key
# - KEY_SREPLACE :: SREPLACE Shifted replace key
# - KEY_SRESET :: SRESET Soft (partial) reset
# - KEY_SRIGHT :: SRIGHT Shifted right arrow key
# - KEY_SRSUME :: SRSUME Shifted resume key
# - KEY_SSAVE :: SSAVE Shifted save key
# - KEY_SSUSPEND :: SSUSPEND Shifted suspend key
# - KEY_STAB :: STAB Set tab
# - KEY_SUNDO :: SUNDO Shifted undo key
# - KEY_SUSPEND :: SUSPEND Suspend key
# - KEY_UNDO :: UNDO Undo key
# - KEY_UP :: UP the up arrow key

# These are the integers returned by the constants in my experiments.
#
# KEY_SYM_MAP = {
#  409 => :KEY_MOUSE,
#  257 => :KEY_BREAK,
#  258 => :KEY_DOWN,
#  259 => :KEY_UP,
#  260 => :KEY_LEFT,
#  261 => :KEY_RIGHT,
#  262 => :KEY_HOME,
#  263 => :KEY_BACKSPACE,
#  264 => :KEY_F0,
#  265 => :KEY_F1,
#  266 => :KEY_F2,
#  267 => :KEY_F3,
#  268 => :KEY_F4,
#  269 => :KEY_F5,
#  270 => :KEY_F6,
#  271 => :KEY_F7,
#  272 => :KEY_F8,
#  273 => :KEY_F9,
#  274 => :KEY_F10,
#  275 => :KEY_F11,
#  276 => :KEY_F12,
#  277 => :KEY_F13,
#  278 => :KEY_F14,
#  279 => :KEY_F15,
#  280 => :KEY_F16,
#  281 => :KEY_F17,
#  282 => :KEY_F18,
#  283 => :KEY_F19,
#  284 => :KEY_F20,
#  285 => :KEY_F21,
#  286 => :KEY_F22,
#  287 => :KEY_F23,
#  288 => :KEY_F24,
#  289 => :KEY_F25,
#  290 => :KEY_F26,
#  291 => :KEY_F27,
#  292 => :KEY_F28,
#  293 => :KEY_F29,
#  294 => :KEY_F30,
#  295 => :KEY_F31,
#  296 => :KEY_F32,
#  297 => :KEY_F33,
#  298 => :KEY_F34,
#  299 => :KEY_F35,
#  300 => :KEY_F36,
#  301 => :KEY_F37,
#  302 => :KEY_F38,
#  303 => :KEY_F39,
#  304 => :KEY_F40,
#  305 => :KEY_F41,
#  306 => :KEY_F42,
#  307 => :KEY_F43,
#  308 => :KEY_F44,
#  309 => :KEY_F45,
#  310 => :KEY_F46,
#  311 => :KEY_F47,
#  312 => :KEY_F48,
#  313 => :KEY_F49,
#  314 => :KEY_F50,
#  315 => :KEY_F51,
#  316 => :KEY_F52,
#  317 => :KEY_F53,
#  318 => :KEY_F54,
#  319 => :KEY_F55,
#  320 => :KEY_F56,
#  321 => :KEY_F57,
#  322 => :KEY_F58,
#  323 => :KEY_F59,
#  324 => :KEY_F60,
#  325 => :KEY_F61,
#  326 => :KEY_F62,
#  327 => :KEY_F63,
#  328 => :KEY_DL,
#  329 => :KEY_IL,
#  330 => :KEY_DC,
#  331 => :KEY_IC,
#  332 => :KEY_EIC,
#  333 => :KEY_CLEAR,
#  334 => :KEY_EOS,
#  335 => :KEY_EOL,
#  336 => :KEY_SF,
#  337 => :KEY_SR,
#  338 => :KEY_NPAGE,
#  339 => :KEY_PPAGE,
#  340 => :KEY_STAB,
#  341 => :KEY_CTAB,
#  342 => :KEY_CATAB,
#  343 => :KEY_ENTER,
#  344 => :KEY_SRESET,
#  345 => :KEY_RESET,
#  346 => :KEY_PRINT,
#  347 => :KEY_LL,
#  348 => :KEY_A1,
#  349 => :KEY_A3,
#  350 => :KEY_B2,
#  351 => :KEY_C1,
#  352 => :KEY_C3,
#  353 => :KEY_BTAB,
#  354 => :KEY_BEG,
#  355 => :KEY_CANCEL,
#  356 => :KEY_CLOSE,
#  357 => :KEY_COMMAND,
#  358 => :KEY_COPY,
#  359 => :KEY_CREATE,
#  360 => :KEY_END,
#  361 => :KEY_EXIT,
#  362 => :KEY_FIND,
#  363 => :KEY_HELP,
#  364 => :KEY_MARK,
#  365 => :KEY_MESSAGE,
#  366 => :KEY_MOVE,
#  367 => :KEY_NEXT,
#  368 => :KEY_OPEN,
#  369 => :KEY_OPTIONS,
#  370 => :KEY_PREVIOUS,
#  371 => :KEY_REDO,
#  372 => :KEY_REFERENCE,
#  373 => :KEY_REFRESH,
#  374 => :KEY_REPLACE,
#  375 => :KEY_RESTART,
#  376 => :KEY_RESUME,
#  377 => :KEY_SAVE,
#  378 => :KEY_SBEG,
#  379 => :KEY_SCANCEL,
#  380 => :KEY_SCOMMAND,
#  381 => :KEY_SCOPY,
#  382 => :KEY_SCREATE,
#  383 => :KEY_SDC,
#  384 => :KEY_SDL,
#  385 => :KEY_SELECT,
#  386 => :KEY_SEND,
#  387 => :KEY_SEOL,
#  388 => :KEY_SEXIT,
#  389 => :KEY_SFIND,
#  390 => :KEY_SHELP,
#  391 => :KEY_SHOME,
#  392 => :KEY_SIC,
#  393 => :KEY_SLEFT,
#  394 => :KEY_SMESSAGE,
#  395 => :KEY_SMOVE,
#  396 => :KEY_SNEXT,
#  397 => :KEY_SOPTIONS,
#  398 => :KEY_SPREVIOUS,
#  399 => :KEY_SPRINT,
#  400 => :KEY_SREDO,
#  401 => :KEY_SREPLACE,
#  402 => :KEY_SRIGHT,
#  403 => :KEY_SRSUME,
#  404 => :KEY_SSAVE,
#  405 => :KEY_SSUSPEND,
#  406 => :KEY_SUNDO,
#  407 => :KEY_SUSPEND,
#  408 => :KEY_UNDO,
#  410 => :KEY_RESIZE,
#  511 => :KEY_MAX,
#  1 => :KEY_CTRL_A,
#  2 => :KEY_CTRL_B,
#  3 => :KEY_CTRL_C,
#  4 => :KEY_CTRL_D,
#  5 => :KEY_CTRL_E,
#  6 => :KEY_CTRL_F,
#  7 => :KEY_CTRL_G,
#  8 => :KEY_CTRL_H,
#  9 => :KEY_CTRL_I,
#  10 => :KEY_CTRL_J,
#  11 => :KEY_CTRL_K,
#  12 => :KEY_CTRL_L,
#  13 => :KEY_CTRL_M,
#  14 => :KEY_CTRL_N,
#  15 => :KEY_CTRL_O,
#  16 => :KEY_CTRL_P,
#  17 => :KEY_CTRL_Q,
#  18 => :KEY_CTRL_R,
#  19 => :KEY_CTRL_S,
#  20 => :KEY_CTRL_T,
#  21 => :KEY_CTRL_U,
#  22 => :KEY_CTRL_V,
#  23 => :KEY_CTRL_W,
#  24 => :KEY_CTRL_X,
#  25 => :KEY_CTRL_Y,
#  26 => :KEY_CTRL_Z
# }

#   MAP = {
#     9 => FatTerm::KeyEvent.new(key: :tab),
#     353 => FatTerm::KeyEvent.new(key: :backtab),
#     265 => FatTerm::KeyEvent.new(key: :f1),
#     277 => FatTerm::KeyEvent.new(key: :f1, shift: true),
#     289 => FatTerm::KeyEvent.new(key: :f1, ctrl: true),
#     301 => FatTerm::KeyEvent.new(key: :f1, shift: true, ctrl: true),
#     313 => FatTerm::KeyEvent.new(key: :f1, meta: true),
#     325 => FatTerm::KeyEvent.new(key: :f1, shift: true, meta: true),
#     266 => FatTerm::KeyEvent.new(key: :f2),
#     278 => FatTerm::KeyEvent.new(key: :f2, shift: true),
#     290 => FatTerm::KeyEvent.new(key: :f2, ctrl: true),
#     302 => FatTerm::KeyEvent.new(key: :f2, shift: true, ctrl: true),
#     314 => FatTerm::KeyEvent.new(key: :f2, meta: true),
#     326 => FatTerm::KeyEvent.new(key: :f2, shift: true, meta: true),
#     267 => FatTerm::KeyEvent.new(key: :f3),
#     279 => FatTerm::KeyEvent.new(key: :f3, shift: true),
#     291 => FatTerm::KeyEvent.new(key: :f3, ctrl: true),
#     303 => FatTerm::KeyEvent.new(key: :f3, shift: true, ctrl: true),
#     315 => FatTerm::KeyEvent.new(key: :f3, meta: true),
#     327 => FatTerm::KeyEvent.new(key: :f3, shift: true, meta: true),
#     268 => FatTerm::KeyEvent.new(key: :f4),
#     280 => FatTerm::KeyEvent.new(key: :f4, shift: true),
#     292 => FatTerm::KeyEvent.new(key: :f4, ctrl: true),
#     304 => FatTerm::KeyEvent.new(key: :f4, shift: true, ctrl: true),
#     316 => FatTerm::KeyEvent.new(key: :f4, meta: true),
#     328 => FatTerm::KeyEvent.new(key: :f4, shift: true, meta: true),
#     269 => FatTerm::KeyEvent.new(key: :f5),
#     281 => FatTerm::KeyEvent.new(key: :f5, shift: true),
#     293 => FatTerm::KeyEvent.new(key: :f5, ctrl: true),
#     305 => FatTerm::KeyEvent.new(key: :f5, shift: true, ctrl: true),
#     317 => FatTerm::KeyEvent.new(key: :f5, meta: true),
#     329 => FatTerm::KeyEvent.new(key: :f5, shift: true, meta: true),
#     270 => FatTerm::KeyEvent.new(key: :f6),
#     282 => FatTerm::KeyEvent.new(key: :f6, shift: true),
#     294 => FatTerm::KeyEvent.new(key: :f6, ctrl: true),
#     306 => FatTerm::KeyEvent.new(key: :f6, shift: true, ctrl: true),
#     318 => FatTerm::KeyEvent.new(key: :f6, meta: true),
#     # 330 duplicates the :delete key
#     # 330 => FatTerm::KeyEvent.new(key: :f6, shift: true, meta: true),
#     271 => FatTerm::KeyEvent.new(key: :f7),
#     283 => FatTerm::KeyEvent.new(key: :f7, shift: true),
#     295 => FatTerm::KeyEvent.new(key: :f7, ctrl: true),
#     307 => FatTerm::KeyEvent.new(key: :f7, shift: true, ctrl: true),
#     319 => FatTerm::KeyEvent.new(key: :f7, meta: true),
#     # 331 duplicates the :insert key
#     # 331 => FatTerm::KeyEvent.new(key: :f7, shift: true, meta: true),
#     272 => FatTerm::KeyEvent.new(key: :f8),
#     284 => FatTerm::KeyEvent.new(key: :f8, shift: true),
#     296 => FatTerm::KeyEvent.new(key: :f8, ctrl: true),
#     308 => FatTerm::KeyEvent.new(key: :f8, shift: true, ctrl: true),
#     320 => FatTerm::KeyEvent.new(key: :f8, meta: true),
#     332 => FatTerm::KeyEvent.new(key: :f8, shift: true, meta: true),
#     273 => FatTerm::KeyEvent.new(key: :f9),
#     285 => FatTerm::KeyEvent.new(key: :f9, shift: true),
#     297 => FatTerm::KeyEvent.new(key: :f9, ctrl: true),
#     309 => FatTerm::KeyEvent.new(key: :f9, shift: true, ctrl: true),
#     321 => FatTerm::KeyEvent.new(key: :f9, meta: true),
#     333 => FatTerm::KeyEvent.new(key: :f9, shift: true, meta: true),
#     274 => FatTerm::KeyEvent.new(key: :f10),
#     286 => FatTerm::KeyEvent.new(key: :f10, shift: true),
#     298 => FatTerm::KeyEvent.new(key: :f10, ctrl: true),
#     310 => FatTerm::KeyEvent.new(key: :f10, shift: true, ctrl: true),
#     322 => FatTerm::KeyEvent.new(key: :f10, meta: true),
#     334 => FatTerm::KeyEvent.new(key: :f10, shift: true, meta: true),
#     275 => FatTerm::KeyEvent.new(key: :f11),
#     287 => FatTerm::KeyEvent.new(key: :f11, shift: true),
#     299 => FatTerm::KeyEvent.new(key: :f11, ctrl: true),
#     311 => FatTerm::KeyEvent.new(key: :f11, shift: true, ctrl: true),
#     323 => FatTerm::KeyEvent.new(key: :f11, meta: true),
#     335 => FatTerm::KeyEvent.new(key: :f11, shift: true, meta: true),
#     276 => FatTerm::KeyEvent.new(key: :f12),
#     288 => FatTerm::KeyEvent.new(key: :f12, shift: true),
#     300 => FatTerm::KeyEvent.new(key: :f12, ctrl: true),
#     312 => FatTerm::KeyEvent.new(key: :f12, shift: true, ctrl: true),
#     324 => FatTerm::KeyEvent.new(key: :f12, meta: true),
#     # 336 duplicates the :down key
#     # 336 => FatTerm::KeyEvent.new(key: :f12, shift: true, meta: true),

#     331 => FatTerm::KeyEvent.new(key: :insert),
#     392 => FatTerm::KeyEvent.new(key: :insert, shift: true),
#     550 => FatTerm::KeyEvent.new(key: :insert, meta: true),
#     551 => FatTerm::KeyEvent.new(key: :insert, shift: true, meta: true),
#     552 => FatTerm::KeyEvent.new(key: :insert, ctrl: true),
#     553 => FatTerm::KeyEvent.new(key: :insert, shift: true, ctrl: true),
#     330 => FatTerm::KeyEvent.new(key: :delete),
#     383 => FatTerm::KeyEvent.new(key: :delete, shift: true),
#     531 => FatTerm::KeyEvent.new(key: :delete, meta: true),
#     532 => FatTerm::KeyEvent.new(key: :delete, shift: true, meta: true),
#     533 => FatTerm::KeyEvent.new(key: :delete, ctrl: true),
#     534 => FatTerm::KeyEvent.new(key: :delete, shift: true, ctrl: true),
#     262 => FatTerm::KeyEvent.new(key: :home),
#     391 => FatTerm::KeyEvent.new(key: :home, shift: true),
#     545 => FatTerm::KeyEvent.new(key: :home, meta: true),
#     546 => FatTerm::KeyEvent.new(key: :home, shift: true, meta: true),
#     547 => FatTerm::KeyEvent.new(key: :home, ctrl: true),
#     548 => FatTerm::KeyEvent.new(key: :home, shift: true, ctrl: true),
#     360 => FatTerm::KeyEvent.new(key: :end),
#     386 => FatTerm::KeyEvent.new(key: :end, shift: true),
#     540 => FatTerm::KeyEvent.new(key: :end, meta: true),
#     541 => FatTerm::KeyEvent.new(key: :end, shift: true, meta: true),
#     542 => FatTerm::KeyEvent.new(key: :end, ctrl: true),
#     543 => FatTerm::KeyEvent.new(key: :end, shift: true, ctrl: true),
#     339 => FatTerm::KeyEvent.new(key: :page_up),
#     398 => FatTerm::KeyEvent.new(key: :page_up, shift: true),
#     565 => FatTerm::KeyEvent.new(key: :page_up, meta: true),
#     566 => FatTerm::KeyEvent.new(key: :page_up, shift: true, meta: true),
#     567 => FatTerm::KeyEvent.new(key: :page_up, ctrl: true),
#     568 => FatTerm::KeyEvent.new(key: :page_up, shift: true, ctrl: true),
#     338 => FatTerm::KeyEvent.new(key: :page_down),
#     396 => FatTerm::KeyEvent.new(key: :page_down, shift: true),
#     560 => FatTerm::KeyEvent.new(key: :page_down, meta: true),
#     561 => FatTerm::KeyEvent.new(key: :page_down, shift: true, meta: true),
#     562 => FatTerm::KeyEvent.new(key: :page_down, ctrl: true),
#     563 => FatTerm::KeyEvent.new(key: :page_down, shift: true, ctrl: true),

#     258 => FatTerm::KeyEvent.new(key: :down),
#     336 => FatTerm::KeyEvent.new(key: :down, shift: true),
#     535 => FatTerm::KeyEvent.new(key: :down, meta: true),
#     536 => FatTerm::KeyEvent.new(key: :down, shift: true, meta: true),
#     537 => FatTerm::KeyEvent.new(key: :down, ctrl: true),
#     538 => FatTerm::KeyEvent.new(key: :down, shift: true, ctrl: true),
#     259 => FatTerm::KeyEvent.new(key: :up),
#     337 => FatTerm::KeyEvent.new(key: :up, shift: true),
#     576 => FatTerm::KeyEvent.new(key: :up, meta: true),
#     577 => FatTerm::KeyEvent.new(key: :up, shift: true, meta: true),
#     578 => FatTerm::KeyEvent.new(key: :up, ctrl: true),
#     579 => FatTerm::KeyEvent.new(key: :up, shift: true, ctrl: true),
#     260 => FatTerm::KeyEvent.new(key: :left),
#     393 => FatTerm::KeyEvent.new(key: :left, shift: true),
#     555 => FatTerm::KeyEvent.new(key: :left, meta: true),
#     556 => FatTerm::KeyEvent.new(key: :left, shift: true, meta: true),
#     557 => FatTerm::KeyEvent.new(key: :left, ctrl: true),
#     558 => FatTerm::KeyEvent.new(key: :left, shift: true, ctrl: true),
#     261 => FatTerm::KeyEvent.new(key: :right),
#     402 => FatTerm::KeyEvent.new(key: :right, shift: true),
#     570 => FatTerm::KeyEvent.new(key: :right, meta: true),
#     571 => FatTerm::KeyEvent.new(key: :right, shift: true, meta: true),
#     572 => FatTerm::KeyEvent.new(key: :right, ctrl: true),
#     573 => FatTerm::KeyEvent.new(key: :right, shift: true, ctrl: true),
#   }

# require_relative "../../key_event"

require 'curses'

module FatTerm
  module Curses
    CURSES_TO_EVENT = {
      # Special case for TAB.  Curses::KEY_CTRL_I may not get defined on all
      # platforms.
      9 => FatTerm::KeyEvent.new(key: :tab, raw: 9),
      ::Curses::KEY_RESIZE => FatTerm::KeyEvent.new(key: :resize, raw: ::Curses::KEY_RESIZE),
      ::Curses::KEY_BTAB => FatTerm::KeyEvent.new(key: :tab, shift: true, raw: ::Curses::KEY_BTAB),
      ::Curses::KEY_BACKSPACE => FatTerm::KeyEvent.new(key: :backspace, raw: ::Curses::KEY_BACKSPACE),
      ::Curses::KEY_F1 => FatTerm::KeyEvent.new(key: :f1, raw: ::Curses::KEY_F1),
      ::Curses::KEY_F13 => FatTerm::KeyEvent.new(key: :f1, shift: true, raw: ::Curses::KEY_F13),
      ::Curses::KEY_F25 => FatTerm::KeyEvent.new(key: :f1, ctrl: true, raw: ::Curses::KEY_F25),
      ::Curses::KEY_F37 => FatTerm::KeyEvent.new(key: :f1, shift: true, ctrl: true, raw: ::Curses::KEY_F37),
      ::Curses::KEY_F49 => FatTerm::KeyEvent.new(key: :f1, meta: true, raw: ::Curses::KEY_F49),
      ::Curses::KEY_F61 => FatTerm::KeyEvent.new(key: :f1, shift: true, meta: true, raw: ::Curses::KEY_F61),
      ::Curses::KEY_F2 => FatTerm::KeyEvent.new(key: :f2, raw: ::Curses::KEY_F2),
      ::Curses::KEY_F14 => FatTerm::KeyEvent.new(key: :f2, shift: true, raw: ::Curses::KEY_F14),
      ::Curses::KEY_F26 => FatTerm::KeyEvent.new(key: :f2, ctrl: true, raw: ::Curses::KEY_F26),
      ::Curses::KEY_F38 => FatTerm::KeyEvent.new(key: :f2, shift: true, ctrl: true, raw: ::Curses::KEY_F38),
      ::Curses::KEY_F50 => FatTerm::KeyEvent.new(key: :f2, meta: true, raw: ::Curses::KEY_F50),
      ::Curses::KEY_F62 => FatTerm::KeyEvent.new(key: :f2, shift: true, meta: true, raw: ::Curses::KEY_F62),
      ::Curses::KEY_F3 => FatTerm::KeyEvent.new(key: :f3, raw: ::Curses::KEY_F3),
      ::Curses::KEY_F15 => FatTerm::KeyEvent.new(key: :f3, shift: true, raw: ::Curses::KEY_F15),
      ::Curses::KEY_F27 => FatTerm::KeyEvent.new(key: :f3, ctrl: true, raw: ::Curses::KEY_F27),
      ::Curses::KEY_F39 => FatTerm::KeyEvent.new(key: :f3, shift: true, ctrl: true, raw: ::Curses::KEY_F39),
      ::Curses::KEY_F51 => FatTerm::KeyEvent.new(key: :f3, meta: true, raw: ::Curses::KEY_F51),
      ::Curses::KEY_F63 => FatTerm::KeyEvent.new(key: :f3, shift: true, meta: true, raw: ::Curses::KEY_F63),
      ::Curses::KEY_F4 => FatTerm::KeyEvent.new(key: :f4, raw: ::Curses::KEY_F4),
      ::Curses::KEY_F16 => FatTerm::KeyEvent.new(key: :f4, shift: true, raw: ::Curses::KEY_F16),
      ::Curses::KEY_F28 => FatTerm::KeyEvent.new(key: :f4, ctrl: true, raw: ::Curses::KEY_F28),
      ::Curses::KEY_F40 => FatTerm::KeyEvent.new(key: :f4, shift: true, ctrl: true, raw: ::Curses::KEY_F40),
      ::Curses::KEY_F52 => FatTerm::KeyEvent.new(key: :f4, meta: true, raw: ::Curses::KEY_F52),
      # KEY_DL: 328 => FatTerm::KeyEvent.new(key: :f4, shift: true, meta: true, raw: KEY_DL: 328),
      ::Curses::KEY_F5 => FatTerm::KeyEvent.new(key: :f5, raw: ::Curses::KEY_F5),
      ::Curses::KEY_F17 => FatTerm::KeyEvent.new(key: :f5, shift: true, raw: ::Curses::KEY_F17),
      ::Curses::KEY_F29 => FatTerm::KeyEvent.new(key: :f5, ctrl: true, raw: ::Curses::KEY_F29),
      ::Curses::KEY_F41 => FatTerm::KeyEvent.new(key: :f5, shift: true, ctrl: true, raw: ::Curses::KEY_F41),
      ::Curses::KEY_F53 => FatTerm::KeyEvent.new(key: :f5, meta: true, raw: ::Curses::KEY_F53),
      # KEY_IL: 329 => FatTerm::KeyEvent.new(key: :f5, shift: true, meta: true, raw: KEY_IL: 329),
      ::Curses::KEY_F6 => FatTerm::KeyEvent.new(key: :f6, raw: ::Curses::KEY_F6),
      ::Curses::KEY_F18 => FatTerm::KeyEvent.new(key: :f6, shift: true, raw: ::Curses::KEY_F18),
      ::Curses::KEY_F30 => FatTerm::KeyEvent.new(key: :f6, ctrl: true, raw: ::Curses::KEY_F30),
      ::Curses::KEY_F42 => FatTerm::KeyEvent.new(key: :f6, shift: true, ctrl: true, raw: ::Curses::KEY_F42),
      ::Curses::KEY_F54 => FatTerm::KeyEvent.new(key: :f6, meta: true, raw: ::Curses::KEY_F54),
      # 330 duplicates the :delete key
      # KEY_DC: 330 => FatTerm::KeyEvent.new(key: :f6, shift: true, meta: true, raw: 330 duplicates the :delete key
      # KEY_DC: 330),
      ::Curses::KEY_F7 => FatTerm::KeyEvent.new(key: :f7, raw: ::Curses::KEY_F7),
      ::Curses::KEY_F19 => FatTerm::KeyEvent.new(key: :f7, shift: true, raw: ::Curses::KEY_F19),
      ::Curses::KEY_F31 => FatTerm::KeyEvent.new(key: :f7, ctrl: true, raw: ::Curses::KEY_F31),
      ::Curses::KEY_F43 => FatTerm::KeyEvent.new(key: :f7, shift: true, ctrl: true, raw: ::Curses::KEY_F43),
      ::Curses::KEY_F55 => FatTerm::KeyEvent.new(key: :f7, meta: true, raw: ::Curses::KEY_F55),
      # 331 duplicates the :insert key
      # KEY_IC: 331 => FatTerm::KeyEvent.new(key: :f7, shift: true, meta: true),
      ::Curses::KEY_F8 => FatTerm::KeyEvent.new(key: :f8, raw: ::Curses::KEY_F8),
      ::Curses::KEY_F20 => FatTerm::KeyEvent.new(key: :f8, shift: true, raw: ::Curses::KEY_F20),
      ::Curses::KEY_F32 => FatTerm::KeyEvent.new(key: :f8, ctrl: true, raw: ::Curses::KEY_F32),
      ::Curses::KEY_F44 => FatTerm::KeyEvent.new(key: :f8, shift: true, ctrl: true, raw: ::Curses::KEY_F44),
      ::Curses::KEY_F56 => FatTerm::KeyEvent.new(key: :f8, meta: true, raw: ::Curses::KEY_F56),
      # KEY_EIC: 332 => FatTerm::KeyEvent.new(key: :f8, shift: true, meta: true),
      ::Curses::KEY_F9 => FatTerm::KeyEvent.new(key: :f9, raw: ::Curses::KEY_F9),
      ::Curses::KEY_F21 => FatTerm::KeyEvent.new(key: :f9, shift: true, raw: ::Curses::KEY_F21),
      ::Curses::KEY_F33 => FatTerm::KeyEvent.new(key: :f9, ctrl: true, raw: ::Curses::KEY_F33),
      ::Curses::KEY_F45 => FatTerm::KeyEvent.new(key: :f9, shift: true, ctrl: true, raw: ::Curses::KEY_F45),
      ::Curses::KEY_F57 => FatTerm::KeyEvent.new(key: :f9, meta: true, raw: ::Curses::KEY_F57),
      # KEY_CLEAR: 333 => FatTerm::KeyEvent.new(key: :f9, shift: true, meta: true),
      ::Curses::KEY_F10 => FatTerm::KeyEvent.new(key: :f10, raw: ::Curses::KEY_F10),
      ::Curses::KEY_F22 => FatTerm::KeyEvent.new(key: :f10, shift: true, raw: ::Curses::KEY_F22),
      ::Curses::KEY_F34 => FatTerm::KeyEvent.new(key: :f10, ctrl: true, raw: ::Curses::KEY_F34),
      ::Curses::KEY_F46 => FatTerm::KeyEvent.new(key: :f10, shift: true, ctrl: true, raw: ::Curses::KEY_F46),
      ::Curses::KEY_F58 => FatTerm::KeyEvent.new(key: :f10, meta: true, raw: ::Curses::KEY_F58),
      # KEY_EOS: 334 => FatTerm::KeyEvent.new(key: :f10, shift: true, meta: true),
      ::Curses::KEY_F11 => FatTerm::KeyEvent.new(key: :f11, raw: ::Curses::KEY_F11),
      ::Curses::KEY_F23 => FatTerm::KeyEvent.new(key: :f11, shift: true, raw: ::Curses::KEY_F23),
      ::Curses::KEY_F35 => FatTerm::KeyEvent.new(key: :f11, ctrl: true, raw: ::Curses::KEY_F35),
      ::Curses::KEY_F47 => FatTerm::KeyEvent.new(key: :f11, shift: true, ctrl: true, raw: ::Curses::KEY_F47),
      ::Curses::KEY_F59 => FatTerm::KeyEvent.new(key: :f11, meta: true, raw: ::Curses::KEY_F59),
      # KEY_EOL: 335 => FatTerm::KeyEvent.new(key: :f11, shift: true, meta: true),
      ::Curses::KEY_F12 => FatTerm::KeyEvent.new(key: :f12, raw: ::Curses::KEY_F12),
      ::Curses::KEY_F24 => FatTerm::KeyEvent.new(key: :f12, shift: true, raw: ::Curses::KEY_F24),
      ::Curses::KEY_F36 => FatTerm::KeyEvent.new(key: :f12, ctrl: true, raw: ::Curses::KEY_F36),
      ::Curses::KEY_F48 => FatTerm::KeyEvent.new(key: :f12, shift: true, ctrl: true, raw: ::Curses::KEY_F48),
      ::Curses::KEY_F60 => FatTerm::KeyEvent.new(key: :f12, meta: true, raw: ::Curses::KEY_F60),
      # 336 duplicates the :down key
      # KEY_SF: 336 => FatTerm::KeyEvent.new(key: :f12, shift: true, meta: true),
      ::Curses::KEY_IC => FatTerm::KeyEvent.new(key: :insert, raw: ::Curses::KEY_IC),
      ::Curses::KEY_SIC => FatTerm::KeyEvent.new(key: :insert, shift: true, raw: ::Curses::KEY_SIC),
      # 550 => FatTerm::KeyEvent.new(key: :insert, meta: true, raw: 550),
      # 551 => FatTerm::KeyEvent.new(key: :insert, shift: true, meta: true),
      # 552 => FatTerm::KeyEvent.new(key: :insert, ctrl: true),
      # 553 => FatTerm::KeyEvent.new(key: :insert, shift: true, ctrl: true),
      ::Curses::KEY_DC => FatTerm::KeyEvent.new(key: :delete, raw: ::Curses::KEY_DC),
      ::Curses::KEY_SDC => FatTerm::KeyEvent.new(key: :delete, shift: true, raw: ::Curses::KEY_SDC),
      # 531 => FatTerm::KeyEvent.new(key: :delete, meta: true),
      # 532 => FatTerm::KeyEvent.new(key: :delete, shift: true, meta: true),
      # 533 => FatTerm::KeyEvent.new(key: :delete, ctrl: true),
      # 534 => FatTerm::KeyEvent.new(key: :delete, shift: true, ctrl: true),
      ::Curses::KEY_HOME => FatTerm::KeyEvent.new(key: :home, raw: ::Curses::KEY_HOME),
      ::Curses::KEY_SHOME => FatTerm::KeyEvent.new(key: :home, shift: true, raw: ::Curses::KEY_SHOME),
      # 545 => FatTerm::KeyEvent.new(key: :home, meta: true),
      # 546 => FatTerm::KeyEvent.new(key: :home, shift: true, meta: true),
      # 547 => FatTerm::KeyEvent.new(key: :home, ctrl: true),
      # 548 => FatTerm::KeyEvent.new(key: :home, shift: true, ctrl: true),
      ::Curses::KEY_END => FatTerm::KeyEvent.new(key: :end, raw: ::Curses::KEY_END),
      ::Curses::KEY_SEND => FatTerm::KeyEvent.new(key: :end, shift: true, raw: ::Curses::KEY_SEND),
      # 540 => FatTerm::KeyEvent.new(key: :end, meta: true),
      # 541 => FatTerm::KeyEvent.new(key: :end, shift: true, meta: true),
      # 542 => FatTerm::KeyEvent.new(key: :end, ctrl: true),
      # 543 => FatTerm::KeyEvent.new(key: :end, shift: true, ctrl: true),
      ::Curses::KEY_PPAGE => FatTerm::KeyEvent.new(key: :page_up, raw: ::Curses::KEY_PPAGE),
      ::Curses::KEY_SPREVIOUS => FatTerm::KeyEvent.new(key: :page_up, shift: true, raw: ::Curses::KEY_SPREVIOUS),
      # 565 => FatTerm::KeyEvent.new(key: :page_up, meta: true),
      # 566 => FatTerm::KeyEvent.new(key: :page_up, shift: true, meta: true),
      # 567 => FatTerm::KeyEvent.new(key: :page_up, ctrl: true),
      # 568 => FatTerm::KeyEvent.new(key: :page_up, shift: true, ctrl: true),
      ::Curses::KEY_NPAGE => FatTerm::KeyEvent.new(key: :page_down, raw: ::Curses::KEY_NPAGE),
      ::Curses::KEY_SNEXT => FatTerm::KeyEvent.new(key: :page_down, shift: true, raw: ::Curses::KEY_SNEXT),
      # 560 => FatTerm::KeyEvent.new(key: :page_down, meta: true),
      # 561 => FatTerm::KeyEvent.new(key: :page_down, shift: true, meta: true),
      # 562 => FatTerm::KeyEvent.new(key: :page_down, ctrl: true),
      # 563 => FatTerm::KeyEvent.new(key: :page_down, shift: true, ctrl: true),
      ::Curses::KEY_DOWN => FatTerm::KeyEvent.new(key: :down, raw: ::Curses::KEY_DOWN),
      ::Curses::KEY_SF => FatTerm::KeyEvent.new(key: :down, shift: true, raw: ::Curses::KEY_SF),
      # 535 => FatTerm::KeyEvent.new(key: :down, meta: true),
      # 536 => FatTerm::KeyEvent.new(key: :down, shift: true, meta: true),
      # 537 => FatTerm::KeyEvent.new(key: :down, ctrl: true),
      # 538 => FatTerm::KeyEvent.new(key: :down, shift: true, ctrl: true),
      ::Curses::KEY_UP => FatTerm::KeyEvent.new(key: :up, raw: ::Curses::KEY_UP),
      ::Curses::KEY_SR => FatTerm::KeyEvent.new(key: :up, shift: true, raw: ::Curses::KEY_SR),
      # 576 => FatTerm::KeyEvent.new(key: :up, meta: true),
      # 577 => FatTerm::KeyEvent.new(key: :up, shift: true, meta: true),
      # 578 => FatTerm::KeyEvent.new(key: :up, ctrl: true),
      # 579 => FatTerm::KeyEvent.new(key: :up, shift: true, ctrl: true),
      ::Curses::KEY_LEFT => FatTerm::KeyEvent.new(key: :left, raw: ::Curses::KEY_LEFT),
      ::Curses::KEY_SLEFT => FatTerm::KeyEvent.new(key: :left, shift: true, raw: ::Curses::KEY_SLEFT),
      # 555 => FatTerm::KeyEvent.new(key: :left, meta: true),
      # 556 => FatTerm::KeyEvent.new(key: :left, shift: true, meta: true),
      # 557 => FatTerm::KeyEvent.new(key: :left, ctrl: true),
      # 558 => FatTerm::KeyEvent.new(key: :left, shift: true, ctrl: true),
      ::Curses::KEY_RIGHT => FatTerm::KeyEvent.new(key: :right, raw: ::Curses::KEY_RIGHT),
      ::Curses::KEY_SRIGHT => FatTerm::KeyEvent.new(key: :right, shift: true, raw: ::Curses::KEY_SRIGHT),
      # 570 => FatTerm::KeyEvent.new(key: :right, meta: true),
      # 571 => FatTerm::KeyEvent.new(key: :right, shift: true, meta: true),
      # 572 => FatTerm::KeyEvent.new(key: :right, ctrl: true),
      # 573 => FatTerm::KeyEvent.new(key: :right, shift: true, ctrl: true),
    }
  end
end
