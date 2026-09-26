fsm = new SnowState("hello");
fsm.history_set_enabled(true);
fsm.history_set_max_size(8);

fsm.on(SnowState.EV_STATE_CHANGE, function(_payload) {
	var _json = json_stringify(_payload);
	show_debug_message($"State changed!\t{_json}");
});

fsm.add_state("hello",
	new SnowState.Event("enter", function() {
		show_debug_message("enter hello");
	}),
	new SnowState.Event("step", function() {
		show_debug_message($"hello timer: {fsm.get_time()}")
	}),
	new SnowState.Event("exit", function() {
		show_debug_message("exit hello");
	}),
);

fsm.add_state("world",
	new SnowState.Event("enter", function() {
		show_debug_message("enter world");
	}),
	new SnowState.Event("step", function() {
		show_debug_message($"world timer: {fsm.get_time()}")
	}),
	new SnowState.Event("exit", function() {
		show_debug_message("exit world");
	}),
);

fsm.add_transition("t_space_release", "hello", "world");
fsm.add_transition("t_space_release", "world", "hello");