// Draw current State

draw_rectangle_color(0, 0, 125, 420, c_black, c_black, c_black, c_black, false);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fDemo);
draw_set_color(c_white);

var _str = "History:\n";

var _history = state.get_history();
var _i = 0; repeat(array_length(_history)) {
	_str += _history[@ _i] + "\n";
	++_i;
};

draw_text(10, 10, _str);