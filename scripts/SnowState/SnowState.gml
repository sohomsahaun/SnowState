/**
*	SnowState | v3.0.0
*	Documentation: https://github.com/sohomsahaun/SnowState/wiki
*
*	Author: Sohom Sahaun | @sohomsahaun
*/

/// @func SnowState(initial_state, [execute_enter])
/// @param {string} initial_state		Initial state for the state machine
/// @param {bool}   [execute_enter]		Whether to execute the "enter" event for the initial state (true) or not (false) [Default: true]
function SnowState(_initState, _execEnter = true) constructor {
	
	#region SnowState System
	
	enum SNOWSTATE_EVENT {
		NOT_DEFINED	= 0,
		DEFINED		= 1,
		INHERITED	= 2,
		DEFAULT		= 4,
	}
	
	enum SNOWSTATE_TRIGGER {
		NOT_DEFINED	= 0,
		DEFINED		= 1,
		INHERITED	= 2,
	}
	
	var _owner = other;
	__this = {};		// Container for "private" members
	
	with (__this) {
		owner			= _owner;		// Context of the SnowState instances
		states			= {};			// Struct holding states
		transitions		= {};			// Struct holding transitions
		wildTransitions	= {};			// Struct holding wildcard transitions
		initState		= _initState;	// Initial state of the SnowState instance
		execEnter		= _execEnter;	// If the "enter" event should be executed by default or not
		currEvent		= undefined;	// Current event
		tempEvent		= undefined;	// Temporary event - Used when changing states
		parent			= {};			// Inheritance tree
		childQueue		= [];			// Path from current state to it's ancestor(s)
		stateStartTime	= get_timer();	// Start time of the current state (in microseconds)
		history			= array_create(2, undefined);	// Array holding the history
		historyMaxSize	= max(0, SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE);	// Maximum size of history
		historyEnabled	= SNOWSTATE_HISTORY_ENABLED;	// If history is enabled or not
		defaultEvents	= {		// Default functions for events
			enter: {
				exists: SNOWSTATE_EVENT.NOT_DEFINED,
				func: function() {}
			},
			leave: {
				exists: SNOWSTATE_EVENT.NOT_DEFINED,
				func: function() {}
			},
		};
		invalidStateNames = [	// It is what it is
			SNOWSTATE_WILDCARD_TRANSITION_NAME,
			SNOWSTATE_REFLEXIVE_TRANSITION_NAME,
		];
		
		/// @param {string} state_name
		/// @param {struct} state_struct
		/// @param {bool} has_parent
		/// @returns {SnowState} self
		add = method(other, function(_name, _struct, _hasParent) {
			var _events, _state, _event, _i;
			var _self = self;
			
			with (__this) {
				_state = create_events_struct(_struct);
				states[$ _name] = _state;
				
				// Update from parent
				if (_hasParent) {
					// Get events from parent
					update_events_from_parent(_name);

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
					if (execEnter) {
						stateStartTime = get_timer();
						_self.enter();
					}
				}
			}
		});
		
		/// @param {string} name
		/// @param {string} from
		/// @param {string} to
		/// @param {function} condition
		/// @param {function} leave_func
		/// @param {function} enter_func
		/// @returns {SnowState} self
		add_transition = method(other, function(_transitionName, _from, _to, _condition, _leave, _enter) {
			with (__this) {
				// Define the transition
				var _transition = {
					from		: _from,
					to			: _to,
					condition	: _condition,
					exists		: SNOWSTATE_TRIGGER.DEFINED,
					leave		: _leave,
					enter		: _enter
				};
				
				if (_from == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
					// Wildcard transition
					if (!variable_struct_exists(wildTransitions, _transitionName)) {
						wildTransitions[$ _transitionName] = [];
					}
					
					array_push(wildTransitions[$ _transitionName], _transition);
				} else {
					// Normal transition
    				if (!variable_struct_exists(transitions, _from)) {
    					transitions[$ _from] = {};
    				}
    				if (!variable_struct_exists(transitions[$ _from], _transitionName)) {
    					transitions[$ _from][$ _transitionName] = [];
    				}
    				
    				array_push(transitions[$ _from][$ _transitionName], _transition);
				}
			}
			
			return self;
		})
	
		/// @param {string} event
		/// @returns {SnowState} self
		add_event_method = method(other, function(_event) {
			var _temp = {
				exec : __this.execute,
				event: _event
			};
			self[$ _event] = method(_temp, function() {
				var _args = array_create(argument_count);
				var _i = 0; repeat(argument_count) {
					_args[_i] = argument[_i];
					++_i;
				}
				exec(event, undefined, _args);
			});
			return self;
		});
	
		/// @param {string} event
		/// @returns {SnowState} self
		assert_event_available = method(other, function(_event) {
			with (__this) {
				if (!variable_struct_exists(defaultEvents, _event)) {
					set_default_event(_event, function() {}, SNOWSTATE_EVENT.NOT_DEFINED);
				}
			}
			return self;
		});
	
		/// @param {string} event
		/// @returns {SnowState} self
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
	
		/// @param {string} state_name
		/// @param {bool} [show_error]
		/// @returns {bool} Whether the name is valid (true), or not (false)
		assert_state_name_valid = method(other, function(_state, _error = true) {
			with (__this) {
				var _func = snowstate_error;
				if (!_error) {
					_func = SNOWSTATE_DEBUG_WARNING ? snowstate_trace : undefined;
				}
				
				if (!is_string(_state) || (_state == "")) {
					if (_func != undefined) _func("State name should be a non-empty string.");
					return false;
				}
				
				var _name, _i;
				_i = 0; repeat (array_length(invalidStateNames)) {
					_name = invalidStateNames[@ _i]; ++_i;
					if (_state == _name) {
						if (_func != undefined) _func("State name can not be \"", _name, "\".");
						return false;
					}
				}
				
				return true;
			}
		});
	
		/// @param {string} transition_name
		/// @param {bool} [show_error]
		/// @returns {bool} Whether the name is valid (true), or not (false)
		assert_transition_name_valid = method(other, function(_state, _error = true) {
			with (__this) {
				var _func = snowstate_error;
				if (!_error) {
					_func = SNOWSTATE_DEBUG_WARNING ? snowstate_trace : undefined;
				}
				
				if (!is_string(_state) || (_state == "")) {
					if (_func != undefined) _func("Transition name should be a non-empty string.");
					return false;
				}
				
				return true;
			}
		});
		
		/// @param {string} state_name
		/// @param {function} leave_func
		/// @param {function} enter_func
		/// @returns {SnowState} self
		change = method(other, function(_state, _leave, _enter) {
			var _defLeave, _defEnter, _self;
			_self = self;
			_defLeave = leave;
			_defEnter = enter;
			leave = _leave;
			enter = _enter;
			
			with (__this) {
				// Leave current state
				tempEvent = _defLeave;
				with (_self) leave();
				
				// Add to history
				if (array_length(childQueue) > 0) {
					history[@ 0] = childQueue[@ 0];
					childQueue = [];
				}
				
				// Init state
				stateStartTime = get_timer();
				history_add(_state);
				
				// Enter next state
				tempEvent = _defEnter;
				with (_self) enter();
				
				// Reset temp variable
				tempEvent = undefined;
			}
			
			leave = _defLeave;
			enter = _defEnter;
		
			return self;
		});
		
		/// @param {struct} state_struct
		/// @return {struct} Struct filled with all possible events
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
		
		/// @param {string} event
		/// @param {string} [state_name]
		/// @param {array} [args]
		/// @returns {SnowState} self
		execute = method(other, function(_event, _state = __this.history[@ 0], _args = []) {
			with (__this) {
				if (!is_state_defined(_state)) {
					snowstate_error("State \"", _state, "\" is not defined.");
					return undefined;
				}
				
				currEvent = _event;
				var _func = states[$ _state][$ _event].func;
				with (owner) script_execute_ext(method_get_index(_func), _args);
			}
			
			return self;
		});

		/// @returns {string} The current state
		get_current_state = method(other, function() {
			with (__this) {
				var _state = ((array_length(history) > 0) ? history[@ 0] : undefined);
				if (array_length(childQueue) > 0) _state = childQueue[@ 0];
				return _state;
			}
		});
		
		/// @param {string} state
		/// @returns {SnowState} self
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
		
		/// @returns {SnowState} self
		history_fit_contents = method(other, function() {
			with (__this) {
				array_resize(history, max(2, min(historyMaxSize, array_length(history))));
			}
			return self;
		});
		
		/// @returns {bool} Whether the argument is a method or a function (true), or not (false)
		is_really_a_method = method(other, function(_method) {
			try {
				return is_method(method(undefined, _method));
			} catch (_e) {
				return false;	
			}
		});
		
		/// @param {string} state_name
		/// @return {bool} Whether the state is defined (true), or not (false)
		is_state_defined = method(other, function(_state) {
			with (__this) {
				return (is_string(_state) && variable_struct_exists(states, _state));
			}
		});
		
		/// @param {string} event
		/// @param {function} method
		/// @param {int} defined
		/// @returns {SnowState} self
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
		
		/// @param {any} [args]
		/// @returns {SnowState} self
		snowstate_error = method(other, function() {
			var _str = "[SnowState]\n";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			_str += "\n\n\n";
			show_error(_str, true);
			return self;
		});
		
		/// @param {any} [args]
		/// @returns {SnowState} self
		snowstate_trace = method(other, function() {
			var _str = "[SnowState] ";
			var _i = 0; repeat(argument_count) {
				_str += string(argument[_i++]);	
			}
			show_debug_message(_str);
			return self;
		});
		
		/// @param {string} transition_name
		/// @param {string} from_state
		/// @returns {int} SNOWSTATE_TRIGGER
		transition_exists = method(other, function(_transitionName, _from) {
			with (__this) {
				if (_from == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
					// Wildcard transition
					if (variable_struct_exists(wildTransitions, _transitionName)) {
						return SNOWSTATE_TRIGGER.DEFINED;
					}
				} else {
					// Default	
					if (variable_struct_exists(transitions, _from) && variable_struct_exists(transitions[$ _from], _transitionName)) {
						return SNOWSTATE_TRIGGER.DEFINED;
					}
					while (variable_struct_exists(parent, _from)) {
						_from = parent[$ _from];
						if (variable_struct_exists(transitions, _from) && variable_struct_exists(transitions[$ _from], _transitionName)) {
							return SNOWSTATE_TRIGGER.INHERITED;
						}
					}
				}
				
				return SNOWSTATE_TRIGGER.NOT_DEFINED;
			}
		});
	
		/// @param {array} transitions
		/// @param {string} source_state
		/// @param {string} trigger_name
		/// @returns {bool} Whether the trigger is successful (true), or not (false)
		try_triggers = method(other, function(_transitions, _source, _trigger) {
			with (__this) {
				var _transition, _dest, _i;
				_i = 0; repeat(array_length(_transitions)) {
					_transition = _transitions[@ _i]; ++_i;
					
					// For reflexive wildcard transitions, change to source
					_dest = _transition.to;
					if (_dest == SNOWSTATE_REFLEXIVE_TRANSITION_NAME) _dest = _source;
					
					// Check condition
					if (_transition.condition(_trigger, _source, _dest)) {
						change(_dest, _transition.leave, _transition.enter);
						return true;
					}
				}
					
				return false;
			}
		});
		
		/// @param {string} state_name
		/// @returns {SnowState} self
		update_events_from_parent = method(other, function(_name) {
			with (__this) {
				var _parent, _state, _events, _event, _exists, _parEvent, _i;
			
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
		
		/// @param {bool} has_parent
		/// @returns {SnowState} self
		update_states = method(other, function(_hasParent) {
			with (__this) {
				var _states, _events, _state, _event, _defEvent, _i, _j;
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
	
	/// @param {string} state_name
	/// @param {struct} [state_struct]
	/// @returns {SnowState} self
	add = function(_name, _struct = {}) {
		with (__this) {
			if (!assert_state_name_valid(_name)) return undefined;
	
			if (!is_struct(_struct)) {
				snowstate_error("State struct should be a struct.");
				return undefined;
			}
	
			if (SNOWSTATE_DEBUG_WARNING && is_state_defined(_name)) {
				snowstate_trace("State \"", _name, "\" has been defined already. Replacing the previous definition.");
			}
			
			add(_name, _struct, false);
		}
		
		return self;
	};

	/// @param {string} state_name
	/// @param {function} [leave_func]
	/// @param {function} [enter_func]
	/// @returns {SnowState} self
	change = function(_state, _leave = leave, _enter = enter) {
		with (__this) {
			if (!is_really_a_method(_leave)) {
				snowstate_error("Invalid value for \"leave_func\" in change(). Should be a function.");
				return undefined;
			}
		
			if (!is_really_a_method(_enter)) {
				snowstate_error("Invalid value for \"enter_func\" in change(). Should be a function.");
				return undefined;
			}
		
			change(_state, _leave, _enter);
		}
		
		return self;
	};

	/// @param {string} state_name
	/// @param {string} [state_to_check]
	/// @returns {bool} Whether state_name is state_to_check or a parent of state_to_check (true), or not (false)
	state_is = function(_target, _source = get_current_state()) {
		var _state = _source;
			
		with (__this) {
			if (!assert_state_name_valid(_target)) return false;
			if (!assert_state_name_valid(_source)) return false;
		
			while (_state != undefined) {
				if (_state == _target) return true;
				_state = variable_struct_exists(parent, _state) ? parent[$ _state] : undefined;
			}
		}
		
		return false;
	};
	
	/// @returns {array} Array containing the states defined
	get_states = function() {
		with (__this) {
			return variable_struct_get_names(states);	
		}
	};
	
	/// @returns {string} The current state
	get_current_state = function() {
		with (__this) {
			return get_current_state();
		}
	};
	
	/// @returns {string} The previous state
	get_previous_state = function() {
		with (__this) {
			return ((array_length(history) > 1) ? history[@ 1] : undefined);
		}
	};
	
	/// @param {bool} [seconds]
	/// @returns {number} Number of steps (or seconds) the current state has been running for
	get_time = function(_seconds = true) {
		with (__this) {
			var _time = (get_timer()-stateStartTime) * 1/1000000;
			return (_seconds ? _time : (_time * game_get_speed(gamespeed_fps)));
		}
	};
	
	/// @param {number} time
	/// @param {bool} [seconds]
	/// @returns {SnowState} self
	set_time = function(_time, _seconds = true) {
		with (__this) {
			if (!is_real(_time)) {
				snowstate_error("Time should be a number");
				return undefined;
			}
			if (!_seconds) _time *= 1/game_get_speed(gamespeed_fps);
			stateStartTime = get_timer() - _time;
		}
		
		return self;
	};
	
	#endregion
	
	#region Inheritance
	
	/// @param {string} parent_state_name
	/// @param {string} state_name
	/// @param {struct} [state_struct]
	/// @return {SnowState} self
	add_child = function(_parent, _name, _struct = {}) {
		with (__this) {
			if (!assert_state_name_valid(_name)) return undefined;
			if (!assert_state_name_valid(_parent)) return undefined;
			
			if (!is_state_defined(_parent)) {
				snowstate_error("State \"", _parent, "\" is not defined.");
				return undefined;
			}
				
			if (_parent == _name) {
				snowstate_error("Cannot set a state as a parent to itself.");
				return undefined;
			}
	
			if (!is_struct(_struct)) {
				snowstate_error("State struct should be a struct.");
				return undefined;
			}
			
			if (SNOWSTATE_DEBUG_WARNING) {
				if (is_state_defined(_name)) {
					snowstate_trace("State \"", _name, "\" has been defined already. The previous definition has been replaced.");
				}
				
				if (variable_struct_exists(parent, _name)) {
					if (parent[$ _name] == _parent) {
						snowstate_trace("State \"", _name, "\" is already a child of \"", _parent, "\".");
						break;
					}
				}
			}
			
			parent[$ _name] = _parent;
			add(_name, _struct, true);
		}
		
		return self;		
	};
	
	/// @returns {SnowState} self
	inherit = function() {
		with (__this) {
			var _state = history[@ 0];
			
			if (!variable_struct_exists(parent, _state)) {
				if (SNOWSTATE_DEBUG_WARNING) {
					snowstate_trace("State \"", _state, "\" has no parent state.");
				}
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
	
	/// @param {string} event
	/// @param {function} function
	/// @returns {SnowState} self
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
	
	/// NOTE: This function is only meant to be used in change()
	/// @returns {function}
	event_get_current_function = function() {
		with (__this) {
			return tempEvent;	
		}
	}
	
	/// @param {string} event
	/// @returns {int} SNOWSTATE_EVENT
	event_exists = function(_event) {
		with (__this) {
			if (!is_string(_event) || (_event == "")) {
				if (SNOWSTATE_DEBUG_WARNING) {
					snowstate_trace("Event should be a non-empty string.");
				}
				return SNOWSTATE_EVENT.NOT_DEFINED;
			}
			
			var _state = get_current_state();
			if (!variable_struct_exists(states[$ _state], _event)) return SNOWSTATE_EVENT.NOT_DEFINED;
			return states[$ get_current_state()][$ _event].exists;
		}
	};

	/// @returns {SnowState} self
	enter = function() {
		with (__this) {
			execute("enter");
		}
		
		return self;
	};
	
	/// @returns {SnowState} self
	leave = function() {
		with (__this) {
			execute("leave");
		}
		
		return self;
	};
	
	#endregion
	
	#region Transitions

	/// @param {string} transition_name
	/// @param {string/array} source_state
	/// @param {string} dest_state
	/// @param {function} [condition]
	/// @param {function} [leave_func]
	/// @param {function} [enter_func]
	/// @returns {SnowState} self
	add_transition = function(_transitionName, _source, _dest, _condition = function() { return true; }, _leave = leave, _enter = enter) {
		with (__this) {
			if (!assert_transition_name_valid(_transitionName)) return undefined;
			if (!is_string(_dest) || (_dest == "")) {
				snowstate_error("State name should be a non-empty string.");
				return undefined;
			}
			if (_dest == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
				snowstate_error("Destination state name can not be the same as SNOWSTATE_WILDCARD_TRANSITION_NAME.");
				return undefined;
			}
			
			if (!is_really_a_method(_condition)) {
				snowstate_error("Invalid value for \"condition\" in add_transition(). Should be a function.");
				return undefined;
			}
			if (!is_really_a_method(_leave)) {
				snowstate_error("Invalid value for \"leave_func\" in add_transition(). Should be a function.");
				return undefined;
			}
			if (!is_really_a_method(_enter)) {
				snowstate_error("Invalid value for \"enter_func\" in add_transition(). Should be a function.");
				return undefined;
			}
			
			if (!is_array(_source)) _source = [_source];
			
			var _i, _from;
			_i = 0; repeat (array_length(_source)) {
				_from = _source[@ _i]; ++_i;
				if (!is_string(_from) || (_from == "")) {
					if (SNOWSTATE_DEBUG_WARNING) {
						snowstate_trace("State name should be a non-empty string. Transition not added.");	
					}
				} else if (_from == SNOWSTATE_REFLEXIVE_TRANSITION_NAME) {
					if (SNOWSTATE_DEBUG_WARNING) {
						snowstate_trace("Source state name can not be the same as SNOWSTATE_REFLEXIVE_TRANSITION_NAME. Transition not added.");	
					}
				} else {
					add_transition(_transitionName, _from, _dest, _condition, _leave, _enter);
				}
			}
		}
		
		return self;
	};
	
	/// @param {string} transition_name
	/// @param {string} dest_state
	/// @param {function} [condition]
	/// @param {function} [leave_func]
	/// @param {function} [enter_func]
	/// @returns {SnowState} self
	add_wildcard_transition = function(_transitionName, _dest, _condition = function() { return true; }, _leave, _enter) {
		return add_transition(_transitionName, SNOWSTATE_WILDCARD_TRANSITION_NAME, _dest, _condition, _leave, _enter);
	};
	
	/// @param {string} transition_name
	/// @param {string/array} source_state
	/// @param {function} [condition]
	/// @param {function} [leave_func]
	/// @param {function} [enter_func]
	/// @returns {SnowState} self
	add_reflexive_transition = function(_transitionName, _source, _condition = function() { return true; }, _leave, _enter) {
		return add_transition(_transitionName, _source, SNOWSTATE_REFLEXIVE_TRANSITION_NAME, _condition, _leave, _enter);
	};
	
	/// @param {string} transition_name
	/// @param {string} source_state
	/// @returns {int} SNOWSTATE_TRIGGER
	transition_exists = function(_transitionName, _source) {
		with (__this) {
			if (!assert_state_name_valid(_source, false)) return false;
			if (!assert_transition_name_valid(_transitionName, false)) return false;
			
			return transition_exists(_transitionName, _source);
		}
	};
	
	/// @param {string} transition_name
	/// @returns {bool} Whether the transition has been triggered (true), or not (false)
	trigger = function(_transitionName) {
		with (__this) {
			if (!assert_transition_name_valid(_transitionName)) return false;
			
			var _currState, _source;
			_currState = get_current_state();
			_source    = _currState;
			
			// My triggers
			if (transition_exists(_transitionName, _source) == SNOWSTATE_TRIGGER.DEFINED) {
				if (try_triggers(transitions[$ _source][$ _transitionName], _currState, _transitionName)) return true;
			}
				
			// Wild triggers
			if (transition_exists(_transitionName, SNOWSTATE_WILDCARD_TRANSITION_NAME) == SNOWSTATE_TRIGGER.DEFINED) {
				if (try_triggers(wildTransitions[$ _transitionName], _currState, _transitionName)) return true;
			}
			
			// Parent triggers
			while (variable_struct_exists(parent, _source)) {
				_source = parent[$ _source];
				if (transition_exists(_transitionName, _source) == SNOWSTATE_TRIGGER.DEFINED) {
					if (try_triggers(transitions[$ _source][$ _transitionName], _currState, _transitionName)) return true;
				}
			}
			
			return false;
		}
	};

	#endregion
	
	#region History
	
	/// @returns {SnowState} self
	history_enable = function() {
		with (__this) {
			if (!historyEnabled) {
				historyEnabled = true;
				history_fit_contents();
			}
		}
		
		return self;
	};
	
	/// @returns {SnowState} self
	history_disable = function() {
		with (__this) {
			if (historyEnabled) {
				historyEnabled = false;
				array_resize(history, 2);
			}
		}
		
		return self;
	};
	
	/// @returns {bool} Whether state history is enabled (true), or not (false)
	history_is_enabled = function() {
		with (__this) {
			return historyEnabled;
		}
	};
	
	/// @param {int} size
	/// @returns {SnowState} self
	history_set_max_size = function(_size) {
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
	
	/// @returns {int} The maximum storage capacity of state history
	history_get_max_size = function() {
		with (__this) {
			return historyMaxSize;
		}	
	};
	
	/// @returns {array} Array containing the state history
	history_get = function() {
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
		assert_state_name_valid(_initState);
		history_add(_initState);
	}
}
// Startup errors
if (!is_string(SNOWSTATE_WILDCARD_TRANSITION_NAME) || (string_length(SNOWSTATE_WILDCARD_TRANSITION_NAME) != 1)) {
	var _str = "[SnowState]\n";
	_str += "SNOWSTATE_WILDCARD_TRANSITION_NAME should be a string of length 1."
	_str += "\n\n\n";
	show_error(_str, true);
}

if (!is_string(SNOWSTATE_REFLEXIVE_TRANSITION_NAME) || (string_length(SNOWSTATE_REFLEXIVE_TRANSITION_NAME) != 1)) {
	var _str = "[SnowState]\n";
	_str += "SNOWSTATE_REFLEXIVE_TRANSITION_NAME should be a string of length 1."
	_str += "\n\n\n";
	show_error(_str, true);
}

// Some info
#macro SNOWSTATE_VERSION "v3.0.0"
#macro SNOWSTATE_DATE "15-11-2021"

show_debug_message("[SnowState] You are using SnowState by @sohomsahaun (Version: " + string(SNOWSTATE_VERSION) + " | Date: " + string(SNOWSTATE_DATE) + ")");
