extends Area3D



func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.set_meta("hidden_count", body.get_meta("hidden_count", 0) + 1)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.set_meta("hidden_count", body.get_meta("hidden_count", 0) - 1)
