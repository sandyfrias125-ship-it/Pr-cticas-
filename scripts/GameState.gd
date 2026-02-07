extends Node
class_name GameState

var save_path := "user://save.json"
var state: Dictionary = {}

signal state_changed

func new_game() -> void:
    state = _load_default()
    emit_signal("state_changed")

func has_save() -> bool:
    return FileAccess.file_exists(save_path)

func save_game() -> void:
    var f = FileAccess.open(save_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(state, "\t"))
    f.close()

func load_game() -> bool:
    if not has_save():
        return false
    var f = FileAccess.open(save_path, FileAccess.READ)
    state = JSON.parse_string(f.get_as_text())
    if typeof(state) != TYPE_DICTIONARY:
        state = {}
        return false
    emit_signal("state_changed")
    return true

func _load_default() -> Dictionary:
    var path = "res://data/default_save.json"
    var f = FileAccess.open(path, FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text())
    if typeof(d) != TYPE_DICTIONARY:
        d = {}
    return d

# Convenience getters
func company() -> Dictionary:
    return state.get("company", {})

func roster() -> Array:
    return state.get("roster", [])

func titles() -> Array:
    return state.get("titles", [])

func rivalries() -> Array:
    return state.get("rivalries", [])

func storylines() -> Array:
    return state.get("storylines", [])

func calendar() -> Array:
    return state.get("calendar", [])

func venues() -> Array:
    return state.get("venues", [])

func match_types() -> Array:
    return state.get("match_types", [])
