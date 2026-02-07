extends Node
class_name Localization

var lang := "es"
var dict := {}

func _ready():
    load_language(lang)

func load_language(code: String) -> void:
    lang = code
    var path = "res://localization/%s.json" % code
    if not FileAccess.file_exists(path):
        push_warning("Language file not found: %s" % path)
        dict = {}
        return
    var f = FileAccess.open(path, FileAccess.READ)
    dict = JSON.parse_string(f.get_as_text())
    if typeof(dict) != TYPE_DICTIONARY:
        dict = {}

func tr_key(key: String) -> String:
    if dict.has(key):
        return str(dict[key])
    return key
