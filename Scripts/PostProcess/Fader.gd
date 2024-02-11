class_name Fader extends Object

var rd: RenderingDevice
var shader_fader: RID

@warning_ignore("shadowed_variable")
func init(rd: RenderingDevice):
	self.rd = rd
	shader_fader = rd.shader_create_from_spirv(load("res://Scripts/PostProcess/fader.glsl").get_spirv())

func fade(texture: RID, amount: float):
	var buffer_globals := rd.storage_buffer_create(4, PackedFloat32Array([amount]).to_byte_array())
	var uniform_globals := RDUniform.new()
	uniform_globals.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_globals.binding = 0
	uniform_globals.add_id(buffer_globals)
	var uniform_set_globals := rd.uniform_set_create([uniform_globals], shader_fader, 0)
	
	var uniform_texture := RDUniform.new()
	uniform_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture.binding = 0
	uniform_texture.add_id(texture)
	var uniform_set_texture := rd.uniform_set_create([uniform_texture], shader_fader, 1)
	
	var pipeline := rd.compute_pipeline_create(shader_fader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_globals, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_texture, 1)
	rd.compute_list_dispatch(compute_list, 1920, 1080, 1)
	rd.compute_list_end()

	rd.free_rid(buffer_globals)
	rd.free_rid(pipeline)
