extends Control
## Settings screen (from the main menu).


func _ready() -> void:
	var v := UiKit.screen(self)
	UiKit.header(v, I18n.t("Settings"), func() -> void: SceneRouter.to_menu())
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(c)
	var panel := SettingsPanel.new()
	panel.show_close = false
	panel.language_changed.connect(func() -> void: SceneRouter.to_settings()) # rebuild in the new language
	c.add_child(panel)


func on_back() -> void:
	SceneRouter.to_menu()
