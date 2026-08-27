extends Control

@export var app_id: int = 1001
@export var test_achievement_id: String = ""
@export var test_stat_id: String = ""

@onready var status_label: Label = $Status

func _ready() -> void:
	Ludolio.initialization_complete.connect(_on_initialization_complete)
	Ludolio.authentication_complete.connect(_on_authentication_complete)
	Ludolio.user_info_received.connect(_on_user_info_received)
	Ludolio.achievement_unlocked.connect(_on_achievement_unlocked)
	Ludolio.achievements_received.connect(_on_achievements_received)
	Ludolio.stats_requested.connect(_on_stats_requested)
	Ludolio.stats_stored.connect(_on_stats_stored)
	_set_status("Initializing Ludolio…")
	Ludolio.initialize_with_app_id(app_id)


func _on_initialization_complete(success: bool, error: String) -> void:
	if not success:
		_set_status("Initialize failed: %s" % error)
		return
	_set_status("Initialized. Authenticating…")
	Ludolio.authenticate()


func _on_authentication_complete(success: bool, error: String) -> void:
	if not success:
		_set_status("Authenticate failed: %s" % error)
		return
	_set_status("Authenticated as %s. Loading data…" % Ludolio.get_user_id())
	Ludolio.request_user_info()
	Ludolio.request_achievements()
	Ludolio.request_stats()


func _on_user_info_received(success: bool, user_info: Dictionary, error: String) -> void:
	if not success:
		_set_status("User info failed: %s" % error)
		return
	_set_status("Welcome, %s" % str(user_info.get("user_name", "")))


func _on_achievements_received(success: bool, _achievements: Array, error: String) -> void:
	if not success:
		_set_status("Achievements failed: %s" % error)
		return
	if test_achievement_id.is_empty():
		return
	Ludolio.unlock_achievement(test_achievement_id)


func _on_achievement_unlocked(achievement_id: String, success: bool, error: String) -> void:
	if success:
		_set_status("Unlocked %s" % achievement_id)
		return
	_set_status("Unlock %s failed: %s" % [achievement_id, error])


func _on_stats_requested(success: bool, error: String) -> void:
	if not success:
		_set_status("Stats failed: %s" % error)
		return
	if test_stat_id.is_empty():
		_set_status("Ready. User %s" % Ludolio.get_user_id())
		return
	var current = Ludolio.get_stat_int(test_stat_id)
	var next_value := 1
	if current != null:
		next_value = int(current) + 1
	Ludolio.set_stat_int(test_stat_id, next_value)
	Ludolio.store_stats()


func _on_stats_stored(success: bool, result_text: String) -> void:
	if success:
		_set_status("Ready. User %s" % Ludolio.get_user_id())
		return
	_set_status("Store stats failed: %s" % result_text)


func _set_status(text: String) -> void:
	print("[Ludolio sample] ", text)
	if status_label:
		status_label.text = text
