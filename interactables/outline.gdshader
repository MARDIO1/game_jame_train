// 共享白色轮廓：沿合并外壳的法线扩张顶点，只绘制扩张外壳的背面。
shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_width_m = 0.03;

void vertex() {
	VERTEX += NORMAL * outline_width_m;
}

void fragment() {
	ALBEDO = vec3(1.0);
}
