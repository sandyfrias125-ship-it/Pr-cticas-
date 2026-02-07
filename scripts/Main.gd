extends Control

@onready var lbl_title: Label = %Title
@onready var lbl_status: Label = %Status
@onready var main_stack: VBoxContainer = %MainStack
@onready var app_tabs: TabContainer = %AppTabs

@onready var booking = BookingSystem.new()
@onready var combat = CombatSystem.new()

func _ready():
    add_child(booking)
    add_child(combat)
    combat.match_finished.connect(_on_match_finished)

    lbl_title.text = Localization.tr_key("APP_TITLE")
    _refresh_buttons()
    _refresh_all()

func _refresh_buttons():
    %BtnNew.text = Localization.tr_key("BTN_NEW")
    %BtnContinue.text = Localization.tr_key("BTN_CONTINUE")
    %BtnSettings.text = Localization.tr_key("BTN_SETTINGS")
    %BtnQuit.text = Localization.tr_key("BTN_QUIT")

func _refresh_all():
    %WeekLabel.text = "%s: %s" % [Localization.tr_key("LBL_WEEK"), str(GameState.company().get("week",1))]
    %CashLabel.text = "%s: $%s" % [Localization.tr_key("LBL_CASH"), str(GameState.company().get("cash",0))]
    _refresh_roster()
    _refresh_titles()
    _refresh_rivalries()
    _refresh_storylines()
    _refresh_calendar()
    _refresh_card()
    _refresh_finances()
    _refresh_combat_panel()

func _on_btn_new_pressed():
    GameState.new_game()
    lbl_status.text = ""
    app_tabs.visible = true
    _refresh_all()

func _on_btn_continue_pressed():
    if GameState.load_game():
        lbl_status.text = Localization.tr_key("MSG_LOADED")
        app_tabs.visible = true
        _refresh_all()
    else:
        lbl_status.text = Localization.tr_key("MSG_NO_SAVE")

func _on_btn_settings_pressed():
    app_tabs.current_tab = 8 # Settings

func _on_btn_quit_pressed():
    get_tree().quit()

func _on_save_pressed():
    GameState.save_game()
    lbl_status.text = Localization.tr_key("MSG_SAVED")

func _on_lang_changed(idx: int):
    var code = "es" if idx == 0 else "en"
    Localization.load_language(code)
    # Re-label UI
    lbl_title.text = Localization.tr_key("APP_TITLE")
    _refresh_buttons()
    %HintCombat.text = Localization.tr_key("COMBAT_HINT")
    _refresh_all()

# ---------------- Roster
func _refresh_roster():
    var list: ItemList = %RosterList
    list.clear()
    for p in GameState.roster():
        var c = p.get("contract", {})
        var line = "%s | Pop %d | Skill %d | Moral %d | %s %dw | $%d/w | Lesión %d" % [
            p.get("name","?"),
            int(p.get("popularity",0)),
            int(p.get("skill",0)),
            int(p.get("morale",0)),
            ("Excl." if bool(c.get("exclusive",false)) else "No excl."),
            int(c.get("weeks_left",0)),
            int(c.get("salary",0)),
            int(p.get("injury",0))
        ]
        list.add_item(line)

func _on_hire_pressed():
    var name = %HireName.text.strip_edges()
    if name == "":
        name = "Nuevo Luchador"
    booking.hire_wrestler(name)
    %HireName.text = ""
    _refresh_roster()

func _on_fire_pressed():
    var list: ItemList = %RosterList
    var idxs = list.get_selected_items()
    if idxs.size() == 0: return
    var pid = GameState.roster()[idxs[0]].get("id","")
    booking.fire_wrestler(pid)
    _refresh_roster()

# ---------------- Titles
func _refresh_titles():
    var list: ItemList = %TitlesList
    list.clear()
    for t in GameState.titles():
        var holder = _name_for_id(t.get("holder",""))
        list.add_item("%s (Prest %d) — %s" % [t.get("name","?"), int(t.get("prestige",0)), holder if holder != "" else "Vacante"])

func _on_create_title_pressed():
    var name = %TitleName.text.strip_edges()
    if name == "": name = "Nuevo Título"
    var prest = int(%TitlePrestige.value)
    booking.create_title(name, prest)
    %TitleName.text = ""
    _refresh_titles()

