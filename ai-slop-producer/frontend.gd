extends Control

@export var text_field : Node
@export var label : Node

func _on_button_pressed() -> void:
	send()
	
func _process(delta: float) -> void:
	label.text = API.reply
	if Input.is_action_just_pressed("send"):
		send()
	
func send():
	if text_field.text != "":
		API.send_message(text_field.text)
		text_field.text = ""
