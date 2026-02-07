extends Node
class_name BookingSystem

# Instancia local de GameState (evita el error non-static)
var GS: GameState = GameState.new()

# High-level "complete" booking loop:
# - build match card
# - decide winners or simulate
# - update popularity/morale/reputation
# - compute revenue/expenses, injuries, contracts countdown

func current_week() -> int:
	return int(GS.company().get("week", 1))

func ensure_week_entry(week: int) -> void:
	var cal = GS.calendar()
	for e in cal:
		if int(e.get("week", 0)) == week:
			return

	cal.append({
		"week": week,
		"show": {
			"name": "Show Semana %d" % week,
			"venue": "",
			"matches": []
		}
	})

func get_week_entry(week: int) -> Dictionary:
	ensure_week_entry(week)
	for e in GS.calendar():
		if int(e.get("week", 0)) == week:
			return e
	return {}

func set_show_venue(week: int, venue_id: String) -> void:
	var entry = get_week_entry(week)
	if entry.is_empty():
		return
	entry["show"]["venue"] = venue_id

func add_match(week: int, match_dict: Dictionary) -> void:
	var entry = get_week_entry(week)
	if entry.is_empty():
		return
	entry["show"]["matches"].append(match_dict)

func clear_card(week: int) -> void:
	var entry = get_week_entry(week)
	if entry.is_empty():
		return
	entry["show"]["matches"] = []

func decide_winner(week: int, match_index: int, winner_id: String) -> void:
	var entry = get_week_entry(week)
	if entry.is_empty():
		return

	var matches = entry["show"]["matches"]
	if match_index < 0 or match_index >= matches.size():
		return

	matches[match_index]["winner"] = winner_id
	matches[match_index]["decided"] = true

func simulate_show(week: int) -> Dictionary:
	var entry = get_week_entry(week)
	if entry.is_empty():
		return {}

	var show = entry["show"]
	var roster = GS.roster()
	var company = GS.company()

	# Venue & capacity
	var venue = _find_by_id(GS.venues(), show.get("venue", ""))
	var capacity = int(venue.get("capacity", 800))
	var base_cost = int(venue.get("cost", 1500))

	# Decide winners for undecided matches
	for m in show["matches"]:
		if not m.get("decided", false):
			var a = m.get("a")
			var b = m.get("b")
			m["winner"] = a if randf() < 0.5 else b
			m["decided"] = true

	# Simple attendance model
	var attendance = int(capacity * clamp(randf_range(0.6, 1.0), 0.0, 1.0))
	var ticket_price = int(company.get("ticket_price", 20))
	var revenue = attendance * ticket_price

	var expenses = base_cost
	var profit = revenue - expenses

	company["cash"] = int(company.get("cash", 0)) + profit
	company["week"] = week + 1

	return {
		"attendance": attendance,
		"revenue": revenue,
		"expenses": expenses,
		"profit": profit
	}

func _find_by_id(arr: Array, id_value) -> Dictionary:
	for e in arr:
		if e.get("id") == id_value:
			return e
	return {}