# ---------------- Rivalries
func _refresh_rivalries():
    var list: ItemList = %RivalriesList
    list.clear()
    for r in GameState.rivalries():
        list.add_item("%s vs %s — Heat %d — %s" % [_name_for_id(r.get("a","")), _name_for_id(r.get("b","")), int(r.get("heat",0)), r.get("status","")])

func _on_create_rivalry_pressed():
    var a_idx = %RivA.get_selected_id()
    var b_idx = %RivB.get_selected_id()
    if a_idx == -1 or b_idx == -1 or a_idx == b_idx: return
    var a = GameState.roster()[a_idx].get("id","")
    var b = GameState.roster()[b_idx].get("id","")
    booking.create_rivalry(a,b)
    _refresh_rivalries()

# ---------------- Storylines
func _refresh_storylines():
    var list: ItemList = %StoryList
    list.clear()
    for s in GameState.storylines():
        list.add_item("%s — %s (%d/%d)" % [s.get("name","?"), s.get("status",""), int(s.get("progress",0)), int(s.get("beats",[]).size())])

# ---------------- Calendar/Card
func _refresh_calendar():
    var week = int(GameState.company().get("week",1))
    booking.ensure_week_entry(week)
    var entry = booking.get_week_entry(week)
    %ShowName.text = entry.get("show",{}).get("name","")
    _refresh_venue_options()
    %VenueOptions.select(_venue_index(entry.get("show",{}).get("venue","small_hall")))
    %WeekLabel.text = "%s: %s" % [Localization.tr_key("LBL_WEEK"), str(week)]
    %CashLabel.text = "%s: $%s" % [Localization.tr_key("LBL_CASH"), str(GameState.company().get("cash",0))]

func _refresh_venue_options():
    var opt: OptionButton = %VenueOptions
    opt.clear()
    for v in GameState.venues():
        opt.add_item("%s (%d) — $%d" % [v.get("name",""), int(v.get("capacity",0)), int(v.get("cost",0))])

func _venue_index(venue_id: String) -> int:
    var i := 0
    for v in GameState.venues():
        if v.get("id") == venue_id:
            return i
        i += 1
    return 0

func _on_venue_changed(idx: int):
    var v = GameState.venues()[idx]
    booking.set_show_venue(int(GameState.company().get("week",1)), v.get("id","small_hall"))
    _refresh_calendar()

func _refresh_card():
    var list: ItemList = %CardList
    list.clear()
    var week = int(GameState.company().get("week",1))
    var entry = booking.get_week_entry(week)
    var matches: Array = entry.get("show",{}).get("matches",[])
    for m in matches:
        var mt = m.get("type","singles")
        var parts: Array = m.get("participants",[])
        var names = []
        for pid in parts:
            names.append(_name_for_id(pid))
        var winner = _name_for_id(m.get("winner",""))
        var decided = bool(m.get("decided",false))
        var title_str = ""
        if bool(m.get("title_match",false)):
            title_str = " — (%s)" % _title_name(m.get("title_id",""))
        list.add_item("[%s]%s %s%s %s" % [mt, title_str, " vs ".join(names), "", ("→ " + winner if decided else "")])

func _on_add_match_pressed():
    var week = int(GameState.company().get("week",1))
    var a_idx = %MatchA.get_selected_id()
    var b_idx = %MatchB.get_selected_id()
    if a_idx == -1 or b_idx == -1 or a_idx == b_idx: return
    var a = GameState.roster()[a_idx].get("id","")
    var b = GameState.roster()[b_idx].get("id","")
    var title_match = %TitleMatch.button_pressed
    var title_id = ""
    if title_match:
        var tidx = %TitlePick.get_selected_id()
        if tidx != -1:
            title_id = GameState.titles()[tidx].get("id","")
    booking.add_match(week, {
        "type":"singles",
        "participants":[a,b],
        "stipulation": %Stipulation.text.strip_edges(),
        "title_match": title_match,
        "title_id": title_id,
        "winner":"",
        "decided": false
    })
    _refresh_card()

