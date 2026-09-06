var _x = 12;
var _y = 12;

draw_set_colour(c_white);

var _history = fsm.history_get();
for (var _i = 0; _i < array_length(_history); ++_i) {
	var _state_name = _history[_i];
	draw_text(_x, _y + _i * 14, _state_name);
}