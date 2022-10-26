/**
*	SnowState | v3.1.4
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
	__owner				= _owner;		// Context of the SnowState instances
	__states			= {};			// Struct holding states
	__transitions		= {};			// Struct holding transitions
	__wildTransitions	= {};			// Struct holding wildcard transitions
	__on_events			= {};			// Struct holding events for .on()
	__initState			= _initState;	// Initial state of the SnowState instance
	__execEnter			= _execEnter;	// If the "enter" event should be executed by default or not
	__currEvent			= undefined;	// Current event
	__tempEvent			= undefined;	// Temporary event - Used when changing states
	__parent			= {};			// Inheritance tree
	__childQueue		= [];			// Path from current state to it's ancestor(s)
	__stateStartTime	= get_timer();	// Start time of the current state (in microseconds)
	__history			= array_create(2, undefined);	// Array holding the history
	__historyMaxSize	= max(0, SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE);	// Maximum size of history
	__historyEnabled	= SNOWSTATE_HISTORY_ENABLED;	// If history is enabled or not
	__defaultEvents		= {		// Default functions for events
		enter: {
			exists: SNOWSTATE_EVENT.NOT_DEFINED,
			func: function() {}
		},
		leave: {
			exists: SNOWSTATE_EVENT.NOT_DEFINED,
			func: function() {}
		},
	};
	__invalidStateNames = [	// It is what it is
		SNOWSTATE_WILDCARD_TRANSITION_NAME,
		SNOWSTATE_REFLEXIVE_TRANSITION_NAME,
	];
	
	// Add .on() events
	__on_events[$ "state changed"] = undefined;
		
	/// @param {string} state_name
	/// @param {struct} state_struct
	/// @param {bool} has_parent
	/// @returns {SnowState} self
	__add = function(_name, _struct, _hasParent) {
		var _events, _state, _event, _i;
		
		_state = __create_events_struct(_struct);
		__states[$ _name] = _state;
		
		// Update from parent
		if (_hasParent) {
			// Get events from parent
			__update_events_from_parent(_name);

			// Replace parent's events with defined ones
			_events = variable_struct_get_names(_struct);
			_i = 0; repeat (array_length(_events)) {
				_event = _events[_i];
				_state[$ _event] = {
					exists: SNOWSTATE_EVENT.DEFINED,
					func: method(__owner, _struct[$ _event])
				};
				++_i;
			}
		}
				
		// Update all the states
		__update_states();
				
		// Execute "enter" event
		if (_name == __initState) {
			if (__execEnter) {
				__stateStartTime = get_timer();
				enter();
			}
		}
		
		return self;
	};
		
	/// @param {string} name
	/// @param {string} from
	/// @param {string} to
	/// @param {function} condition
	/// @param {function} leave_func
	/// @param {function} enter_func
	/// @returns {SnowState} self
	__add_transition = function(_transitionName, _from, _to, _condition, _leave, _enter) {
		// Define the transition
		var _transition = {
			//from		: _from,
			to			: _to,
			condition	: _condition,
			exists		: SNOWSTATE_TRIGGER.DEFINED,
			leave		: _leave,
			enter		: _enter
		};
				
		if (_from == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
			// Wildcard transition
			if (!variable_struct_exists(__wildTransitions, _transitionName)) {
				__wildTransitions[$ _transitionName] = [];
			}
					
			array_push(__wildTransitions[$ _transitionName], _transition);
		} else {
			// Normal transition
    		if (!variable_struct_exists(__transitions, _from)) {
    			__transitions[$ _from] = {};
    		}
    		if (!variable_struct_exists(__transitions[$ _from], _transitionName)) {
    			__transitions[$ _from][$ _transitionName] = [];
    		}
    				
    		array_push(__transitions[$ _from][$ _transitionName], _transition);
		}
			
		return self;
	};
	
	/// @param {string} event
	/// @returns {SnowState} self
	__add_event_method = function(_event) {
		var _temp = {
			exec : __execute,
			event: _event
		};
		self[$ _event] = method(_temp, function() {
			var _args = undefined;
			if (argument_count > 0) {
				_args = array_create(argument_count);
				var _i = 0; repeat(argument_count) {
					_args[_i] = argument[_i];
					++_i;
				}
			}
			exec(event, undefined, _args);
		});
		
		return self;
	};
	
	/// @param {string} event
	/// @returns {SnowState} self
	__assert_event_available = function(_event) {
		if (!variable_struct_exists(__defaultEvents, _event)) {
			__set_default_event(_event, function() {}, SNOWSTATE_EVENT.NOT_DEFINED);
		}

		return self;
	};
	
	/// @param {string} event
	/// @returns {SnowState} self
	__assert_event_name_valid = function(_event) {
		if (variable_struct_exists(__defaultEvents, _event)) return true;
		if (variable_struct_exists(self, _event)) {
			__snowstate_error("Can not use \"", _event, "\" as an event.");
			return false;
		}
			
		return true;
	};
	
	/// @param {string} state_name
	/// @param {bool} [show_error]
	/// @returns {bool} Whether the name is valid (true), or not (false)
	__assert_state_name_valid = function(_state, _error = true) {
		var _func = __snowstate_error;
		if (!_error) {
			_func = SNOWSTATE_DEBUG_WARNING ? __snowstate_trace : undefined;
		}
				
		if (!is_string(_state) || (_state == "")) {
			if (_func != undefined) _func("State name should be a non-empty string.");
			return false;
		}
				
		var _name, _i;
		_i = 0; repeat (array_length(__invalidStateNames)) {
			_name = __invalidStateNames[_i]; ++_i;
			if (_state == _name) {
				if (_func != undefined) _func("State name can not be \"", _name, "\".");
				return false;
			}
		}
				
		return true;
	};
	
	/// @param {string} transition_name
	/// @param {bool} [show_error]
	/// @returns {bool} Whether the name is valid (true), or not (false)
	__assert_transition_name_valid = function(_state, _error = true) {
		var _func = __snowstate_error;
		if (!_error) {
			_func = SNOWSTATE_DEBUG_WARNING ? __snowstate_trace : undefined;
		}
				
		if (!is_string(_state) || (_state == "")) {
			if (_func != undefined) _func("Transition name should be a non-empty string.");
			return false;
		}
				
		return true;
	};
	
	/// @param {string} event
	/// @param {array<any>} [args]
	/// @returns {SnowState} self
	__broadcast_event = function(_event, _args) {
		var _func = __on_events[$ _event];
		if (_func != undefined) __func_exec(_func, _args);
		
		return self;
	};
	
	/// @param {string} state_name
	/// @param {function} leave_func
	/// @param {function} enter_func
	/// @param {struct} [data]
	/// @returns {SnowState} self
	__change = function(_state, _leave, _enter, _data) {
		var _defLeave, _defEnter;
		_defLeave = leave;
		_defEnter = enter;
		leave = _leave;
		enter = _enter;
			
		// Leave current state
		if (leave == undefined) leave = _defLeave;
			else __tempEvent = _defLeave;
		leave(_data);
				
		// Add to history
		if (array_length(__childQueue) > 0) {
			__history[@ 0] = __childQueue[0];
			__childQueue = [];
		}
				
		// Init state
		__stateStartTime = get_timer();
		__history_add(_state);
				
		// Enter next state
		if (enter == undefined) enter = _defEnter;
			else __tempEvent = _defEnter;
		enter(_data);
				
		// Reset temp variable
		__tempEvent = undefined;
			
		leave = _defLeave;
		enter = _defEnter;
		
		return self;
	};
		
	/// @param {struct} state_struct
	/// @return {struct} Struct filled with all possible events
	__create_events_struct = function(_struct) {
		var _events = {};
		var _arr, _i, _event, _defEvent;
			
		_arr = variable_struct_get_names(_struct);
		_i = 0; repeat(array_length(_arr)) {
			_event = _arr[_i];
			__assert_event_name_valid(_event);
			__assert_event_available(_event);
			_events[$ _event] = {
				exists: SNOWSTATE_EVENT.DEFINED,
				func: method(__owner, _struct[$ _event])
			};
			++_i;
		}
		
		_arr = variable_struct_get_names(__defaultEvents);
		_i = 0; repeat(array_length(_arr)) {
			_event = _arr[_i];
			_defEvent = __defaultEvents[$ _event];
			if (!variable_struct_exists(_struct, _event)) {
				_events[$ _event] = {
					exists: _defEvent.exists,
					func: method(__owner, _defEvent.func)
				};
			}
			++_i;
		}
		
		return _events;
	};
		
	/// @param {string} event
	/// @param {string} [state_name]
	/// @param {array} [args]
	/// @returns {SnowState} self
	__execute = function(_event, _state = undefined, _args = undefined) {
		if (_state == undefined) _state = __history[0];
		
		if (!__is_state_defined(_state)) {
			__snowstate_error("State \"", _state, "\" is not defined.");
			return undefined;
		}
				
		__currEvent = _event;
		var _func = __states[$ _state][$ _event].func;
		var _pyramid = __func_exec;
		with (__owner) _pyramid(_func, _args);
			
		return self;
	};
	
	/// @param {function} function
	/// @param {array<any>} [args=undefined]
	/// @returns {any} Return value of function
	__func_exec = function(_func, _args = undefined) {
		if (_args == undefined) return _func();
		if (!is_array(_args)) return _func(_args);
		
		switch (array_length(_args)) {
			case  0: return _func();
			case  1: return _func(_args[0]);
			case  2: return _func(_args[0], _args[1]);
			case  3: return _func(_args[0], _args[1], _args[2]);
			case  4: return _func(_args[0], _args[1], _args[2], _args[3]);
			case  5: return _func(_args[0], _args[1], _args[2], _args[3], _args[4]);
			case  6: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5]);
			case  7: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6]);
			case  8: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7]);
			case  9: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8]);
			case 10: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9]);
			case 11: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10]);
			case 12: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10], _args[11]);
			case 13: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10], _args[11], _args[12]);
			case 14: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10], _args[11], _args[12], _args[13]);
			case 15: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10], _args[11], _args[12], _args[13], _args[14]);
			case 16: return _func(_args[0], _args[1], _args[2], _args[3], _args[4], _args[5], _args[6], _args[7], _args[8], _args[9], _args[10], _args[11], _args[12], _args[13], _args[14], _args[15]);
			default: __snowstate_error("Can't use more than 16 arguments."); break;
		}
		
		return undefined;
	};

	/// @returns {string} The current state
	__get_current_state = function() {
		var _state = ((array_length(__history) > 0) ? __history[0] : undefined);
		if (array_length(__childQueue) > 0) _state = __childQueue[0];
		return _state;
	};
		
	/// @param {string} state
	/// @returns {SnowState} self
	__history_add = function(_state) {
		if (__historyEnabled) {
			if (__history[1] == undefined) {
				__history[@ 1] = __history[0];
				__history[@ 0] = _state;
			} else {
				array_insert(__history, 0, _state);
				__history_fit_contents();
			}
		} else {
			__history[@ 1] = __history[0];
			__history[@ 0] = _state;
		}
		
		return self;
	};
		
	/// @returns {SnowState} self
	__history_fit_contents = function() {
		array_resize(__history, max(2, min(__historyMaxSize, array_length(__history))));
		return self;
	};
		
	/// @returns {bool} Whether the argument is a method or a function (true), or not (false)
	__is_really_a_method = function(_method) {
		try {
			return is_method(method(undefined, _method));
		} catch (_e) {
			return false;	
		}
	};
		
	/// @param {string} state_name
	/// @return {bool} Whether the state is defined (true), or not (false)
	__is_state_defined = function(_state) {
		return (is_string(_state) && variable_struct_exists(__states, _state));
	};
		
	/// @param {string} event
	/// @param {function} method
	/// @param {int} defined
	/// @returns {SnowState} self
	__set_default_event = function(_event, _method, _defined) {
		__defaultEvents[$ _event] = {
			exists: _defined,
			func: _method
		};
		__add_event_method(_event);
		
		return self;
	};
		
	/// @param {any} [args]
	/// @returns {SnowState} self
	__snowstate_error = function() {
		var _str = "[SnowState]\n";
		var _i = 0; repeat(argument_count) {
			_str += string(argument[_i++]);	
		}
		_str += "\n\n\n";
		show_error(_str, true);
		return self;
	};
		
	/// @param {any} [args]
	/// @returns {SnowState} self
	__snowstate_trace = function() {
		var _str = "[SnowState] ";
		var _i = 0; repeat(argument_count) {
			_str += string(argument[_i++]);	
		}
		show_debug_message(_str);
		return self;
	};
		
	/// @param {string} transition_name
	/// @param {string} from_state
	/// @returns {int} SNOWSTATE_TRIGGER
	__transition_exists = function(_transitionName, _from) {
		if (_from == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
			// Wildcard transition
			if (variable_struct_exists(__wildTransitions, _transitionName)) {
				return SNOWSTATE_TRIGGER.DEFINED;
			}
		} else {
			// Default	
			if (variable_struct_exists(__transitions, _from) && variable_struct_exists(__transitions[$ _from], _transitionName)) {
				return SNOWSTATE_TRIGGER.DEFINED;
			}
			while (variable_struct_exists(__parent, _from)) {
				_from = __parent[$ _from];
				if (variable_struct_exists(__transitions, _from) && variable_struct_exists(__transitions[$ _from], _transitionName)) {
					return SNOWSTATE_TRIGGER.INHERITED;
				}
			}
		}
				
		return SNOWSTATE_TRIGGER.NOT_DEFINED;
	};
	
	/// @param {string} transition_name
	/// @param {struct} [data]
	/// @returns {bool} Whether the transition has been triggered (true), or not (false)
	__trigger = function(_transitionName, _data) {
		if (!__assert_transition_name_valid(_transitionName)) return false;
			
		var _currState, _source;
		_currState = __get_current_state();
		_source    = _currState;
			
		// My triggers
		if (__transition_exists(_transitionName, _source) == SNOWSTATE_TRIGGER.DEFINED) {
			if (__try_triggers(__transitions[$ _source][$ _transitionName], _currState, _transitionName, _data)) return true;
		}
				
		// Wild triggers
		if (__transition_exists(_transitionName, SNOWSTATE_WILDCARD_TRANSITION_NAME) == SNOWSTATE_TRIGGER.DEFINED) {
			if (__try_triggers(__wildTransitions[$ _transitionName], _currState, _transitionName, _data)) return true;
		}
			
		// Parent triggers
		while (variable_struct_exists(__parent, _source)) {
			_source = __parent[$ _source];
			if (__transition_exists(_transitionName, _source) == SNOWSTATE_TRIGGER.DEFINED) {
				if (__try_triggers(__transitions[$ _source][$ _transitionName], _currState, _transitionName, _data)) return true;
			}
		}
			
		return false;
	};
	
	/// @param {array} transitions
	/// @param {string} source_state
	/// @param {string} trigger_name
	/// @param {struct} [data]
	/// @returns {bool} Whether the trigger is successful (true), or not (false)
	__try_triggers = function(_transitions, _source, _trigger, _data) {
		var _transition, _dest, _i;
		_i = 0; repeat(array_length(_transitions)) {
			_transition = _transitions[_i]; ++_i;
					
			// For reflexive wildcard transitions, change to source
			_dest = _transition.to;
			if (_dest == SNOWSTATE_REFLEXIVE_TRANSITION_NAME) _dest = _source;
					
			// Check condition
			if (_transition.condition(_data)) {
				__change(_dest, _transition.leave, _transition.enter, _data);
				__broadcast_event("state changed", [_dest, _source, _trigger]);
				return true;
			}
		}
					
		return false;
	};
		
	/// @param {string} state_name
	/// @returns {SnowState} self
	__update_events_from_parent = function(_name) {
		var _parent, _state, _events, _event, _exists, _parEvent, _i;
			
		_parent = __states[$ __parent[$ _name]];
		_state  = __states[$ _name];
				
		_events = variable_struct_get_names(_parent);
		_i = 0; repeat (array_length(_events)) {
			_event = _events[_i];
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
			
		return self;
	};
		
	/// @param {bool} has_parent
	/// @returns {SnowState} self
	__update_states = function(_hasParent) {
		var _states, _events, _state, _event, _defEvent, _i, _j;
		_states = variable_struct_get_names(__states);
		_events = variable_struct_get_names(__defaultEvents);
		
		_i = 0; repeat(array_length(_states)) {
			_state = __states[$ _states[_i]];
			_j = 0; repeat(array_length(_events)) {
				_event = _events[_j];
				if (!variable_struct_exists(_state, _event)) {
					_defEvent = __defaultEvents[$ _event];
					_state[$ _event] = {
						exists: _defEvent.exists,
						func: method(__owner, _defEvent.func)
					};
				}
				++_j;
			}
			++_i;
		}
		
		return self;
	};

	#endregion
	
	#region Basics
	
	/// @param {string} state_name
	/// @param {struct} [state_struct]
	/// @returns {SnowState} self
	add = function(_name, _struct = {}) {
		if (!__assert_state_name_valid(_name)) return undefined;
	
		if (!is_struct(_struct)) {
			__snowstate_error("State struct should be a struct.");
			return undefined;
		}
	
		if (SNOWSTATE_DEBUG_WARNING && __is_state_defined(_name)) {
			__snowstate_trace("State \"", _name, "\" has been defined already. Replacing the previous definition.");
		}
			
		__add(_name, _struct, false);
		
		return self;
	};

	/// @param {string} state_name
	/// @param {function} [leave_func=undefined]
	/// @param {function} [enter_func=undefined]
	/// @param {struct} [data=undefined]
	/// @returns {SnowState} self
	change = function(_state, _leave = undefined, _enter = undefined, _data = undefined) {
		if ((_leave != undefined) && !__is_really_a_method(_leave)) {
			__snowstate_error("Invalid value for \"leave_func\" in change(). Should be a function.");
			return undefined;
		}
		
		if ((_enter != undefined) && !__is_really_a_method(_enter)) {
			__snowstate_error("Invalid value for \"enter_func\" in change(). Should be a function.");
			return undefined;
		}
		
		var _source = get_current_state();
		__change(_state, _leave, _enter, _data);
		__broadcast_event("state changed", [_state, _source]);
		
		return self;
	};

	/// @param {string} state_name
	/// @param {string} [state_to_check]
	/// @returns {bool} Whether state_name is state_to_check or a parent of state_to_check (true), or not (false)
	state_is = function(_target, _source = get_current_state()) {
		var _state = _source;
		
		if (!__assert_state_name_valid(_target)) return false;
		if (!__assert_state_name_valid(_source)) return false;
		
		while (_state != undefined) {
			if (_state == _target) return true;
			_state = variable_struct_exists(__parent, _state) ? __parent[$ _state] : undefined;
		}
		
		return false;
	};
	
	/// @param {string} state_name
	/// @returns {bool} Whether state_name exists (true), or not (false)
	state_exists = function(_state) {
		return variable_struct_exists(__states, _state);
	};
	
	/// @returns {array} Array containing the states defined
	get_states = function() {
		return variable_struct_get_names(__states);	
	};
	
	/// @returns {string} The current state
	get_current_state = function() {
		return __get_current_state();
	};
	
	/// @returns {string} The previous state
	get_previous_state = function() {
		return ((array_length(__history) > 1) ? __history[1] : undefined);
	};
	
	/// @param {bool} [in_microseconds]
	/// @returns {number} Number of microseconds (or steps) the current state has been running for
	get_time = function(_us = true) {
		var _time = (get_timer()-__stateStartTime);
		return (_us ? _time : (_time * game_get_speed(gamespeed_fps) * 1/1000000));
	};
	
	/// @param {number} time
	/// @param {bool} [in_microseconds]
	/// @returns {SnowState} self
	set_time = function(_time, _us = true) {
		if (!is_real(_time)) {
			__snowstate_error("Time should be a number");
			return undefined;
		}
		
		__stateStartTime = get_timer() - (_us ? _time : (_time * 1/game_get_speed(gamespeed_fps) * 1000000));
		
		return self;
	};
	
	/// @param {string} event
	/// @param {string} callback
	/// @param {struct} [context=noone]
	/// @returns {SnowState} self
	on = function(_event, _callback, _context = noone) {
		if (!is_string(_event)) {
			__snowstate_error("Event name should be a string.");
			return undefined;
		}
		
		if (!__is_really_a_method(_callback)) {
			__snowstate_error("Callback should be a string.");
			return undefined;
		}
		
		if (variable_struct_exists(__on_events, _event)) {
			if (_context != noone) _callback = method(_context, _callback);
			__on_events[$ _event] = _callback;
		} else if (SNOWSTATE_DEBUG_WARNING) {
			__snowstate_trace("Event \"", _event, "\" does not exist.");
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
		if (!__assert_state_name_valid(_name)) return undefined;
		if (!__assert_state_name_valid(_parent)) return undefined;
			
		if (!__is_state_defined(_parent)) {
			__snowstate_error("State \"", _parent, "\" is not defined.");
			return undefined;
		}
				
		if (_parent == _name) {
			__snowstate_error("Cannot set a state as a parent to itself.");
			return undefined;
		}
	
		if (!is_struct(_struct)) {
			__snowstate_error("State struct should be a struct.");
			return undefined;
		}
			
		if (SNOWSTATE_DEBUG_WARNING) {
			if (__is_state_defined(_name)) {
				__snowstate_trace("State \"", _name, "\" has been defined already. The previous definition has been replaced.");
			}
				
			if (variable_struct_exists(__parent, _name)) {
				if (__parent[$ _name] == _parent) {
					__snowstate_trace("State \"", _name, "\" is already a child of \"", _parent, "\".");
				}
			}
		}
			
		__parent[$ _name] = _parent;
		__add(_name, _struct, true);
		
		return self;		
	};
	
	/// @returns {SnowState} self
	inherit = function() {
		var _state = __history[0];
			
		if (!variable_struct_exists(__parent, _state)) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("State \"", _state, "\" has no parent state.");
			}
			return self;
		}
			
		if (SNOWSTATE_CIRCULAR_INHERITANCE_ERROR) {
			var _str, _len, _i;
			_len = array_length(__childQueue);
			_str = "";
			_i = 0; repeat (_len) {
				if (__childQueue[_i] == _state) break;
				++_i;
			}
				
			if (_i < _len) {
				_str += string(_state);
				repeat (_len-_i-1) {
					++_i;
					_str += " -> " + string(__childQueue[_i]);
				}
				_str += " -> " + string(_state);
				__snowstate_error("Circular inheritance found. Inheritance chain: ",
								"(-> reads as \"inherits from\")\n", _str);
				return undefined;
			}
		}
			
		array_push(__childQueue, _state);
		_state = __parent[$ _state];
		__history[@ 0] = _state;
		__execute(__currEvent);
		if (array_length(__childQueue) > 0) __history[@ 0] = array_pop(__childQueue);
		
		return self;
	};
	
	#endregion
	
	#region Events
	
	/// @param {string} event
	/// @param {function} function
	/// @returns {SnowState} self
	event_set_default_function = function(_event, _function) {
		if (SNOWSTATE_DEBUG_WARNING && (variable_struct_names_count(__states) > 0)) {
			__snowstate_trace("event_set_default_function() should be called before defining any state.");
		}
		
		if (!is_string(_event) || (_event == "")) {
			__snowstate_error("Event should be a non-empty string.");
			return undefined;
		}
		
		if (!__is_really_a_method(_function)) {
			__snowstate_error("Default function should be a function.");
			return undefined;
		}
		
		__assert_event_name_valid(_event);
		__set_default_event(_event, method(__owner, _function), SNOWSTATE_EVENT.DEFAULT);
		__update_states();
		
		return self;
	};
	
	/// NOTE: This function is only meant to be used in change()
	/// @returns {function}
	event_get_current_function = function() {
		return __tempEvent;
	}
	
	/// @param {string} event
	/// @returns {int} SNOWSTATE_EVENT
	event_exists = function(_event) {
		if (!is_string(_event) || (_event == "")) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("Event should be a non-empty string.");
			}
			return SNOWSTATE_EVENT.NOT_DEFINED;
		}
			
		var _state = __get_current_state();
		if (!variable_struct_exists(__states[$ _state], _event)) return SNOWSTATE_EVENT.NOT_DEFINED;
		return __states[$ _state][$ _event].exists;
	};

	/// @param {struct} [data]
	/// @returns {SnowState} self
	enter = function(_data = undefined) {
		__execute("enter", undefined, _data);
		return self;
	};
	
	/// @param {struct} [data]
	/// @returns {SnowState} self
	leave = function(_data = undefined) {
		__execute("leave", undefined, _data);
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
		if (!__assert_transition_name_valid(_transitionName)) return undefined;
		if (!is_string(_dest) || (_dest == "")) {
			__snowstate_error("State name should be a non-empty string.");
			return undefined;
		}
		if (_dest == SNOWSTATE_WILDCARD_TRANSITION_NAME) {
			__snowstate_error("Destination state name can not be the same as SNOWSTATE_WILDCARD_TRANSITION_NAME.");
			return undefined;
		}
			
		if (!__is_really_a_method(_condition)) {
			__snowstate_error("Invalid value for \"condition\" in add_transition(). Should be a function.");
			return undefined;
		}
		if (!__is_really_a_method(_leave)) {
			__snowstate_error("Invalid value for \"leave_func\" in add_transition(). Should be a function.");
			return undefined;
		}
		if (!__is_really_a_method(_enter)) {
			__snowstate_error("Invalid value for \"enter_func\" in add_transition(). Should be a function.");
			return undefined;
		}
			
		if (!is_array(_source)) _source = [_source];
			
		var _i, _from;
		_i = 0; repeat (array_length(_source)) {
			_from = _source[_i]; ++_i;
			if (!is_string(_from) || (_from == "")) {
				if (SNOWSTATE_DEBUG_WARNING) {
					__snowstate_trace("State name should be a non-empty string. Transition not added.");	
				}
			} else if (_from == SNOWSTATE_REFLEXIVE_TRANSITION_NAME) {
				if (SNOWSTATE_DEBUG_WARNING) {
					__snowstate_trace("Source state name can not be the same as SNOWSTATE_REFLEXIVE_TRANSITION_NAME. Transition not added.");	
				}
			} else {
				__add_transition(_transitionName, _from, _dest, _condition, _leave, _enter);
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
	add_wildcard_transition = function(_transitionName, _dest, _condition = function() { return true; }, _leave = undefined, _enter = undefined) {
		return add_transition(_transitionName, SNOWSTATE_WILDCARD_TRANSITION_NAME, _dest, _condition, _leave, _enter);
	};
	
	/// @param {string} transition_name
	/// @param {string/array} source_state
	/// @param {function} [condition]
	/// @param {function} [leave_func]
	/// @param {function} [enter_func]
	/// @returns {SnowState} self
	add_reflexive_transition = function(_transitionName, _source, _condition = function() { return true; }, _leave = undefined, _enter = undefined) {
		return add_transition(_transitionName, _source, SNOWSTATE_REFLEXIVE_TRANSITION_NAME, _condition, _leave, _enter);
	};
	
	/// @param {string} transition_name
	/// @param {string} source_state
	/// @returns {int} SNOWSTATE_TRIGGER
	transition_exists = function(_transitionName, _source) {
		if (!is_string(_transitionName)) return false;
		if (!is_string(_source)) return false;
		if (_source == SNOWSTATE_WILDCARD_TRANSITION_NAME) return true;
		
		if (!__assert_transition_name_valid(_transitionName, false)) return false;
			
		return __transition_exists(_transitionName, _source);
	};
	
	/// @param {string|array} transition_name
	/// @param {struct} [data=undefined]
	/// @returns {bool} Whether a transition has been triggered (true), or not (false)
	trigger = function(_transition, _data = undefined) {
		if (is_array(_transition)) {
			var _i = 0; repeat (array_length(_transition)) {
				if (__trigger(_transition[_i], _data)) return true;
				++_i;
			}
			return false;
		} else {
			return __trigger(_transition, _data);
		}
	}

	#endregion
	
	#region History
	
	/// @returns {SnowState} self
	history_enable = function() {
		if (!__historyEnabled) {
			__historyEnabled = true;
			__history_fit_contents();
		}
		
		return self;
	};
	
	/// @returns {SnowState} self
	history_disable = function() {
		if (__historyEnabled) {
			__historyEnabled = false;
			array_resize(__history, 2);
		}
		
		return self;
	};
	
	/// @returns {bool} Whether state history is enabled (true), or not (false)
	history_is_enabled = function() {
		return __historyEnabled;
	};
	
	/// @param {int} size
	/// @returns {SnowState} self
	history_set_max_size = function(_size) {
		if (!is_real(_size)) {
			__snowstate_error("Size should be a number.");
			return undefined;
		}
		if (_size < 0) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("History size should non-negative. Setting the size to 0 instead of ", _size, ".");
			}
			_size = 0;
		}
		__historyMaxSize = _size;
		__history_fit_contents();
		
		return self;
	};
	
	/// @returns {int} The maximum storage capacity of state history
	history_get_max_size = function() {
		return __historyMaxSize;
	};
	
	/// @returns {array} Array containing the state history
	history_get = function() {
		if (!__historyEnabled) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("History is disabled, can not get_history().");	
			}
			return [];
		}
		if (get_previous_state() == undefined) return [__get_current_state()];
		var _len = min(array_length(__history), __historyMaxSize);
		var _arr = array_create(_len);
		array_copy(_arr, 0, __history, 0, _len);
		_arr[@ 0] = __get_current_state();
		return _arr;
	};
	
	#endregion
	
	// Initialization
	__assert_state_name_valid(_initState);
	__history_add(_initState);
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
#macro SNOWSTATE_VERSION "v3.1.4"
#macro SNOWSTATE_DATE "26-10-2022"

show_debug_message("[SnowState] You are using SnowState by @sohomsahaun (Version: " + string(SNOWSTATE_VERSION) + " | Date: " + string(SNOWSTATE_DATE) + ")");
