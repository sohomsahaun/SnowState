// Draw current State

draw_rectangle_color(0, 0, 190, 43, c_black, c_black, c_black, c_black, false);

draw_set_font(fDemo);
draw_set_color(c_white);

var _state = get_current_state(id);
_state = string_upper(string_char_at(_state, 1)) + string_copy(_state, 2, string_length(_state)-1);
draw_text(10, 10, "State: " + _state);
