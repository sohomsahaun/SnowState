draw_set_font(fDemo);
draw_set_halign(fa_right);
draw_set_valign(fa_bottom);

var _x, _y, _diff, _thickness;
_diff = 24;
_thickness = 1;

_x = display_get_gui_width()-10;
_y = display_get_gui_height()-10;

if (showControls) {
				 draw_text_outline(_x, _y, "F2 = Hide Controls",				c_white, c_black, _thickness);
	_y -= _diff; draw_text_outline(_x, _y, "H = Show/Hide history",				c_white, c_black, _thickness);
	_y -= _diff; draw_text_outline(_x, _y, "C/Q = Recall the sword",			c_white, c_black, _thickness);
	_y -= _diff; draw_text_outline(_x, _y, "X/E = Throw the sword",				c_white, c_black, _thickness);
	_y -= _diff; draw_text_outline(_x, _y, "Z/Space = Attack the sword",		c_white, c_black, _thickness);
	_y -= _diff; draw_text_outline(_x, _y, "Arrow Keys = Movement and Jump",	c_white, c_black, _thickness);
} else {
				 draw_text_outline(_x, _y, "F2 = Show Controls",				c_black, c_white, _thickness);
}

if (showHistory) {
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);

	_x = 10;
	_y = 10;

	var _str, _states, _i;
	_states = oPlayer.fsm.get_history();
	_str = "groundAttack3";
	
	draw_set_alpha(.9);
	draw_rectangle_color(0, 0, 20+string_width(_str), display_get_gui_height(),
						 c_black, c_black, c_black, c_black, 0);
	draw_set_alpha(1);
	
	draw_text_outline(_x, _y, "HISTORY", c_white, c_black, _thickness);
	_y += 10;
	
	_i = 0; repeat (array_length(_states)) {
		_y += _diff; draw_text_outline(_x, _y, _states[@ _i], c_white, c_black, _thickness);
		++_i;
	}
}