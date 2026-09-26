// 共享白色轮廓：在屏幕空间将背面外壳扩张固定像素。
shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_width_px : hint_range(0.5, 10.0, 0.5) = 3.0;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 view_offset = MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
	vec4 clip_pos = PROJECTION_MATRIX * view_pos;
	vec4 clip_offset = PROJECTION_MATRIX * view_offset;
	vec2 screen_pos = clip_pos.xy / clip_pos.w;
	vec2 screen_offset = clip_offset.xy / clip_offset.w;
	vec2 screen_normal = normalize(screen_offset - screen_pos);
	vec2 pixel_size = 2.0 / VIEWPORT_SIZE;
	clip_pos.xy += screen_normal * outline_width_px * pixel_size * clip_pos.w;
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = vec3(1.0);
}
