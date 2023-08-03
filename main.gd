extends Node2D


func _ready():
	var button_white = $ui/Control/ColorRect/MarginContainer/ButtonFlowContainer/Button as Button
	button_white.grab_focus()
	button_white.pressed.emit()
