# frozen_string_literal: true
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

module FatTerm
  class KeyEvent
  attr_reader :key, :text, :ctrl, :meta, :shift

  def initialize(key:, text: nil, ctrl: false, meta: false, shift: false)
    @key  = key          # Symbol or named key
    @text = text         # String to insert (or nil)
    @ctrl = ctrl
    @meta = meta
    @shift = shift
  end

  def ctrl?
    @ctrl
  end

  def meta?
    @meta
  end

  def shift?
    @shift
  end

  KEY_SYM_MAP = {
   409 => :KEY_MOUSE,
   257 => :KEY_BREAK,
   258 => :KEY_DOWN,
   259 => :KEY_UP,
   260 => :KEY_LEFT,
   261 => :KEY_RIGHT,
   262 => :KEY_HOME,
   263 => :KEY_BACKSPACE,
   264 => :KEY_F0,
   265 => :KEY_F1,
   266 => :KEY_F2,
   267 => :KEY_F3,
   268 => :KEY_F4,
   269 => :KEY_F5,
   270 => :KEY_F6,
   271 => :KEY_F7,
   272 => :KEY_F8,
   273 => :KEY_F9,
   274 => :KEY_F10,
   275 => :KEY_F11,
   276 => :KEY_F12,
   277 => :KEY_F13,
   278 => :KEY_F14,
   279 => :KEY_F15,
   280 => :KEY_F16,
   281 => :KEY_F17,
   282 => :KEY_F18,
   283 => :KEY_F19,
   284 => :KEY_F20,
   285 => :KEY_F21,
   286 => :KEY_F22,
   287 => :KEY_F23,
   288 => :KEY_F24,
   289 => :KEY_F25,
   290 => :KEY_F26,
   291 => :KEY_F27,
   292 => :KEY_F28,
   293 => :KEY_F29,
   294 => :KEY_F30,
   295 => :KEY_F31,
   296 => :KEY_F32,
   297 => :KEY_F33,
   298 => :KEY_F34,
   299 => :KEY_F35,
   300 => :KEY_F36,
   301 => :KEY_F37,
   302 => :KEY_F38,
   303 => :KEY_F39,
   304 => :KEY_F40,
   305 => :KEY_F41,
   306 => :KEY_F42,
   307 => :KEY_F43,
   308 => :KEY_F44,
   309 => :KEY_F45,
   310 => :KEY_F46,
   311 => :KEY_F47,
   312 => :KEY_F48,
   313 => :KEY_F49,
   314 => :KEY_F50,
   315 => :KEY_F51,
   316 => :KEY_F52,
   317 => :KEY_F53,
   318 => :KEY_F54,
   319 => :KEY_F55,
   320 => :KEY_F56,
   321 => :KEY_F57,
   322 => :KEY_F58,
   323 => :KEY_F59,
   324 => :KEY_F60,
   325 => :KEY_F61,
   326 => :KEY_F62,
   327 => :KEY_F63,
   328 => :KEY_DL,
   329 => :KEY_IL,
   330 => :KEY_DC,
   331 => :KEY_IC,
   332 => :KEY_EIC,
   333 => :KEY_CLEAR,
   334 => :KEY_EOS,
   335 => :KEY_EOL,
   336 => :KEY_SF,
   337 => :KEY_SR,
   338 => :KEY_NPAGE,
   339 => :KEY_PPAGE,
   340 => :KEY_STAB,
   341 => :KEY_CTAB,
   342 => :KEY_CATAB,
   343 => :KEY_ENTER,
   344 => :KEY_SRESET,
   345 => :KEY_RESET,
   346 => :KEY_PRINT,
   347 => :KEY_LL,
   348 => :KEY_A1,
   349 => :KEY_A3,
   350 => :KEY_B2,
   351 => :KEY_C1,
   352 => :KEY_C3,
   353 => :KEY_BTAB,
   354 => :KEY_BEG,
   355 => :KEY_CANCEL,
   356 => :KEY_CLOSE,
   357 => :KEY_COMMAND,
   358 => :KEY_COPY,
   359 => :KEY_CREATE,
   360 => :KEY_END,
   361 => :KEY_EXIT,
   362 => :KEY_FIND,
   363 => :KEY_HELP,
   364 => :KEY_MARK,
   365 => :KEY_MESSAGE,
   366 => :KEY_MOVE,
   367 => :KEY_NEXT,
   368 => :KEY_OPEN,
   369 => :KEY_OPTIONS,
   370 => :KEY_PREVIOUS,
   371 => :KEY_REDO,
   372 => :KEY_REFERENCE,
   373 => :KEY_REFRESH,
   374 => :KEY_REPLACE,
   375 => :KEY_RESTART,
   376 => :KEY_RESUME,
   377 => :KEY_SAVE,
   378 => :KEY_SBEG,
   379 => :KEY_SCANCEL,
   380 => :KEY_SCOMMAND,
   381 => :KEY_SCOPY,
   382 => :KEY_SCREATE,
   383 => :KEY_SDC,
   384 => :KEY_SDL,
   385 => :KEY_SELECT,
   386 => :KEY_SEND,
   387 => :KEY_SEOL,
   388 => :KEY_SEXIT,
   389 => :KEY_SFIND,
   390 => :KEY_SHELP,
   391 => :KEY_SHOME,
   392 => :KEY_SIC,
   393 => :KEY_SLEFT,
   394 => :KEY_SMESSAGE,
   395 => :KEY_SMOVE,
   396 => :KEY_SNEXT,
   397 => :KEY_SOPTIONS,
   398 => :KEY_SPREVIOUS,
   399 => :KEY_SPRINT,
   400 => :KEY_SREDO,
   401 => :KEY_SREPLACE,
   402 => :KEY_SRIGHT,
   403 => :KEY_SRSUME,
   404 => :KEY_SSAVE,
   405 => :KEY_SSUSPEND,
   406 => :KEY_SUNDO,
   407 => :KEY_SUSPEND,
   408 => :KEY_UNDO,
   410 => :KEY_RESIZE,
   511 => :KEY_MAX,
   1 => :KEY_CTRL_A,
   2 => :KEY_CTRL_B,
   3 => :KEY_CTRL_C,
   4 => :KEY_CTRL_D,
   5 => :KEY_CTRL_E,
   6 => :KEY_CTRL_F,
   7 => :KEY_CTRL_G,
   8 => :KEY_CTRL_H,
   9 => :KEY_CTRL_I,
   10 => :KEY_CTRL_J,
   11 => :KEY_CTRL_K,
   12 => :KEY_CTRL_L,
   13 => :KEY_CTRL_M,
   14 => :KEY_CTRL_N,
   15 => :KEY_CTRL_O,
   16 => :KEY_CTRL_P,
   17 => :KEY_CTRL_Q,
   18 => :KEY_CTRL_R,
   19 => :KEY_CTRL_S,
   20 => :KEY_CTRL_T,
   21 => :KEY_CTRL_U,
   22 => :KEY_CTRL_V,
   23 => :KEY_CTRL_W,
   24 => :KEY_CTRL_X,
   25 => :KEY_CTRL_Y,
   26 => :KEY_CTRL_Z
  }
  end
end
