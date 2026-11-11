
shader_type spatial;

uniform vec3 background_color : source_color = vec3(0.16, 0.17, 0.19);
uniform vec3 grid_color : source_color = vec3(0.35, 0.37, 0.40);
uniform vec3 major_grid_color : source_color = vec3(0.48, 0.50, 0.54);

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 pos = world_position.xz;

    // Small grid: every 1 unit
    vec2 small_grid = abs(fract(pos - 0.5) - 0.5);
    vec2 small_width = fwidth(pos);
    float small_line = 1.0 - min(
        min(small_grid.x / small_width.x,
            small_grid.y / small_width.y),
        1.0
    );

    // Major grid: every 5 units
    vec2 major_grid = abs(fract(pos / 5.0 - 0.5) - 0.5);
    vec2 major_width = fwidth(pos / 5.0);
    float major_line = 1.0 - min(
        min(major_grid.x / major_width.x,
            major_grid.y / major_width.y),
        1.0
    );

    vec3 color = mix(background_color, grid_color, small_line);
    color = mix(color, major_grid_color, major_line);

    ALBEDO = color;
    ROUGHNESS = 1.0;
}
