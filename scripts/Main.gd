extends Viewport

const SPAWNPOINTS_GROUP : String = "SpawnPoints"
const ENDPORTALS_GROUP : String = "EndPortals"
const COINS_GROUP : String = "Coins"

onready var level : TileMap = $TileMap
onready var player : Player = $Player

onready var container : ViewportContainer = get_parent();
onready var crt_shader = preload("res://shaders/CRT.gdshader");

var completionSound = preload("res://sfx/portal.wav")
var coinSound = preload("res://sfx/coin.wav")

func _ready() -> void:
	EventBus.connect("coin_collected", self, "_on_coin_collected", []);
	EventBus.connect("build_block", self, "_on_build")
	_hook_portals()
	EventBus.connect("crt_filter_toggle",self,"_on_crt_toggle");
	VisualServer.set_default_clear_color(Color.black)

func _hook_portals() -> void:
	for portal in get_tree().get_nodes_in_group(ENDPORTALS_GROUP):
		# Avoid objects that should not be in the group.
		if not portal is EndPortal:
			continue
		# Avoid connecting the same object several times.
		if portal.is_connected("body_entered", self, "_on_endportal_body_entered"):
			continue
		portal.connect("body_entered", self, "_on_endportal_body_entered", [ portal.next_level, portal ])

func _on_build() -> void:
	# If there is a child named TileMap, place a block.
	# Otherwise ignore. Note that this condition is false for some levels.
	if $TileMap != null:
		# Find the player's current position on the tilemap, and look one cell
		# to the left or right depending on which direction the player sprite
		# is facing.
		var player_tile = $TileMap.world_to_map($Player.position)
		var target_tile_x = player_tile[0] + 1
		if $Player.sprite.flip_h:
			target_tile_x = player_tile[0] - 1
		var target_tile_y = player_tile[1]
		var target_cell_v = $TileMap.get_cell(target_tile_x, target_tile_y)
		if target_cell_v == 0:
			# If the cell is empty, place a block
			$TileMap.set_cell(target_tile_x, target_tile_y, 1)
		elif target_cell_v == 1:
			# If the cell has a block in in, break the block.
			$TileMap.set_cell(target_tile_x, target_tile_y, 0)
		

func _on_endportal_body_entered(body : Node2D, next_level : PackedScene, portal) -> void:
	var animation = portal.on_portal_enter()
	body.visible = false;
	yield(animation, "animation_finished");
	body.visible = true;
	call_deferred("_finish_level", next_level)

func _finish_level(next_level : PackedScene = null) -> void:
	if next_level:
		# Create the new level, insert it into the tree and remove the old one.
		var new_level : TileMap = next_level.instance()
		add_child_below_node(level, new_level)
		remove_child(level)
		level = new_level

		# Do not forget to hook the new portals
		_hook_portals()
	
		#Removing instructions 
		$UI/UI/RichTextLabel.visible = false;

		# We need to flash the player out and in the tree to avoid physics errors.
		remove_child(player)
		add_child_below_node(level, player)
		player.global_position = _get_player_spawn_position()
		player.look_right()
		EventBus.emit_signal("level_started", {})

func _get_player_spawn_position() -> Vector2:
	var spawn_points = get_tree().get_nodes_in_group(SPAWNPOINTS_GROUP)
	return spawn_points[0].global_position if len(spawn_points) > 0 else player.global_position

func _on_crt_toggle (on:bool) -> void:
	if on:
		container.material.shader=crt_shader;
	else:
		container.material.shader=null;
