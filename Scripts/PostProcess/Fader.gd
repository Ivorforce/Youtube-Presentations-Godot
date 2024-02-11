class_name Fader extends Object

var rd: RenderingDevice
var shader_fader: RID
var buffer_globals: RID

@warning_ignore("shadowed_variable")
func init(rd: RenderingDevice):
	self.rd = rd
	shader_fader = rd.shader_create_from_spirv(load("res://Scripts/PostProcess/fader.glsl").get_spirv())

	buffer_globals = rd.storage_buffer_create(4)
	
func fade(texture: RID, amount: float):
	rd.buffer_update(buffer_globals, 0, 4, PackedFloat32Array([amount]).to_byte_array())

	var uniform_set_globals := rd.uniform_set_create([
		IvRd.make_storage_buffer_uniform(buffer_globals, 0)
	], shader_fader, 0)
	
	var uniform_set_texture := rd.uniform_set_create([
		IvRd.make_image_uniform(texture, 0)
	], shader_fader, 1)
	
	var pipeline := rd.compute_pipeline_create(shader_fader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_globals, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_texture, 1)
	rd.compute_list_dispatch(compute_list, 1920, 1080, 1)
	rd.compute_list_end()

	rd.free_rid(pipeline)
