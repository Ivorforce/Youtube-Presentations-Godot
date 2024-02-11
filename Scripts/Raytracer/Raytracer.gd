extends Node2D

var rd: RenderingDevice
var shader_tracer: RID
var shader_renderer: RID
var fader

var output_texture: RID

@onready
var rays: Sprite2D = $"../Rays"

# Called when the node enters the scene tree for the first time.
func _ready():
	# local rendering device texture can't be rendered
	#rd = RenderingServer.create_local_rendering_device()
	rd = RenderingServer.get_rendering_device()
	shader_tracer = rd.shader_create_from_spirv(load("res://Scripts/Raytracer/raytracer.glsl").get_spirv())
	shader_renderer = rd.shader_create_from_spirv(load("res://Scripts/Raytracer/rayrenderer.glsl").get_spirv())
	fader = Fader.new()
	fader.init(rd)
	
	var tex_format = RDTextureFormat.new()
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.depth = 1
	tex_format.width = 1920
	tex_format.height = 1080
	tex_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tex_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

	output_texture = rd.texture_create(tex_format, RDTextureView.new())
	
	trace(1024, 3, 0.0)

func trace(ray_count: int, seed: int, distance: float):
	var buffer_globals := rd.storage_buffer_create(4, PackedInt32Array([seed]).to_byte_array())
	var uniform_globals := RDUniform.new()
	uniform_globals.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_globals.binding = 0
	uniform_globals.add_id(buffer_globals)
	var uniform_set_globals := rd.uniform_set_create([uniform_globals], shader_tracer, 0)
	
	var buffer_paths := rd.storage_buffer_create(ray_count * 4 * 2)
	var uniform_paths := RDUniform.new()
	uniform_paths.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_paths.binding = 0
	uniform_paths.add_id(buffer_paths)
	var uniform_set_paths := rd.uniform_set_create([uniform_paths], shader_tracer, 1)
	
	var pipeline := rd.compute_pipeline_create(shader_tracer)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_globals, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_paths, 1)
	rd.compute_list_dispatch(compute_list, ray_count, 1, 1)
	rd.compute_list_end()

	#var time:= Time.get_ticks_msec()
	#rd.submit()
	#rd.sync()
	#print(Time.get_ticks_msec() - time)

	#var output_bytes := rd.buffer_get_data(buffer)
	#var output := output_bytes.to_float32_array()
	#print("Output: ", output)

	#################################################################

	var buffer_globals_renderer := rd.storage_buffer_create(4, PackedFloat32Array([distance]).to_byte_array())
	var uniform_globals_renderer := RDUniform.new()
	uniform_globals_renderer.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_globals_renderer.binding = 0
	uniform_globals_renderer.add_id(buffer_globals_renderer)
	var uniform_set_globals_renderer := rd.uniform_set_create([uniform_globals_renderer], shader_renderer, 0)
	
	var uniform_texture := RDUniform.new()
	uniform_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture.binding = 0
	uniform_texture.add_id(output_texture)
	var uniform_set_texture := rd.uniform_set_create([uniform_texture], shader_renderer, 2)
	
	var pipeline_renderer := rd.compute_pipeline_create(shader_renderer)
	var compute_list_renderer := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list_renderer, pipeline_renderer)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_globals_renderer, 0)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_paths, 1)
	rd.compute_list_bind_uniform_set(compute_list_renderer, uniform_set_texture, 2)
	rd.compute_list_dispatch(compute_list_renderer, ray_count, 1, 1)
	rd.compute_list_end()

	#var time_r := Time.get_ticks_msec()
	#rd.submit()
	#rd.sync()
	#print(Time.get_ticks_msec() - time_r)

	#var output_bytes := rd.buffer_get_data(buffer)
	#var output := output_bytes.to_float32_array()
	#print("Output: ", output)
	
	#var rd_g = RenderingServer.get_rendering_device()
	#var byte_data : PackedByteArray = rd.texture_get_data(texture, 0)
	#var image := Image.create_from_data(1920, 1080, false, Image.FORMAT_RGBAF, byte_data)
	#image.save_jpg("/Users/lukas/Downloads/test.jpg")

	#var texture_g := rd_g.texture_create(tex_format, RDTextureView.new(), [byte_data])
	#(rays.texture as Texture2DRD).texture_rd_rid = texture_g
	(rays.texture as Texture2DRD).texture_rd_rid = output_texture
	
	rd.free_rid(buffer_globals)
	rd.free_rid(buffer_paths)
	rd.free_rid(pipeline)
	
	rd.free_rid(buffer_globals_renderer)
	rd.free_rid(pipeline_renderer)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	fader.fade(output_texture, 0.1 ** delta)
	trace(1024, 3, Time.get_ticks_msec() / 1000.0 / 20.0)
