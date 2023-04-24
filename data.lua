local styles = data.raw["gui-style"].default

styles["VRM_table"] = {
	type = "table_style",
	vertical_centering = true,
	vertical_spacing = 0,
	horizontal_spacing = 0,
	right_cell_padding = 9,
	left_cell_padding  = 0
}

styles["VRM_frame"] = {
	type = "frame_style",
	right_padding = -1,
	vertically_stretchable = "on",
	horizontally_stretchable = "on",
	graphical_set = {
		base = {
			center = {position = {336, 0}, size = {1, 1}},
			opacity = 0.35,
			background_blur = false,
			blend_mode = "multiplicative-with-alpha"
		},
		shadow = default_glow(hard_shadow_color, 1)
	}
}
