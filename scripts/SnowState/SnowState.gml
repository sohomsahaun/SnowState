/**
*	SnowState | v2.3.0
*	Documentation: https://github.com/sohomsahaun/SnowState/wiki
*
*	Author: Sohom Sahaun | @sohomsahaun
*/

/// @func SnowState(initial_state, [execute_enter])
/// @param {string} initial_state		Initial state for the state machine
/// @param {bool}	[execute_enter]		Whether to execute the "enter" event for the initial state (true) or not (false) [Default: true]
function SnowState(_initState) constructor {
	
	#region SnowState System
	
	enum SNOWSTATE_EVENT {
		NOT_DEFINED	= 0,
		DEFINED		= 1,
		INHERITED	= 2,
		DEFAULT		= 4,
	}
	
	var _execEnter = (argument_count > 1) ? argument[1] : true;
	var _owner = other;
	
	__this = {};
	
	with (__this) {
		owner			= _owner;
		states			= {};
		stateStartTime	= get_timer();
		initState		= _initState;
		execEnter		= _execEnter;
		currEvent		= undefined;
		parent			= {};
		childQueue		= [];
		history			= array_create(2, undefined);
		historyMaxSize	= max(0, SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE);
		historyEnabled	= SNOWSTATE_HISTORY_ENABLED;
		defaultEvents	= {
			enter: {
				exists: SNOWSTATE_EVENT.NOT_DEFINED,
				func: function() {}
			},
			leave: {
				exists: SNOWSTATE_EVENT.NOT_DEFINED,
				func: function() {}
			},
		};
		
		add = method(other, function(_name, _struct, _hasParent) {
			if (_struct == undefined) _struct = {};
			if (_hasParent == undefined) _hasParent = false;
			var _events, _state, _event, _i;
			
			with (__this) {
				if (!is_string(_name) || (_name == "")) {
					snowstate_error("State name should be a non-empty string.");
					return undefined;
				}
		
				if (SNOWSTATE_DEBUG_WARNING && is_state_defined(_name)) {
					snowstate_trace("State \"", _name, "\" has been defined already. The previous definition has been replaced.");
				}
		
				if (!is_struct(_struct)) {
					snowstate_error("State struct should be a struct.");
					return undefined;
				}
		
				_state = create_events_struct(_struct);
				states[$ _name] = _state;
				
				// Replace all events with parent's
				if (_hasParent) {
					update_from_parent(_name);

					// Replace parent's events with defined ones
					_events = variable_struct_get_names(_struct);
					_i = 0; repeat (array_length(_events)) {
						_event = _events[@ _i];
						_state[$ _event] = {
							exists: SNOWSTATE_EVENT.DEFINED,
							func: method(owner, _struct[$ _event])
						};
						++_i;
					}
				}
				
				// Update all the states
				update_states();
				
				// Execute "enter" event
				if (_name == initState) {
					if (execEnter) other.enter();
				}
			}
		});
	
		add_event_method = method(other, function(_event) {
			var _temp = {
				exec : __this.execute,
				event: _event
			};
			self[$ _event] = method(_temp, function() {
				exec(event);
			});
			return self;
		});
	
		assert_event_available = method(other, function(_event) {
			with (__this) {
				if (!variable_struct_exists(defaultEvents, _event)) {
					set_default_event(_event, function() {}, SNOWSTATE_EVENT.NOT_DEFINED);
				}
			}
			return self;
		});
	
		assert_event_name_valid = method(other, function(_event) {
			with (__this) {
				if (variable_struct_exists(defaultEvents, _event)) return true;
				if (variable_struct_exists(other, _event)) {
					snowstate_error("Can not use \"", _event, "\" as an event.");
					return false;
				}
			}
			return true;
		});
		
		change = method(other, function(_state, _leave, _enter) {
			var _defLeave, _defEnter;
			_defLeave = leave;
			_defEnter = enter;
			leave = _leave;
			enter = _enter;
			
			leave();
			with (__this) {
				if (array_length(childQueue) > 0) {
					history[@ 0] = childQueue[@ 0];
					childQueue = [];
				}
				
				stateStartTime = get_timer();
				history_add(_state);
			}
			enter();
			
			leave = _defLeave;
			enter = _defEnter;
		
			return self;
		});

		create_events_struct = method(other, function(_struct) {
			var _events = {};
			var _arr, _i, _event, _defEvent;
			
			with (__this) {
				_arr = variable_struct_get_names(_struct);
				_i = 0; repeat(array_length(_arr)) {
					_event = _arr[@ _i];
					assert_event_name_valid(_event);
					assert_event_available(_event);
					_events[$ _event] = {
						exists: SNOWSTATE_EVENT.DEFINED,
						func: method(owner, _struct[$ _event])
					};
					++_i;
				}
		
				_arr = variable_struct_get_names(defaultEvents);
				_i = 0; repeat(array_length(_arr)) {
					_event = _arr[@ _i];
					_defEvent = defaultEvents[$ _event];
					if (!variable_struct_exists(_struct, _event)) {
						_events[$ _event] = {
							exists: _defEvent.exists,
							func: method(owner, _defEvent.func)
						};
					}
					++_i;
				}
			}
		
			return _events;
		});
	
		execute = method(other, function(_event, _state) {
			with (__this) {
				if (_state == undefined) _state = history[@ 0];
				currEvent = _event;
			
				if (!is_state_defined(_state)) {
					snowstate_error("State \"", _state, "\" is not defined.");
					return undefined;
				}
				
				states[$ _state][$ _event].func();
			}
			
			return self;
		});
			
		get_current_state = method(other, function() {
			with (__this) {
				var _state = ((array_length(history) > 0) ? history[@ 0] : undefined);
				if (array_length(childQueue) > 0) _state = childQueue[@ 0];
				return _state;
			}
		});
	
		history_add = method(other, function(_state) {
			with (__this) {
				if (historyEnabled) {
					if (history[@ 1] == undefined) {
						history[@ 1] = history[@ 0];
						history[@ 0] = _state;
					} else {
						array_insert(history, 0, _state);
						history_fit_contents();
					}
				} else {
					history[@ 1] = history[@ 0];
					history[@ 0] = _state;
				}
			}
			return self;
		});
	
		history_fit_contents = method(other, function() {
			with (__this) {
				array_resize(history, max(2, min(historyMaxSize, array_length(history))));
			}
			return self;
		});
	
		is_really_a_method = method(other, function(_method) {
			try {
				return is_method(method(undefined, _method));
			} catch (_e) {
				return false;	
			}
		});
		
		is_state_defined = method(other, function(_state) {
			return (is_string(_state) && variable_struct_exists(__this.states, _state));
		});
	
		set_default_event = method(other, function(_event, _method, _defined) {
			with (__this) {
				defaultEvents[$ _event] = {
					exists: _defined,
					func: _method
				};
				add_event_method(_event);
			}
			return self;
		});
	
		snowstate_error = method(other, function() {
			var _str = "[SnowState]\n";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			_str += "\n\n\n";
			show_error(_str, true);
		});
	
		snowstate_trace = method(other, function() {
			var _str = "[SnowState] ";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			show_debug_message(_str);
		});
	
		update_from_parent = method(other, function(_name) {
			var _parent, _state, _events, _event, _exists, _parEvent, _i;
			
			with (__this) {
				_parent = states[$ parent[$ _name]];
				_state  = states[$ _name];
				
				_events = variable_struct_get_names(_parent);
				_i = 0; repeat (array_length(_events)) {
					_event = _events[@ _i];
					_parEvent = _parent[$ _event];
					
					_exists = SNOWSTATE_EVENT.NOT_DEFINED;
					switch (_parEvent.exists) {
						case SNOWSTATE_EVENT.DEFINED	: _exists = SNOWSTATE_EVENT.INHERITED;	break;	
						case SNOWSTATE_EVENT.INHERITED	: _exists = SNOWSTATE_EVENT.INHERITED;	break;	
						case SNOWSTATE_EVENT.DEFAULT	: _exists = SNOWSTATE_EVENT.DEFAULT;	break;
						default: break;
					}
					
					_state[$ _event] = {
						exists: _exists,
						func: _parEvent.func
					};
					++_i;
				}
			}
			
			return self;
		});
	
		update_states = method(other, function(_hasParent) {
			var _states, _events, _state, _event, _defEvent, _i, _j;
			
			with (__this) {
				_states = variable_struct_get_names(states);
				_events = variable_struct_get_names(defaultEvents);
		
				_i = 0; repeat(array_length(_states)) {
					_state = states[$ _states[@ _i]];
					_j = 0; repeat(array_length(_events)) {
						_event = _events[@ _j];
						if (!variable_struct_exists(_state, _event)) {
							_defEvent = defaultEvents[$ _event];
							_state[$ _event] = {
								exists: _defEvent.exists,
								func: method(owner, _defEvent.func)
							};
						}
						++_j;
					}
					++_i;
				}
			}
		
			return self;
		});
	}

	#endregion
	
	#region Basics
	
	add = function(_name, _struct) {
		__this.add(_name, _struct, false);
		return self;
	};
	
	change = function(_state, _leave, _enter) {
		if (_leave == undefined) _leave = -1;
		if (_enter == undefined) _enter = -1;
		if (_leave == -1) _leave = leave;
		if (_enter == -1) _enter = enter;
		
		with (__this) {
			if (!is_really_a_method(_leave)) {
				snowstate_error("Invalid command \"", _leave, "\" in change().");
				return undefined;
			}
		
			if (!is_really_a_method(_enter)) {
				snowstate_error("Invalid command \"", _enter, "\" in change().");
				return undefined;
			}
		
			change(_state, _leave, _enter);
		}
		
		return self;
	};
	
	state_is = function(_target, _source) {
		if (_source == undefined) _source = get_current_state();
		var _state = _source;
			
		with (__this) {
			if (!is_string(_target) || (_target == "")) {
				snowstate_error("State name should be a non-empty string.");
				return undefined;
			}
			
			if (!is_string(_source) || (_source == "")) {
				snowstate_error("State name should be a non-empty string.");
				return undefined;
			}
		
			while (_state != undefined) {
				if (_state == _target) return true;
				_state = variable_struct_exists(parent, _state) ? parent[$ _state] : undefined;
			}
		}
		
		return false;
	};
	
	get_states = function() {
		with (__this) {
			return variable_struct_get_names(states);	
		}
	};
	
	get_current_state = function() {
		with (__this) {
			return get_current_state();
		}
	};
	
	get_previous_state = function() {
		with (__this) {
			return ((array_length(history) > 1) ? history[@ 1] : undefined);
		}
	};
	
	get_time = function(_seconds) {
		if (_seconds == undefined) _seconds = false;
		var _time = (get_timer()-__this.stateStartTime) * 1/1000000;
		return (_seconds ? _time : floor(_time * game_get_speed(gamespeed_fps)));
	};
	
	#endregion
	
	#region Inheritance
	
	add_child = function(_parent, _name, _struct) {
		with (__this) {
			if (!is_string(_parent) || (_parent == "")) {
				snowstate_error("State name should be a non-empty string.");
				return undefined;
			}
			
			if (!is_state_defined(_parent)) {
				snowstate_error("State \"", _parent, "\" is not defined.");
				return undefined;
			}
				
			if (_parent == _name) {
				snowstate_error("Cannot set a state as a parent to itself.");
				return undefined;
			}
			
			if (SNOWSTATE_DEBUG_WARNING && variable_struct_exists(parent, _name)) {
				if (parent[$ _name] == _parent) {
					snowstate_trace("State \"", _name, "\" is already a child of \"", _parent, "\".");
					break;
				}
			}
			
			parent[$ _name] = _parent;
			add(_name, _struct, true);
		}
		
		return self;		
	};
	
	inherit = function() {
		with (__this) {
			var _state = history[@ 0];
			
			if (SNOWSTATE_DEBUG_WARNING && !variable_struct_exists(parent, _state)) {
				snowstate_trace("State \"", _state, "\" has no parent state.");
				break;
			}
			
			if (SNOWSTATE_CIRCULAR_INHERITANCE_ERROR) {
				var _str, _len, _i;
				_len = array_length(childQueue);
				_str = "";
				_i = 0; repeat (_len) {
					if (childQueue[@ _i] == _state) break;
					++_i;
				}
				
				if (_i < _len) {
					_str += string(_state);
					repeat (_len-_i-1) {
						++_i;
						_str += " -> " + string(childQueue[@ _i]);
					}
					_str += " -> " + string(_state);
					snowstate_error("Circular inheritance found. Inheritance chain: ",
									"(-> reads as \"inherits from\")\n", _str);
					return undefined;
				}
			}
			
			array_push(childQueue, _state);
			_state = parent[$ _state];
			history[@ 0] = _state;
			execute(currEvent);
			if (array_length(childQueue) > 0) history[@ 0] = array_pop(childQueue);
		}
		
		return self;
	};
	
	#endregion
	
	#region Events
	
	event_set_default_function = function(_event, _function) {
		with (__this) {
			if (SNOWSTATE_DEBUG_WARNING && (variable_struct_names_count(states) > 0)) {
				snowstate_trace("event_set_default_function() should be called before defining any state.");
			}
		
			if (!is_string(_event) || (_event == "")) {
				snowstate_error("Event should be a non-empty string.");
				return undefined;
			}
		
			if (!is_really_a_method(_function)) {
				snowstate_error("Default function should be a function.");
				return undefined;
			}
		
			assert_event_name_valid(_event);
			set_default_event(_event, method(owner, _function), SNOWSTATE_EVENT.DEFAULT);
			update_states();
		}
		
		return self;
	};
	
	event_exists = function(_event) {
		try {
			return __this.states[$ get_current_state()][$ _event].exists;
		} catch(_e) {}
		
		return SNOWSTATE_EVENT.NOT_DEFINED;
	};
	
	enter = function() {
		__this.execute("enter");
		return self;
	};
	
	leave = function() {
		__this.execute("leave");
		return self;
	};
	
	#endregion
	
	#region History
	
	history_enable = function() {
		with (__this) {
			if (!historyEnabled) {
				historyEnabled = true;
				history_fit_contents();
			}
		}
		return self;
	};
	
	history_disable = function() {
		with (__this) {
			if (historyEnabled) {
				historyEnabled = false;
				array_resize(history, 2);
			}
		}
		return self;
	};
	
	history_is_enabled = function() {
		return __this.historyEnabled;
	};
	
	set_history_max_size = function(_size) {
		with (__this) {
			if (!is_real(_size)) {
				snowstate_error("Size should be a number.");
				return undefined;
			}
			if (_size < 0) {
				if (SNOWSTATE_DEBUG_WARNING) {
					snowstate_trace("History size should non-negative. Setting the size to 0 instead of ", _size, ".");
				}
				_size = 0;
			}
			historyMaxSize = _size;
			history_fit_contents();
		}
		
		return self;
	};
	
	get_history_max_size = function() {
		return __this.historyMaxSize;	
	};
	
	get_history = function() {
		var _prev = get_previous_state();
		with (__this) {
			if (!historyEnabled) {
				if (SNOWSTATE_DEBUG_WARNING) {
					snowstate_trace("History is disabled, can not get_history().");	
				}
				return [];
			}
			if (_prev == undefined) return [get_current_state()];
			var _len = min(array_length(history), historyMaxSize);
			var _arr = array_create(_len);
			array_copy(_arr, 0, history, 0, _len);
			_arr[@ 0] = get_current_state();
			return _arr;
		}
	};
	
	#endregion
	
	// Initialization
	with (__this) {
		if (!is_string(_initState) || (_initState == "")) {
			snowstate_error("State name should be a non-empty string.");
		}
		
		history_add(_initState);
	}

}

#macro SNOWSTATE_VERSION "v2.3.0"
#macro SNOWSTATE_DATE "30-06-2021"

show_debug_message("[SnowState] You are using SnowState by @sohomsahaun (Version: " + string(SNOWSTATE_VERSION) + " | Date: " + string(SNOWSTATE_DATE) + ")");
