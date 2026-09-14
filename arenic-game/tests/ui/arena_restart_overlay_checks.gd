extends SceneTree
## The restart presenter consumes state and fits the world rect; it owns no clock.

var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var overlay := ArenicArenaRestartOverlay.new()
	root.add_child(overlay)
	if not _check(not overlay.visible and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.focus_mode == Control.FOCUS_NONE, "A new presenter is hidden and cannot capture input."):
		return
	var caption := overlay.get_node("Caption") as Label
	var readout := overlay.get_node("Readout") as Label
	for child: Control in [caption, readout]:
		if not _check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE and child.focus_mode == Control.FOCUS_NONE, "Text passes pointer and keyboard focus through."):
			return
	for bounds: Vector2 in [Vector2(1254, 589), Vector2(640, 360), Vector2(240, 160)]:
		overlay.size = bounds
		overlay.present("rewind", 0, 3679.0, null)
		if not _check(overlay.visible and caption.text == "Rewinding" and readout.text == "1:01", "Rewind reports the supplied 60 Hz visual clock.") or not _check_layout(overlay, caption, readout):
			return
		for count: int in [3, 2, 1]:
			overlay.present("countdown", count, 0.0, null)
			if not _check(caption.text == "Arena starts in" and readout.text == str(count), "Countdown shows the owner's current integer without advancing it.") or not _check_layout(overlay, caption, readout):
				return
		overlay.present("", 0, 0.0, null)
		if not _check(not overlay.visible, "An empty phase removes the entire presentation."):
			return
	# Resizing while shown must remeasure without another present call.
	overlay.size = Vector2(1254, 589)
	overlay.present("countdown", 2, 0.0, null)
	overlay.size = Vector2(210, 140)
	if not _check_layout(overlay, caption, readout):
		return
	await process_frame
	if not _check(readout.text == "2", "A process frame never consumes countdown time."):
		return
	overlay.present("rewind", 0, 7200.0, null)
	if not _check(readout.text == "2:00", "The cycle endpoint has an exact minute readout."):
		return
	overlay.present("rewind", 0, NAN, null)
	if not _check(readout.text == "0:00", "An invalid transient clock cannot create invalid display text."):
		return
	overlay.present("unknown", 0, 0.0, null)
	if not _check(not overlay.visible, "An unsupported presentation phase fails closed."):
		return
	overlay.free()
	print("Arena restart overlay checks passed: %d assertions; responsive phase display and input transparency." % _checks)
	quit(0)


func _check_layout(overlay: ArenicArenaRestartOverlay, caption: Label, readout: Label) -> bool:
	var bounds := Rect2(Vector2.ZERO, overlay.size)
	var panel: Rect2 = overlay._panel_rect
	if not (_check(bounds.encloses(panel) and panel.encloses(caption.get_rect()) and panel.encloses(readout.get_rect()), "The measured panel and text remain inside the actual world rectangle.") \
		and _check(not caption.get_rect().intersects(readout.get_rect()), "Caption and countdown/clock have separate measured rows.") \
		and _check(is_equal_approx(panel.get_center().x, overlay.size.x * 0.5), "Both phases stay horizontally centered when the world rectangle changes.")):
		return false
	if overlay._phase == "rewind":
		var factor: float = minf(1.0, minf(overlay.size.x / 320.0, overlay.size.y / 220.0))
		return _check(is_equal_approx(panel.position.y, 12.0 * factor), "The compact rewind badge sits at the scaled top inset.") \
			and _check(panel.end.y < overlay.size.y * 0.5, "The rewind badge leaves the arena center and founder path unobscured.")
	return _check(panel.get_center().is_equal_approx(overlay.size * 0.5), "The three-second countdown retains its centered placement.")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition
