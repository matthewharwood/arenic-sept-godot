@tool
class_name ArenicClearingTree
extends Resource
## One authored tree placement. It never claims a gameplay tile.
@export var cell: Vector2 = Vector2.ZERO
@export_enum("Oak", "Birch", "Pine", "Crooked", "Fir") var variant: int = 0
@export_enum("North", "East", "South", "West") var facing: int = 0
