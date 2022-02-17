/**
*	Some commonly used scripts
*	Credit goes to the awesome GM community
*/

/// @func animation_end()
function animation_end() {
	return (image_index + image_speed*sprite_get_speed(sprite_index)/(sprite_get_speed_type(sprite_index)==spritespeed_framespergameframe? 1 : game_get_speed(gamespeed_fps)) >= image_number);	
}

/// @func lerp_smooth(val1, val2, amount, [offset])
function lerp_smooth(_val1, _val2, _amount, _offset = 0.01) {
	return ((abs(_val1-_val2) <= _offset) ? _val2 : lerp(_val1, _val2, 1/_amount));
}

/// @func draw_text_outline(x, y, string, text_col, outline_col, thickness)
function draw_text_outline(_x, _y, _string, _textCol, _outCol, _thickness) {
	var _xx, _yy;
	for (_xx = _x-_thickness; _xx <= _x+_thickness; ++_xx) {
		for (_yy = _y-_thickness; _yy <= _y+_thickness; ++_yy) {
			draw_text_color(_xx, _yy, _string, _outCol, _outCol, _outCol, _outCol, 1);
		}
	}
	draw_text_color(_x, _y, _string, _textCol, _textCol, _textCol, _textCol, 1);
	
	//var _dx, _dy, _i, _xx, _yy;
	//_dx = [-1, -1, -1,  0, 0,  1, 1, 1];
	//_dy = [-1,  0,  1, -1, 1, -1, 0, 1];
	//_i = 0; repeat (8) {
	//	_xx = _x + _dx[@ _i];
	//	_yy = _y + _dy[@ _i];
	//	draw_text_color(_xx, _yy, _string, _outCol, _outCol, _outCol, _outCol, 1);
	//	++_i;
	//}
	//draw_text_color(_x, _y, _string, _textCol, _textCol, _textCol, _textCol, 1);
}