func _on_clear_card_pressed():
    booking.clear_card(int(GameState.company().get("week",1)))
    _refresh_card()

func _on_decide_winner_pressed():
    var week = int(GameState.company().get("week",1))
    var idxs = %CardList.get_selected_items()
    if idxs.size()==0: return
    var m_index = idxs[0]
    var entry = booking.get_week_entry(week)
    var m = entry.get("show",{}).get("matches",[])[m_index]
    var parts: Array = m.get("participants",[])
    if parts.size()==0: return
    # choose first by default
    booking.decide_winner(week, m_index, parts[0])
    _refresh_card()

func _on_simulate_show_pressed():
    var week = int(GameState.company().get("week",1))
    var result = booking.simulate_show(week)
    %LastResult.text = "Audiencia: %d | Ingresos: $%d | Gastos: $%d | Balance: $%d | Dinero: $%d" % [
        int(result.get("audience",0)),
        int(result.get("revenue",0)),
        int(result.get("expenses",0)),
        int(result.get("balance",0)),
        int(result.get("cash",0))
    ]
    _refresh_all()

# ---------------- Finances
func _refresh_finances():
    var c = GameState.company()
    %FinCash.text = "$%d" % int(c.get("cash",0))
    %FinRep.text = "%d" % int(c.get("reputation",50))

# ---------------- Combat
func _refresh_combat_panel():
    %HintCombat.text = Localization.tr_key("COMBAT_HINT")
    _refresh_picker_options()

func _refresh_picker_options():
    var a: OptionButton = %MatchA
    var b: OptionButton = %MatchB
    var ra: OptionButton = %RivA
    var rb: OptionButton = %RivB
    var tp: OptionButton = %TitlePick
    a.clear(); b.clear(); ra.clear(); rb.clear(); tp.clear()
    for p in GameState.roster():
        a.add_item(p.get("name",""))
        b.add_item(p.get("name",""))
        ra.add_item(p.get("name",""))
        rb.add_item(p.get("name",""))
    for t in GameState.titles():
        tp.add_item(t.get("name",""))

func _on_play_match_pressed():
    var a_idx = %MatchA.get_selected_id()
    var b_idx = %MatchB.get_selected_id()
    if a_idx == -1 or b_idx == -1 or a_idx == b_idx: return
    var a = GameState.roster()[a_idx].get("id","")
    var b = GameState.roster()[b_idx].get("id","")
    combat.start_match(a,b)
    %CombatStatus.text = "Combate iniciado: %s vs %s" % [_name_for_id(a), _name_for_id(b)]
    %CombatBars.visible = true
    _update_bars()

func _process(_dt):
    if not %CombatBars.visible: return
    if Input.is_action_just_pressed("punch"):
        combat.apply_action(1,"punch")
        combat.apply_action(2, _ai_action())
        _update_bars()
    elif Input.is_action_just_pressed("kick"):
        combat.apply_action(1,"kick")
        combat.apply_action(2, _ai_action())
        _update_bars()
    elif Input.is_action_just_pressed("block"):
        combat.apply_action(1,"block")
        combat.apply_action(2, _ai_action())
        _update_bars()
    elif Input.is_action_just_pressed("dodge"):
        combat.apply_action(1,"dodge")
        combat.apply_action(2, _ai_action())
        _update_bars()

func _ai_action() -> String:
    # very simple AI: if low stamina -> block/dodge else attack
    if int(combat.p2["st"]) < 20:
        return "block" if randf() < 0.6 else "dodge"
    return "punch" if randf() < 0.6 else "kick"

func _update_bars():
    %P1HP.value = combat.p1["hp"]
    %P1ST.value = combat.p1["st"]
    %P2HP.value = combat.p2["hp"]
    %P2ST.value = combat.p2["st"]

func _on_match_finished(winner_id: String):
    %CombatStatus.text = "Ganador: %s" % _name_for_id(winner_id)

# ---------------- Helpers
func _name_for_id(pid: String) -> String:
    if pid == "": return ""
    for p in GameState.roster():
        if p.get("id") == pid:
            return p.get("name","")
    return ""

func _title_name(tid: String) -> String:
    for t in GameState.titles():
        if t.get("id") == tid:
            return t.get("name","")
    return "Título"
