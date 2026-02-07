extends Node
class_name CombatSystem

# Lightweight 2D combat prototype to let Booking mode 'play' a match.
# Not art-heavy; uses hit windows + stamina.

signal match_finished(winner_id: String)

var p1 := {"id":"p1","hp":100,"st":100}
var p2 := {"id":"p2","hp":100,"st":100}
var active := false
var winner := ""

func start_match(a_id: String, b_id: String) -> void:
    p1 = {"id":a_id, "hp":100, "st":100}
    p2 = {"id":b_id, "hp":100, "st":100}
    active = true
    winner = ""

func apply_action(attacker: int, action: String) -> void:
    if not active: return
    var A = p1 if attacker == 1 else p2
    var B = p2 if attacker == 1 else p1

    var dmg := 0
    var cost := 0
    match action:
        "punch":
            dmg = 8
            cost = 6
        "kick":
            dmg = 12
            cost = 10
        "block":
            dmg = 0
            cost = 2
        "dodge":
            dmg = 0
            cost = 8
        _:
            return

    if int(A["st"]) < cost:
        return
    A["st"] = max(0, int(A["st"]) - cost)

    # Simple interactions
    if action in ["punch","kick"]:
        # if defender low stamina, take extra
        var mult = 1.0
        if int(B["st"]) < 25:
            mult = 1.25
        B["hp"] = max(0, int(B["hp"]) - int(dmg * mult))

    # regen a bit
    A["st"] = min(100, int(A["st"]) + 2)
    B["st"] = min(100, int(B["st"]) + 1)

    if int(B["hp"]) <= 0:
        active = false
        winner = str(A["id"])
        emit_signal("match_finished", winner)

    if attacker == 1:
        p1 = A; p2 = B
    else:
        p2 = A; p1 = B
