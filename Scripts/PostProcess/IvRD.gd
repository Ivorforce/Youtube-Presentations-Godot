class_name IvRd extends Node

static func make_storage_buffer_uniform(buffer_id: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer_id)
	return uniform

static func make_image_uniform(buffer_id: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(buffer_id)
	return uniform
