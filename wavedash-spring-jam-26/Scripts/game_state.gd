extends Node

## Autoload "GameState". Tracks run-wide resources; the HUD listens to the signal.

signal wood_changed(wood: int)
signal wood_increased
## Current wolf detection level (0-100). The player HUD danger meter listens.
signal threat_changed(level: float)
## Total trees the player has chopped this run.
signal trees_cut_changed(count: int)

## Wavedash achievement IDs. These must exist in the Wavedash Developer Portal
## (your game -> Achievements) with API names matching exactly, or the unlock is
## a silent no-op.
const ACH_HIDE := "hide_from_wolf"
const ACH_DAM := "dam_complete"
## Tree-chopping tiers: [count threshold, achievement id].
const TREE_TIERS := [[5, "chop_5_trees"], [10, "chop_10_trees"], [15, "chop_15_trees"]]

var wood: int = 0
var threat_level: float = 0.0
var trees_cut: int = 0

var _unlocked: Dictionary = {}

func _ready() -> void:
	# Opt into Wavedash platform features. Safe no-op off the web (init() is
	# guarded by OS.get_name() == "Web" inside the SDK). WavedashSDK is loaded
	# before GameState via autoload order so it is in the tree by now.
	WavedashSDK.init({})

func add_wood(amount: int = 1) -> void:
	if amount > 0:
		wood_increased.emit()
	wood += amount
	wood_changed.emit(wood)

## Pushes the wolf's current detection level to the HUD. Only emits on change so
## the per-frame caller doesn't spam the signal.
func set_threat(level: float) -> void:
	if is_equal_approx(level, threat_level):
		return
	threat_level = level
	threat_changed.emit(level)

## Counts one chopped tree and unlocks any tiered achievement just reached.
func record_tree_cut() -> void:
	trees_cut += 1
	trees_cut_changed.emit(trees_cut)
	WavedashSDK.set_stat_int("trees_cut", trees_cut)
	for tier in TREE_TIERS:
		if trees_cut == tier[0]:
			unlock_achievement(tier[1])

## Unlocks a Wavedash achievement once. The guard keeps per-frame callers (e.g.
## the wolf "you hid" check) from re-sending it every frame. set_achievement is a
## safe no-op off the web.
func unlock_achievement(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	WavedashSDK.set_achievement(id, true)
