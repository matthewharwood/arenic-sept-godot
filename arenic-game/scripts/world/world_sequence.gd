class_name ArenicWorldSequence
extends Node
## Extend this scene controller for a future intro. No entry sequence is installed now.
## Put AnimationPlayer.root_node at the stage and animate CameraRig focus_world/view_span.
signal finished
var stage: ArenicOverworldStage

func start(world_stage: ArenicOverworldStage) -> void:
	stage = world_stage
	# A sequence without authored animation immediately returns control.
	finish()

func cancel() -> void:
	# Override to stop all animation/audio players, then call finish().
	finish()

func finish() -> void:
	finished.emit()
