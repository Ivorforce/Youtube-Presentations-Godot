extends Node2D

var rd: RenderingDevice
var shader_tracer: RID
var shader_renderer: RID
var fader: Fader

var ray_count: int
var bounce_count: int

var paths_texture: RID
var splotch_texture: RID
var uniform_set_textures: RID

var buffer_raytracer_globals: RID
var uniform_set_raytracer_globals: RID
var buffer_renderer_globals: RID
var uniform_set_renderer_globals: RID
var buffer_paths: RID
var uniform_set_tracer_rays: RID
var uniform_set_renderer_rays: RID
var buffer_ray_attributes: RID
var uniform_set_ray_attributes: RID
var pipeline_tracer: RID
var pipeline_renderer: RID

var start_time: float = -1.0
var prev_distance: float = 0.0

@onready
var rays: Sprite2D = $"../Rays"
@onready
var splotches: Sprite2D = $"../Splotches"

# Called when the node enters the scene tree for the first time.
func _ready():
	# local rendering device texture can't be rendered
	#rd = RenderingServer.create_local_rendering_device()
	rd = RenderingServer.get_rendering_device()
	
	shader_tracer = rd.shader_create_from_spirv(load("res://Scripts/Raytracer/raytracer.glsl").get_spirv())
	pipeline_tracer = rd.compute_pipeline_create(shader_tracer)
	
	shader_renderer = rd.shader_create_from_spirv(load("res://Scripts/Raytracer/rayrenderer.glsl").get_spirv())
	pipeline_renderer = rd.compute_pipeline_create(shader_renderer)
	
	fader = Fader.new()
	fader.init(rd)
	
	setup_output_texture(1920, 1080)
	
	buffer_raytracer_globals = rd.storage_buffer_create(16)
	uniform_set_raytracer_globals = rd.uniform_set_create([
		IvRd.make_storage_buffer_uniform(buffer_raytracer_globals, 0),
	], shader_tracer, 0)
	
	buffer_renderer_globals = rd.storage_buffer_create(20)
	uniform_set_renderer_globals = rd.uniform_set_create([
		IvRd.make_storage_buffer_uniform(buffer_renderer_globals, 0),
	], shader_renderer, 0)
	
func setup_output_texture(width: int, height: int):
	var tex_format = RDTextureFormat.new()
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.width = width
	tex_format.height = height
	tex_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tex_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

	paths_texture = rd.texture_create(tex_format, RDTextureView.new())
	(rays.texture as Texture2DRD).texture_rd_rid = paths_texture

	splotch_texture = rd.texture_create(tex_format, RDTextureView.new())
	(splotches.texture as Texture2DRD).texture_rd_rid = splotch_texture

	uniform_set_textures = rd.uniform_set_create([
		IvRd.make_image_uniform(paths_texture, 0),
		IvRd.make_image_uniform(splotch_texture, 1)
	], shader_renderer, 2)

@warning_ignore("shadowed_variable", "shadowed_global_identifier")
func trace(seed: int, ray_count: int, bounce_count: int, setup: int):
	rd.buffer_update(buffer_raytracer_globals, 0, 16, PackedInt32Array([
		seed, ray_count, bounce_count, setup
	]).to_byte_array())
	
	if self.ray_count != ray_count or self.bounce_count != bounce_count:
		self.ray_count = ray_count
		self.bounce_count = bounce_count
		
		if buffer_paths:
			rd.free_rid(buffer_paths)
		buffer_paths = rd.storage_buffer_create(ray_count * bounce_count * 4 * 4)
	
		if buffer_ray_attributes:
			rd.free_rid(buffer_ray_attributes)
		buffer_ray_attributes = rd.storage_buffer_create(ray_count)
		
		uniform_set_tracer_rays = rd.uniform_set_create([
			IvRd.make_storage_buffer_uniform(buffer_paths, 0),
			IvRd.make_storage_buffer_uniform(buffer_ray_attributes, 1)
		], shader_tracer, 1)
		uniform_set_renderer_rays = rd.uniform_set_create([
			IvRd.make_storage_buffer_uniform(buffer_paths, 0),
			IvRd.make_storage_buffer_uniform(buffer_ray_attributes, 1)
		], shader_renderer, 1)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_tracer)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_raytracer_globals, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_tracer_rays, 1)
	rd.compute_list_dispatch(compute_list, ray_count, 1, 1)
	rd.compute_list_end()

func render_at_position(distance: float, filterMode: int):
	# Skip the first frame of drawing backlog
	if prev_distance == 0:
		prev_distance = distance
	
	var globals_array := PackedFloat32Array([distance, prev_distance]).to_byte_array()
	globals_array.append_array(PackedInt32Array([ray_count, bounce_count, filterMode]).to_byte_array())
	rd.buffer_update(buffer_renderer_globals, 0, 20, globals_array)
		
	var compute_list_renderer := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list_renderer, pipeline_renderer)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_renderer_globals, 0)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_renderer_rays, 1)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_textures, 2)
	rd.compute_list_dispatch(compute_list_renderer, ray_count, 1, 1)
	rd.compute_list_end()
	
	prev_distance = distance

func _physics_process(delta):
	if Input.is_action_just_pressed("space"):
		#trace(randi(), 1024 * 1400, 10, 0)
		trace(randi(), 1024 * 500, 10, 1)
		start_time = Time.get_ticks_msec()
		prev_distance = 0.0
	
	if start_time > 0.0:
		fader.fade(paths_texture, 0.0001 ** delta)
		#render_at_position(9900 + (Time.get_ticks_msec() - start_time) / 1000.0 * 200.0, 0)
		render_at_position(0 + (Time.get_ticks_msec() - start_time) / 1000.0 * 200.0, 0)
