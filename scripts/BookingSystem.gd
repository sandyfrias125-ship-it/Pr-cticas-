extends Node
class_name BookingSystem

# High-level, 'complete' booking loop:
# - build match card
# - decide winners or simulate
# - update popularity/morale/reputation, titles, rivalries, storylines
# - compute revenue/expenses, injuries, contracts countdown

func current_week() -> int:
    return int(GameState.company().get("week", 1))

func ensure_week_entry(week: int) -> void:
    var cal = GameState.calendar()
    for e in cal:
        if int(e.get("week", 0)) == week:
            return
    cal.append({"week": week, "show": {"name": "Show Semanal #%d" % week, "venue":"small_hall", "matches": []}})

func get_week_entry(week: int) -> Dictionary:
    ensure_week_entry(week)
    for e in GameState.calendar():
        if int(e.get("week", 0)) == week:
            return e
    return {}

func set_show_venue(week: int, venue_id: String) -> void:
    var entry = get_week_entry(week)
    if entry.is_empty(): return
    entry["show"]["venue"] = venue_id

func add_match(week: int, match_dict: Dictionary) -> void:
    var entry = get_week_entry(week)
    if entry.is_empty(): return
    entry["show"]["matches"].append(match_dict)

func clear_card(week: int) -> void:
    var entry = get_week_entry(week)
    if entry.is_empty(): return
    entry["show"]["matches"] = []

func decide_winner(week: int, match_index: int, winner_id: String) -> void:
    var entry = get_week_entry(week)
    if entry.is_empty(): return
    var matches = entry["show"]["matches"]
    if match_index < 0 or match_index >= matches.size(): return
    matches[match_index]["winner"] = winner_id
    matches[match_index]["decided"] = true

func simulate_show(week: int) -> Dictionary:
    var entry = get_week_entry(week)
    if entry.is_empty(): return {}
    var show = entry["show"]
    var roster = GameState.roster()
    var company = GameState.company()

    # Venue & capacity
    var venue = _find_by_id(GameState.venues(), show.get("venue","small_hall"))
    var capacity = int(venue.get("capacity", 800))
    var base_cost = int(venue.get("cost", 1500))

    # Determine winners for undecided matches
    for m in show.get("matches", []):
        if not bool(m.get("decided", false)):
            var participants: Array = m.get("participants", [])
            if participants.size() > 0:
                m["winner"] = participants[randi() % participants.size()]
                m["decided"] = true

    # Heat from rivalries + title prestige boosts audience
    var heat_bonus := _heat_bonus(show)
    var title_bonus := _title_bonus(show)

    var rep = float(company.get("reputation", 50))
    var expected = clamp(int((rep/100.0) * capacity + heat_bonus + title_bonus), 200, capacity)
    var ticket_price = 12 + int(rep/10)
    var revenue = expected * ticket_price

    var expenses = base_cost + int(company.get("expenses", {}).get("staff", 5000)) + int(company.get("expenses", {}).get("medical", 1000))
    # Payout salaries (weekly portion)
    var payroll := 0
    for p in roster:
        payroll += int(p.get("contract", {}).get("salary", 0))
    expenses += payroll

    var balance = revenue - expenses
    company["cash"] = int(company.get("cash",0)) + balance

    # Update wrestler stats based on match outcomes
    for m in show.get("matches", []):
        _apply_match_outcome(m)

    # Advance rivalries and storylines
    _advance_rivalries(show)
    _advance_storylines()

    # Title changes
    _apply_title_changes(show)

    # Injuries
    _roll_injuries(show)

    # Contract weeks left
    _tick_contracts()

    # Week progresses
    company["week"] = int(company.get("week",1)) + 1

    var result = {
        "audience": expected,
        "revenue": revenue,
        "expenses": expenses,
        "balance": balance,
        "cash": company["cash"],
        "week_next": company["week"]
    }
    return result

func _apply_match_outcome(m: Dictionary) -> void:
    var winner = str(m.get("winner",""))
    var participants: Array = m.get("participants", [])
    if participants.size() == 0: return

    for p in GameState.roster():
        if not participants.has(p.get("id")):
            continue
        var pop = int(p.get("popularity", 50))
        var morale = int(p.get("morale", 50))
        if p.get("id") == winner:
            p["popularity"] = clamp(pop + 2, 0, 100)
            p["morale"] = clamp(morale + 2, 0, 100)
        else:
            p["popularity"] = clamp(pop - 1, 0, 100)
            p["morale"] = clamp(morale - 1, 0, 100)

