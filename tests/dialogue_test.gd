extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dialogue: MonWorldDialogue = MonWorldDialogue.new()
	root.add_child(dialogue)
	await process_frame
	dialogue.show_pages(["First page", "Second page"])
	if not dialogue.is_open() or dialogue.arrow_label.visible or dialogue.visible_count != 0:
		_fail("dialogue did not start in typing state")
		return
	dialogue._process(0.1)
	if dialogue.visible_count <= 0 or dialogue.arrow_label.visible:
		_fail("dialogue typewriter did not advance correctly")
		return
	dialogue.handle_action()
	if dialogue.visible_count != dialogue.current_text.length() or not dialogue.arrow_label.visible:
		_fail("dialogue action did not complete the current page")
		return
	dialogue.handle_action()
	if not dialogue.is_open() or dialogue.page_index != 1 or dialogue.visible_count != 0:
		_fail("dialogue action did not advance to the next page")
		return
	dialogue.handle_action()
	if dialogue.visible_count != dialogue.current_text.length() or not dialogue.arrow_label.visible:
		_fail("dialogue did not complete the final page")
		return
	dialogue.handle_action()
	if dialogue.is_open():
		_fail("dialogue did not close after the final page")
		return
	dialogue.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
