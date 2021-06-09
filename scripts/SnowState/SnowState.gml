/**
*	SnowState | v2.1.1
*	Documentation: https://github.com/sohomsahaun/SnowState/wiki
*
*	Author: Sohom Sahaun | @sohomsahaun
*/

/// @func SnowState(initial_state, [execute_enter])
/// @param {string} initial_state		Initial state for the state machine
/// @param {bool}	[execute_enter]		Whether to execute the "enter" event for the initial state (true) or not (false) [Default: true]
function SnowState(_initState) constructor {	
	#region System
	var _execEnter = (argument_count > 1) ? argument[1] : true;
	var _owner = other;
	
	__this = {
		owner			: _owner,
		states			: {},
		stateStartTime	: get_timer(),
		initState		: _initState,
		execEnter		: _execEnter,
		history			: [],
		historyMaxSize	: max(1, SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE),
		historyEnabled	: SNOWSTATE_HISTORY_ENABLED,
		defaultEvents	: {
			enter: function() {},
			leave: function() {}
		}
	};
	
	with (__this) {
		is_really_a_method = method(other, function(_method) {
			try {
				return is_method(method(undefined, _method));
			} catch (_e) {
				return false;	
			}
		});
		
		snowstate_error = method(other, function() {
			var _str = "SnowState Error:\n";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			show_error(_str, true);
		});
	
		snowstate_trace = method(other, function() {
			var _str = "[SnowState] ";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			show_debug_message(_str);
		});
	
		is_state_defined = method(other, function(_state) {
			return (is_string(_state) && variable_struct_exists(__this.states, _state));
		});
	
		assert_event_name_valid = method(other, function(_event) {
			if (variable_struct_exists(__this.defaultEvents, _event)) return true;
			if (variable_struct_exists(self, _event)) {
				__this.snowstate_error("Can not use \"", _event, "\" as an event.");
				return false;
			}
			return true;
		});
	
		add_event_method = method(other, function(_event) {
			var _temp = {
				exec: __this.execute,
				event: _event
			};
			self[$ _event] = method(_temp, function() {
				exec(event);
			});
			return self;
		});
	
		set_default_event = method(other, function(_event, _method) {
			__this.defaultEvents[$ _event] = _method;
			__this.add_event_method(_event);
			return self;
		});
	
		assert_event_available = method(other, function(_event) {
			if (!variable_struct_exists(__this.defaultEvents, _event)) {
				__this.set_default_event(_event, function() {});
			}
			return self;
		});
	
		create_events_struct = method(other, function(_struct) {
			var _events = {};
			var _arr, _i, _event;
		
			_arr = variable_struct_get_names(_struct);
			_i = 0; repeat(array_length(_arr)) {
				_event = _arr[@ _i];
				__this.assert_event_name_valid(_event);
				__this.assert_event_available(_event);
				_events[$ _event] = method(__this.owner, _struct[$ _event]);
				++_i;
			}
		
			_arr = variable_struct_get_names(__this.defaultEvents);
			_i = 0; repeat(array_length(_arr)) {
				_event = _arr[@ _i];
				if (!variable_struct_exists(_struct, _event)) {
					_events[$ _event] = method(__this.owner, __this.defaultEvents[$ _event]);
				}
				++_i;
			}
		
			return _events;
		});
	
		update_states = method(other, function() {
			var _state, _event, _states, _events, _i, _j;
			_states = variable_struct_get_names(__this.states);
			_events = variable_struct_get_names(__this.defaultEvents);
		
			_i = 0; repeat(array_length(_states)) {
				_state = __this.states[$ _states[@ _i]];
				_j = 0; repeat(array_length(_events)) {
					_event = _events[@ _j];
					if (!variable_struct_exists(_state, _event)) {
						_state[$ _event] = __this.defaultEvents[$ _event];
					}
					++_j;
				}
				++_i;
			}
		
			return self;
		});
	
		history_fit_contents = method(other, function() {
			array_resize(__this.history, min(array_length(__this.history), __this.historyMaxSize));
			return self;
		});
	
		history_resize = method(other, function(_size) {
			__this.historyMaxSize = _size;
			__this.history_fit_contents();
		});
	
		history_add = method(other, function(_state) {
			if (__this.historyEnabled) {
				array_insert(__this.history, 0, _state);
				__this.history_fit_contents();
			} else {
				__this.history[@ 0] = _state;
			}
			return self;
		});
	
		execute = method(other, function(_event) {
			var _state = __this.history[@ 0];
			if (!__this.is_state_defined(_state)) {
				__this.snowstate_error("State \"", _state, "\" is not defined.");
				return undefined;
			}
			__this.states[$ _state][$ _event]();
			return self;
		});
	
		change = method(other, function(_state, _leave, _enter) {
			__this.stateStartTime = get_timer();
		
			_leave();
			__this.history_add(_state);
			_enter();
		
			return self;
		});
	}
	#endregion
	
	enter = function() {
		__this.execute("enter");
		return self;
	};
	
	leave = function() {
		__this.execute("leave");
		return self;
	};
	
	add = function(_name, _struct) {
		if (!is_string(_name) || (_name == "")) {
			__this.snowstate_error("State name should be a non-empty string.");
			return undefined;
		}
		
		if (!is_struct(_struct)) {
			__this.snowstate_error("State struct should be a struct.");
			return undefined;
		}
		
		if (__this.is_state_defined(_name)) {
			__this.snowstate_error("State \"", _name, "\" has been defined already.");
			return undefined;
		}
		
		__this.states[$ _name] = __this.create_events_struct(_struct);
		__this.update_states();
		
		if (_name == __this.initState) {
			if (__this.execEnter) enter();
		}
		
		return self;
	};
	
	change = function(_state, _leave, _enter) {
		if (_leave == undefined) _leave = -1;
		if (_enter == undefined) _enter = -1;
		
		if (!__this.is_really_a_method(_leave)) {
			if (_leave != -1) {
				__this.snowstate_error("Invalid command \"", _leave, "\" in change().");
				return undefined;
			}
			_leave = leave;
		}
		
		if (!__this.is_really_a_method(_enter)) {
			if (_enter != -1) {
				__this.snowstate_error("Invalid command \"", _enter, "\" in change().");
				return undefined;
			}
			_enter = enter;
		}
		
		return __this.change(_state, _leave, _enter);
	};
	
	event_set_default_function = function(_event, _function) {
		if (SNOWSTATE_DEBUG_WARNING && (variable_struct_names_count(__this.states) > 0)) {
			__this.snowstate_trace("event_set_default_function() should be called before defining any state.");
		}
		
		if (!is_string(_event) || (_event == "")) {
			__this.snowstate_error("Event should be a non-empty string.");
			return undefined;
		}
		
		if (!__this.is_really_a_method(_function)) {
			__this.snowstate_error("Default function should be a function.");
			return undefined;
		}
		
		__this.assert_event_name_valid(_event);
		__this.set_default_event(_event, method(__this.owner, _function));
		__this.update_states();
		
		return self;
	};
	
	history_is_enabled = function() {
		return __this.historyEnabled;
	};
	
	history_enable = function() {
		if (!__this.historyEnabled) {
			__this.historyEnabled = true;
			__this.history_resize(__this.historyMaxSize);
		}
		return self;
	};
	
	history_disable = function() {
		if (__this.historyEnabled) {
			__this.historyEnabled = false;
			array_resize(__this.history, 1);
		}
		return self;
	};
	
	get_history = function() {
		if (!__this.historyEnabled) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__this.snowstate_trace("History is disabled, can not get_history().");	
			}
			return [];
		}
		var _len = array_length(__this.history);
		var _arr = array_create(_len);
		array_copy(_arr, 0, __this.history, 0, _len);
		return _arr;
	};
	
	set_history_max_size = function(_size) {
		if (!is_real(_size)) {
			__this.snowstate_error("Size should be a number.");
			return undefined;
		}
		if (_size < 1) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__this.snowstate_trace("History size should be 1 or more. Setting the size to 1 instead of ", _size, ".");
			}
			_size = 1;
		}
		__this.history_resize(_size);
		return self;
	};
	
	get_history_max_size = function() {
		return __this.historyMaxSize;	
	};
	
	get_current_state = function() {
		return ((array_length(__this.history) > 0) ? __this.history[@ 0] : "");
	};
	
	get_previous_state = function() {
		if (!__this.historyEnabled) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__this.snowstate_trace("History is disabled, can not get previous state.");	
			}
			return "";
		}
		return ((array_length(__this.history) > 1) ? __this.history[@ 1] : "");
	};
	
	get_time = function(_seconds) {
		if (_seconds == undefined) _seconds = false;
		var _factor = _seconds ? 1/1000000 : game_get_speed(gamespeed_fps)/1000000;
		return floor((get_timer()-__this.stateStartTime) * _factor);
	};
	
	// Initialization
	if (!is_string(_initState) || (_initState == "")) {
		__this.snowstate_error("State name should be a non-empty string.");
	}
	__this.history_add(_initState);
	
	if (__this.historyEnabled) history_enable();
		else history_disable();
}


#macro SNOWSTATE_VERSION "2.1.1"
#macro SNOWSTATE_DATE "10-06-2021"

show_debug_message("[SnowState] You are using SnowState by @sohomsahaun (Version: " + string(SNOWSTATE_VERSION) + " | Date: " + string(SNOWSTATE_DATE) + ")");