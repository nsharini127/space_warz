extends Node
## Centralized UI color palette and font size constants.
## Registered as autoload "UIColors" in project.godot.

# -- Primary palette --
const CYAN := Color(0.3, 0.8, 1.0)
const GOLD := Color(1.0, 0.85, 0.2)
const RED := Color(1.0, 0.2, 0.2)
const GREEN := Color(0.3, 1.0, 0.3)
const ORANGE := Color(1.0, 0.6, 0.1)

# -- Text colors --
const TEXT_WHITE := Color(1.0, 1.0, 1.0)
const TEXT_GRAY := Color(0.65, 0.65, 0.65)
const TEXT_DIM := Color(0.45, 0.45, 0.45)
const TEXT_CYAN := CYAN
const TEXT_GOLD := GOLD
const TEXT_RED := RED

# -- Panel / background --
const PANEL_BG := Color(0.02, 0.02, 0.06, 0.92)
const PANEL_BG_LIGHT := Color(0.06, 0.06, 0.12, 0.92)
const PANEL_BORDER := Color(0.15, 0.4, 0.7, 0.5)
const PANEL_BORDER_GOLD := Color(0.7, 0.6, 0.2, 0.6)
const OVERLAY_DIM := Color(0.0, 0.0, 0.0, 0.6)

# -- HUD specific --
const HUD_SCORE := TEXT_WHITE
const HUD_HISCORE := TEXT_GRAY
const HUD_WAVE := CYAN
const HUD_POWER := Color(0.4, 0.8, 1.0)
const HUD_BOMBS := Color(0.4, 0.6, 1.0)
const HUD_GRAZE := Color(0.75, 0.75, 1.0)
const HUD_TIMER_SAFE := Color(1.0, 1.0, 0.3)
const HUD_TIMER_WARN := ORANGE
const HUD_TIMER_DANGER := Color(1.0, 0.15, 0.15)
const HUD_HEART_EMPTY := Color(0.3, 0.3, 0.3, 0.5)

# -- Fever --
const FEVER_COMBO := Color(0.0, 1.0, 1.0)
const FEVER_ACTIVE := GOLD
const FEVER_GLOW := Color(1.0, 0.3, 0.0)
const FEVER_OVERLAY := Color(1.0, 0.1, 0.0, 0.06)

# -- Upgrade cards --
const CARD_BG_UTILITY := Color(0.08, 0.08, 0.12, 0.95)
const CARD_BORDER_UTILITY := Color(0.5, 0.5, 0.6)
const CARD_BORDER_EVOLUTION := Color(1.0, 0.75, 0.2)
const CARD_TAG_NEW := GREEN
const CARD_TAG_EVOLVE := Color(1.0, 0.75, 0.2)
const CARD_TAG_LEVEL := Color(0.7, 0.7, 0.8)
const CARD_DESC := Color(0.65, 0.65, 0.75)

# -- Grade colors --
const GRADE_S := GOLD
const GRADE_A := GREEN
const GRADE_B := CYAN
const GRADE_C := Color(0.7, 0.7, 0.7)
const GRADE_D := Color(0.4, 0.4, 0.4)

# -- Buttons --
const BTN_NORMAL_BG := Color(0.05, 0.15, 0.25, 0.9)
const BTN_NORMAL_BORDER := Color(0.3, 0.7, 1.0, 0.6)
const BTN_HOVER_BG := Color(0.08, 0.2, 0.35, 0.95)
const BTN_HOVER_BORDER := Color(0.4, 0.8, 1.0, 0.9)
const BTN_PRESSED_BG := Color(0.03, 0.1, 0.2, 1.0)
const BTN_DANGER_BG := Color(0.18, 0.06, 0.08, 0.9)
const BTN_DANGER_BORDER := Color(0.7, 0.3, 0.35, 0.5)

# -- Boss --
const BOSS_BAR_HIGH := Color(0.2, 0.9, 0.2)
const BOSS_BAR_MID := Color(0.9, 0.9, 0.2)
const BOSS_BAR_LOW := Color(0.9, 0.2, 0.2)
const BOSS_WARNING := Color(1.0, 0.15, 0.15)

# -- Trophy --
const TROPHY_NAME := GOLD
const TROPHY_BONUS := GREEN

# -- Outline --
const OUTLINE_BLACK := Color.BLACK
const OUTLINE_DARK := Color(0.0, 0.0, 0.0, 0.8)

# -- Font size tiers (standardized for 320x480) --
const FONT_TITLE := 16       # Screen titles (GAME OVER, PAUSED, CHOOSE UPGRADE)
const FONT_HERO := 14        # Hero numbers (score value, grade)
const FONT_HEADING := 12     # Section headings (score label, timer)
const FONT_BODY := 10        # Primary text (card names, button labels, wave)
const FONT_SMALL := 8        # Secondary text (descriptions, stats, hints)
const FONT_TINY := 7         # Fine print only (level dots labels, stat headers)

# -- Shared font --
static var _font: Font = null

static func get_font() -> Font:
	if _font == null:
		_font = load("res://theme/NormalFont.ttf")
	return _font
