
extends Node3D

# WORLD SETTINGS
@export var world_size: float = 256.0
@export var subdivisions: int = 165
@export var random_seed: int = 12

# TERRAIN NOISE
var broad_noise: FastNoiseLite
var detail_noise: FastNoiseLite


func _ready() -> void:
	print("TERRAIN GENERATOR STARTED!")
	generate_terrain()


func generate_terrain() -> void:
	seed(random_seed)

	# CREATE BROAD TERRAIN NOISE
	broad_noise = FastNoiseLite.new()
	broad_noise.seed = random_seed
	broad_noise.frequency = 0.009
	broad_noise.fractal_octaves = 2
	broad_noise.fractal_lacunarity = 2.0
	broad_noise.fractal_gain = 0.45

	# CREATE SMALLER TERRAIN DETAILS
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = random_seed + 100
	detail_noise.frequency = 0.035
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.35

	# BEGIN BUILDING THE TERRAIN MESH
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_size := world_size / 2.0
	var step_size := world_size / float(subdivisions)

	# GENERATE TERRAIN GRID
	for z in range(subdivisions):
		for x in range(subdivisions):

			var x0 := -half_size + x * step_size
			var x1 := x0 + step_size
			var z0 := -half_size + z * step_size
			var z1 := z0 + step_size

			var v00 := Vector3(x0, get_height(x0, z0), z0)
			var v10 := Vector3(x1, get_height(x1, z0), z0)
			var v01 := Vector3(x0, get_height(x0, z1), z1)
			var v11 := Vector3(x1, get_height(x1, z1), z1)

			# ALTERNATE TRIANGLE DIRECTIONS FOR LOW-POLY LOOK
			if (x + z) % 2 == 0:
				add_triangle(surface_tool, v00, v01, v10)
				add_triangle(surface_tool, v10, v01, v11)
			else:
				add_triangle(surface_tool, v00, v01, v11)
				add_triangle(surface_tool, v00, v11, v10)

	# FINISH MESH
	surface_tool.generate_normals()
	var terrain_mesh := surface_tool.commit()

	# CREATE TERRAIN MATERIAL
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.9

	# CREATE TERRAIN BODY
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "GeneratedTerrain"
	add_child(terrain_body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = terrain_mesh
	mesh_instance.material_override = terrain_material
	terrain_body.add_child(mesh_instance)

	# CREATE TERRAIN COLLISION
	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(collision)

	# CREATE INVISIBLE WORLD BOUNDARIES
	create_boundaries(half_size)


func get_height(x: float, z: float) -> float:

	var half_size := world_size / 2.0

	# DISTANCE FROM CENTER OF MAP
	var edge_distance: float = maxf(
		absf(x),
		absf(z)
	) / half_size

	# TERRAIN TRANSITIONS
	var hills := smooth_range(0.22, 0.72, edge_distance)
	var mountains := smooth_range(0.65, 0.96, edge_distance)

	var broad := broad_noise.get_noise_2d(x, z)
	var detail := detail_noise.get_noise_2d(x, z)

	# BASE PLAINS
	var height := broad * 0.45 + detail * 0.20

	# ROLLING HILLS
	height += hills * (
		2.0 + broad * 7.0 + detail * 1.5
	)

	# ROUNDED MOUNTAINS
	height += mountains * (
		25.0 + broad * 11.0 + detail * 3.0
	)

	return height


func smooth_range(start: float, finish: float, value: float) -> float:
	var t := clampf(
		(value - start) / (finish - start),
		0.0,
		1.0
	)

	return t * t * (3.0 - 2.0 * t)


func add_triangle(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:

	# AVERAGE HEIGHT OF THE TRIANGLE
	var average_height := (a.y + b.y + c.y) / 3.0

	# GRASS AND ROCK COLORS
	var grass_color := Color(0.30, 0.55, 0.23)
	var rock_color := Color(0.43, 0.45, 0.47)

	# GRADUALLY TRANSITION FROM GRASS TO ROCK
	var rock_amount := smooth_range(9.0, 17.0, average_height)

	var face_color := grass_color.lerp(
		rock_color,
		rock_amount
	)

	# CONTROLLED COLOR VARIATION BETWEEN TRIANGLES
	var shade := randf_range(0.94, 1.06)
	face_color = face_color * shade

	# ADD TRIANGLE VERTICES IN REVERSED ORDER
	surface_tool.set_color(face_color)
	surface_tool.add_vertex(a)

	surface_tool.set_color(face_color)
	surface_tool.add_vertex(c)

	surface_tool.set_color(face_color)
	surface_tool.add_vertex(b)


func create_boundaries(half_size: float) -> void:

	var boundary_body := StaticBody3D.new()
	boundary_body.name = "WorldBoundaries"
	add_child(boundary_body)

	# NORTH AND SOUTH WALLS
	add_boundary_wall(
		boundary_body,
		Vector3(world_size, 100.0, 4.0),
		Vector3(0, 35.0, -half_size)
	)

	add_boundary_wall(
		boundary_body,
		Vector3(world_size, 100.0, 4.0),
		Vector3(0, 35.0, half_size)
	)

	# EAST AND WEST WALLS
	add_boundary_wall(
		boundary_body,
		Vector3(4.0, 100.0, world_size),
		Vector3(-half_size, 35.0, 0)
	)

	add_boundary_wall(
		boundary_body,
		Vector3(4.0, 100.0, world_size),
		Vector3(half_size, 35.0, 0)
	)


func add_boundary_wall(
	parent: StaticBody3D,
	wall_size: Vector3,
	wall_position: Vector3
) -> void:

	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()

	wall_shape.size = wall_size
	wall_collision.shape = wall_shape
	wall_collision.position = wall_position

	parent.add_child(wall_collision)