func _advance_rivalries(show: Dictionary) -> void:
    var rivals = GameState.rivalries()
    for r in rivals:
        if r.get("status") != "Activa": continue
        # If they were booked together, heat increases
        var a = r.get("a"); var b = r.get("b")
        var booked_together := false
        for m in show.get("matches", []):
            var parts: Array = m.get("participants", [])
            if parts.has(a) and parts.has(b):
                booked_together = true
                break
        if booked_together:
            r["heat"] = clamp(int(r.get("heat",50)) + 4, 0, 100)
        else:
            r["heat"] = clamp(int(r.get("heat",50)) - 1, 0, 100)
        r["weeks"] = int(r.get("weeks",0)) + 1
        # auto-finish if heat low after long time
        if int(r["weeks"]) > 12 and int(r["heat"]) < 25:
            r["status"] = "Terminada"

func _advance_storylines() -> void:
    for s in GameState.storylines():
        if s.get("status") != "Activa": continue
        var beats: Array = s.get("beats", [])
        var progress = int(s.get("progress", 0))
        if progress < beats.size():
            s["progress"] = progress + 1
        else:
            s["status"] = "Terminada"

func _apply_title_changes(show: Dictionary) -> void:
    # If match is flagged as title_match, winner becomes holder.
    for m in show.get("matches", []):
        if not bool(m.get("title_match", false)):
            continue
        var title_id = str(m.get("title_id",""))
        var winner = str(m.get("winner",""))
        if title_id == "" or winner == "":
            continue
        for t in GameState.titles():
            if t.get("id") == title_id:
                t["holder"] = winner

func _roll_injuries(show: Dictionary) -> void:
    # Small chance per match participant; higher for hardcore.
    for m in show.get("matches", []):
        var parts: Array = m.get("participants", [])
        for pid in parts:
            var p = _find_by_id(GameState.roster(), pid)
            if p.is_empty(): continue
            var chance = 0.05
            if str(m.get("stipulation","")) in ["Hardcore","Cage"]:
                chance = 0.12
            if randf() < chance:
                p["injury"] = clamp(int(p.get("injury",0)) + 20 + randi()%30, 0, 100)

func _tick_contracts() -> void:
    for p in GameState.roster():
        var c = p.get("contract", {})
        c["weeks_left"] = max(0, int(c.get("weeks_left",0)) - 1)
        p["contract"] = c

func renew_contract(pid: String, weeks: int, salary: int, exclusive: bool) -> void:
    var p = _find_by_id(GameState.roster(), pid)
    if p.is_empty(): return
    p["contract"] = {"weeks_left": weeks, "salary": salary, "exclusive": exclusive}
    p["morale"] = clamp(int(p.get("morale",50)) + 5, 0, 100)

func hire_wrestler(name: String) -> void:
    var roster = GameState.roster()
    var new_id = "h%s" % str(Time.get_ticks_msec())
    roster.append({
        "id": new_id,
        "name": name,
        "style": "Rookie",
        "popularity": 30,
        "skill": 35,
        "morale": 50,
        "alignment": "Face",
        "injury": 0,
        "contract": {"weeks_left": 8, "salary": 500, "exclusive": false}
    })

func fire_wrestler(pid: String) -> void:
    var roster = GameState.roster()
    for i in range(roster.size()):
        if roster[i].get("id") == pid:
            roster.remove_at(i)
            return

func create_title(name: String, prestige: int) -> void:
    GameState.titles().append({"id":"t%s" % str(Time.get_ticks_msec()), "name": name, "prestige": prestige, "holder": ""})

func assign_title(title_id: String, holder_id: String) -> void:
    for t in GameState.titles():
        if t.get("id") == title_id:
            t["holder"] = holder_id

func create_rivalry(a: String, b: String) -> void:
    GameState.rivalries().append({"id":"r%s" % str(Time.get_ticks_msec()), "a":a, "b":b, "heat":40, "weeks":0, "status":"Activa"})

func _heat_bonus(show: Dictionary) -> int:
    var bonus := 0
    for r in GameState.rivalries():
        if r.get("status") != "Activa": continue
        var a = r.get("a"); var b = r.get("b")
        for m in show.get("matches", []):
            var parts: Array = m.get("participants", [])
            if parts.has(a) and parts.has(b):
                bonus += int(r.get("heat",0)) / 5
    return bonus

func _title_bonus(show: Dictionary) -> int:
    var bonus := 0
    for m in show.get("matches", []):
        if bool(m.get("title_match", false)):
            var t = _find_by_id(GameState.titles(), m.get("title_id",""))
            bonus += int(t.get("prestige",0)) / 10
    return bonus

func _find_by_id(arr: Array, idv) -> Dictionary:
    for x in arr:
        if x.get("id") == idv:
            return x
    return {}
