/// @desc A finite state machine
/// @param {String} _initial_state Initial state name
/// @param {Bool} [_exec_initial_enter] Whether to fire the initial enter
/// @returns {Struct.SnowState}
function SnowState(_initial_state, _exec_initial_enter = true) constructor {
	#region Constants

	static EV_STATE_CHANGE = variable_get_hash("state_change");

	static CHANGE_KIND_CHANGE = "change";
	static CHANGE_KIND_PUSH = "push";
	static CHANGE_KIND_POP = "pop";

	static ENTER_HASH = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? SNOWSTATE_EVENT_ENTER : string(SNOWSTATE_EVENT_ENTER));
	static STEP_HASH = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? SNOWSTATE_EVENT_STEP : string(SNOWSTATE_EVENT_STEP));
	static EXIT_HASH = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? SNOWSTATE_EVENT_EXIT : string(SNOWSTATE_EVENT_EXIT));
	static SUSPEND_HASH = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? SNOWSTATE_EVENT_SUSPEND : string(SNOWSTATE_EVENT_SUSPEND));
	static RESUME_HASH = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? SNOWSTATE_EVENT_RESUME : string(SNOWSTATE_EVENT_RESUME));

	#endregion

	#region Setup

	if (SNOWSTATE_VERIFY_USER_ARGS) {
		self.__assert_name(_initial_state, "SnowState", "_initial_state");
		self.__assert_bool(_exec_initial_enter, "SnowState", "_exec_initial_enter");
		_exec_initial_enter = bool(_exec_initial_enter);
	}

	self.initial_state_name = _initial_state;
	self.initial_state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _initial_state : string(_initial_state));
	self.current_state_name = _initial_state;
	self.exec_initial_enter = _exec_initial_enter;
	self.initial_enter_done = false;

	self.previous_state_name = undefined;
	self.current_state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? self.current_state_name : string(self.current_state_name));
	self.state_timer_in_steps = 0;
	self.state_version = 0;

	self.suspended_stack_frames = undefined;
	self.active_stack_frame_depth = 0;

	self.states = {};
	self.state_name_by_hash = {};
	self.registered_state_hashes = [];
	self.registered_event_hashes = [];

	self.default_events = undefined;

	self.transitions = {};

	self.resolution_enabled = false;
	self.parent_state_name_hash = undefined;
	self.inheritance_tree = undefined;
	self.state_hash_to_inheritance_tree_node = undefined;
	self.current_resolved_event = undefined;
	self.current_event_args = undefined;

	self.history_enabled = false;
	self.history_max_size = max(0, floor(SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE));
	self.history = [];

	self.broadcast_events = {};

	array_push(self.registered_event_hashes, self.ENTER_HASH, self.STEP_HASH, self.EXIT_HASH, self.SUSPEND_HASH, self.RESUME_HASH);

	#endregion

	#region Validation

	/// @desc Checks if _value is a boolean
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_bool = function(_value, _method_name, _param_name) {
		if (!is_bool(_value) && !is_numeric(_value)) {
			self.__snowstate_error($"{_method_name}() expects {_param_name} to be a boolean, got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is callable
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_callable = function(_value, _method_name, _param_name) {
		if (!is_callable(_value)) {
			self.__snowstate_error($"{_method_name}() expects {_param_name} to be a function, got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is callable or undefined
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_callable_or_undefined = function(_value, _method_name, _param_name) {
		if (!is_undefined(_value) && !is_callable(_value)) {
			self.__snowstate_error($"{_method_name}() expects {_param_name} to be a function or undefined, got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is a valid SnowState.Event
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_event = function(_value, _method_name, _param_name) {
		if (!is_struct(_value) || !is_instanceof(_value, self.Event)) {
			self.__snowstate_error($"{_method_name}() expects {_param_name} to be a SnowState.Event, got {typeof(_value)}.");
		} else if (!is_callable(_value.func)) {
			self.__snowstate_error($"{_method_name}() expects {_param_name}.func to be a function, got {typeof(_value.func)}.");
		} else {
			self.__assert_name(_value.name, _method_name, $"{_param_name}.name");
		}
		return self;
	};

	/// @desc Checks if _value is an array of valid SnowState.Events
	/// @ignore
	/// @param {Any} _value Value or array of values to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_event_list = function(_value, _method_name, _param_name) {
		var _len = array_length(_value);
		for (var _i = 0; _i < _len; ++_i) {
			self.__assert_event(_value[_i], _method_name, $"{_param_name}[{_i}]");
		}
		return self;
	};

	/// @desc Checks if _value is a hash
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_hash = function(_value, _method_name, _param_name) {
		if (!is_numeric(_value)) {
			self.__snowstate_error($"{_method_name} expects {_param_name} to be a hash (number), got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is a string when SNOWSTATE_ASSUME_STRING_NAMES
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_name = function(_value, _method_name, _param_name) {
		if (SNOWSTATE_ASSUME_STRING_NAMES && !is_string(_value)) {
			self.__snowstate_error($"{_method_name} expects {_param_name} to be a string (SNOWSTATE_ASSUME_STRING_NAMES is true), got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is a name or array of names
	/// @ignore
	/// @param {Any} _value Value or array of values to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_name_or_names = function(_value, _method_name, _param_name) {
		if (!is_array(_value)) {
			return self.__assert_name(_value, _method_name, _param_name);
		}
		var _len = array_length(_value);
		for (var _i = 0; _i < _len; ++_i) {
			self.__assert_name(_value[_i], _method_name, $"{_param_name}[{_i}]");
		}
		return self;
	};

	/// @desc Checks if _value is numeric
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_numeric = function(_value, _method_name, _param_name) {
		if (!is_numeric(_value)) {
			self.__snowstate_error($"{_method_name} expects {_param_name} to be a number, got {typeof(_value)}.");
		}
		return self;
	};

	/// @desc Checks if _value is a non-negative integer
	/// @ignore
	/// @param {Any} _value Value to validate
	/// @param {String} _method_name Calling method name
	/// @param {String} _param_name Parameter name
	/// @returns {Struct.SnowState}
	static __assert_size = function(_value, _method_name, _param_name) {
		if (is_numeric(_value)) {
			if ((_value < 0) || (_value != floor(_value))) {
				self.__snowstate_error($"{_method_name}() expects {_param_name} to be a non-negative integer, got {_value}.");
			}
		} else {
			self.__snowstate_error($"{_method_name}() expects {_param_name} to be a non-negative integer, got {typeof(_value)}.");
		}
		return self;
	};

	#endregion

	#region Utility

	/// @desc Throws an error
	/// @ignore
	/// @param {String} _message Error message
	static __snowstate_error = function(_message) {
		throw $"[SnowState] {_message}";
	};

	/// @desc Logs a message
	/// @ignore
	/// @param {String} _message Message to log
	/// @returns {Struct.SnowState}
	static __snowstate_trace = function(_message) {
		show_debug_message($"[SnowState] {_message}");
		return self;
	};

	#endregion

	#region Broadcast

	/// @desc Fires EV_STATE_CHANGE
	/// @ignore
	/// @param {String,Undefined} _transition_name Triggering transition, or undefined
	/// @param {String} _change_kind Change kind (CHANGE/PUSH/POP)
	/// @returns {Struct.SnowState}
	static __broadcast_state_change = function(_transition_name, _change_kind) {
		var _event = struct_get_from_hash(self.broadcast_events, self.EV_STATE_CHANGE);
		if (is_undefined(_event)) return self;

		var _state_change_payload = new self.StateChange(self.current_state_name, self.previous_state_name, _transition_name, _change_kind);
		_event(_state_change_payload);

		return self;
	};

	/// @desc Registers a broadcast event callback
	/// @param {Real} _broadcast_event_name_hash Broadcast event name hash
	/// @param {Function,Undefined} _callback Callback, or undefined to unregister
	/// @returns {Struct.SnowState}
	static on = function(_broadcast_event_name_hash, _callback) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_hash(_broadcast_event_name_hash, "on", "_broadcast_event_name_hash");
			self.__assert_callable_or_undefined(_callback, "on", "_callback");
		}

		struct_set_from_hash(self.broadcast_events, _broadcast_event_name_hash, _callback);
		return self;
	};

	#endregion

	#region State

	/// @desc Applies a state change
	/// @ignore
	/// @param {Any} _new_state_name State becoming current
	/// @param {Real} _new_state_name_hash Hash of _new_state_name
	/// @returns {Struct.SnowState}
	static __apply_state_change = function(_new_state_name, _new_state_name_hash) {
		self.previous_state_name = self.current_state_name;
		self.current_state_name = _new_state_name;
		self.current_state_name_hash = _new_state_name_hash;
		self.state_version += 1;
		if (self.history_enabled) {
			self.__history_push_current_state();
		}
		return self;
	};

	/// @desc Changes to a verified state
	/// @ignore
	/// @param {Any} _dest_state_name Destination state
	/// @param {Function,Undefined} _src_state_exit Source exit callback, or undefined
	/// @param {Function,Undefined} _dest_state_enter Destination enter callback, or undefined
	/// @param {Any} _data Data to pass to callbacks
	/// @returns {Bool} Whether the change was applied
	static __change_state = function(_dest_state_name, _src_state_exit, _dest_state_enter, _data) {
		if (SNOWSTATE_CHECK_NON_EXISTENT_STATE && !struct_exists(self.states, _dest_state_name)) {
			self.__snowstate_error($"State {_dest_state_name} not defined.");
			return false;
		}

		var _data_array = is_undefined(_data) ? undefined : [_data];

		var _previous_stack_frame_depth = self.active_stack_frame_depth;

		// exit current state
		self.active_stack_frame_depth = is_undefined(self.suspended_stack_frames) ? 0 : array_length(self.suspended_stack_frames);
		self.__invoke_resolved_event(self.current_state_name_hash, self.EXIT_HASH, _data_array, _src_state_exit, _data);

		// clear stack
		if (!is_undefined(self.suspended_stack_frames)) {
			for (var _i = array_length(self.suspended_stack_frames)-1; _i >= 0; --_i) {
				self.active_stack_frame_depth = _i;
				self.__invoke_resolved_event(self.suspended_stack_frames[_i].state_name_hash, self.EXIT_HASH, _data_array);
			}
			self.suspended_stack_frames = undefined;
		}

		// change state
		self.__apply_state_change(_dest_state_name, variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _dest_state_name : string(_dest_state_name)));

		// enter new state
		self.state_timer_in_steps = 0;
		self.active_stack_frame_depth = 0;
		self.__invoke_resolved_event(self.current_state_name_hash, self.ENTER_HASH, _data_array, _dest_state_enter, _data);

		self.active_stack_frame_depth = _previous_stack_frame_depth;

		return true;
	};

	/// @desc Fires initial state's enter
	/// @ignore
	/// @param {Any} _state_name State just added
	/// @returns {Struct.SnowState}
	static __try_exec_initial_enter = function(_state_name) {
		if (!self.exec_initial_enter) return self;
		if (self.initial_enter_done) return self;

		var _state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_name : string(_state_name));
		if (_state_name_hash != self.initial_state_name_hash) return self;

		self.initial_enter_done = true;

		self.__invoke_resolved_event(_state_name_hash, self.ENTER_HASH, undefined);

		return self;
	};

	/// @desc Adds a state
	/// @param {Any} _state_name State to add
	/// @param {Array<Struct.SnowState.Event>} [_event_or_events] Event or array of events
	/// @returns {Struct.SnowState}
	static add_state = function(_state_name, _event_or_events = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_state_name, "add_state", "_state_name");

			if (is_array(_event_or_events)) {
				self.__assert_event_list(_event_or_events, "add_state", "_event_or_events");
			} else if (!is_undefined(_event_or_events)) {
				for (var _i = 1; _i < argument_count; ++_i) {
					self.__assert_event(argument[_i], "add_state", $"argument {_i}");
				}
			}
		}

		if (SNOWSTATE_SHOW_WARNING && struct_exists(self.states, _state_name)) {
			self.__snowstate_trace($"State '{_state_name}' exists already, overwriting...");
		}

		// handle events
		var _events_map = {};
		if (is_array(_event_or_events)) {
			var _event_or_events_len = array_length(_event_or_events);
			for (var _i = 0; _i < _event_or_events_len; ++_i) {
				var _event = _event_or_events[_i];
				_events_map[$ _event.name] = _event.func;
				self.__register_event(_event.name);
			}
		} else if (!is_undefined(_event_or_events)) {
			for (var _i = 1; _i < argument_count; ++_i) {
				var _event = argument[_i];
				_events_map[$ _event.name] = _event.func;
				self.__register_event(_event.name);
			}
		}
		self.states[$ _state_name] = _events_map;

		// store the hash, and the original (un-stringified) name
		var _state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_name : string(_state_name));
		if (!struct_exists_from_hash(self.state_name_by_hash, _state_name_hash)) {
			array_push(self.registered_state_hashes, _state_name_hash);
		}
		struct_set_from_hash(self.state_name_by_hash, _state_name_hash, _state_name);

		// handle resolution
		if (self.resolution_enabled) {
			if (!struct_exists_from_hash(self.state_hash_to_inheritance_tree_node, _state_name_hash)) {
				struct_set_from_hash(self.state_hash_to_inheritance_tree_node, _state_name_hash, new self.InheritanceTreeNode(_state_name_hash));
			}
			self.__resolve_inheritance_subtree(_state_name_hash);
		}

		// initial enter
		self.__try_exec_initial_enter(_state_name);

		return self;
	};

	/// @desc Changes the current state
	/// @param {Any} _dest_state_name Destination state
	/// @param {Function} [_src_state_exit] Source exit callback, or undefined
	/// @param {Function} [_dest_state_enter] Destination enter callback, or undefined
	/// @param {Any} [_data] Data to pass to callbacks
	/// @returns {Struct.SnowState}
	static change_state = function(_dest_state_name, _src_state_exit = undefined, _dest_state_enter = undefined, _data = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_dest_state_name, "change_state", "_dest_state_name");
			self.__assert_callable_or_undefined(_src_state_exit, "change_state", "_src_state_exit");
			self.__assert_callable_or_undefined(_dest_state_enter, "change_state", "_dest_state_enter");
		}

		if (self.__change_state(_dest_state_name, _src_state_exit, _dest_state_enter, _data)) {
			self.__broadcast_state_change(undefined, self.CHANGE_KIND_CHANGE);
		}
		return self;
	};

	/// @desc Returns the current state name
	/// @returns {Any}
	static get_current_state_name = function() {
		return self.current_state_name;
	};

	/// @desc Returns the initial state name
	/// @returns {Any}
	static get_initial_state_name = function() {
		return self.initial_state_name;
	};

	/// @desc Returns the previous state name
	/// @returns {Any,Undefined}
	static get_previous_state_name = function() {
		return self.previous_state_name;
	};

	/// @desc Returns all registered state names
	/// @returns {Array<Any>} Fresh array, safe to modify
	static get_state_names = function() {
		var _len = array_length(self.registered_state_hashes);
		var _names = array_create(_len);
		for (var _i = 0; _i < _len; ++_i) {
			_names[_i] = struct_get_from_hash(self.state_name_by_hash, self.registered_state_hashes[_i]);
		}
		return _names;
	};

	/// @desc Returns the current state's step timer
	/// @returns {Real}
	static get_time = function() {
		return self.state_timer_in_steps;
	};

	/// @desc Sets the state timer
	/// @param {Real} _time Timer value in steps
	/// @returns {Struct.SnowState}
	static set_time = function(_time) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_numeric(_time, "set_time", "_time");
		}

		self.state_timer_in_steps = _time;
		return self;
	};

	/// @desc Checks if a state exists
	/// @param {Any} _state_name State name to look up
	/// @returns {Bool}
	static state_exists = function(_state_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_state_name, "state_exists", "_state_name");
		}

		return struct_exists(self.states, _state_name);
	};

	/// @desc Checks if a state matches the current or ancestor states
	/// @param {Any} _state_name State name to check
	/// @param {Any} [_state_to_check] State to check (defaults to current)
	/// @returns {Bool}
	static state_is = function(_state_name, _state_to_check = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_state_name, "state_is", "_state_name");
			if (!is_undefined(_state_to_check)) {
				self.__assert_name(_state_to_check, "state_is", "_state_to_check");
			}
		}

		var _state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_name : string(_state_name));

		_state_to_check = _state_to_check ?? self.get_current_state_name();
		var _state_to_check_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_to_check : string(_state_to_check));
		if (_state_to_check_hash == _state_name_hash) return true;

		if (self.resolution_enabled) {
			while (struct_exists_from_hash(self.parent_state_name_hash, _state_to_check_hash)) {
				_state_to_check_hash = struct_get_from_hash(self.parent_state_name_hash, _state_to_check_hash);
				if (_state_to_check_hash == _state_name_hash) return true;
			}
		}

		return false;
	};

	#endregion

	#region Events

	/// @desc Executes an event by hash
	/// @ignore
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Array<Any>,Undefined} _args Arguments to forward
	/// @returns {Struct.SnowState}
	static __execute_event_hashed = function(_event_name_hash, _args) {
		if (SNOWSTATE_CHECK_NON_EXISTENT_STATE && !struct_exists_from_hash(self.states, self.current_state_name_hash)) {
			self.__snowstate_error($"State {self.current_state_name} not defined.");
			return self;
		}

		var _state_version = self.state_version;
		var _previous_stack_frame_depth = self.active_stack_frame_depth;
		self.active_stack_frame_depth = is_undefined(self.suspended_stack_frames) ? 0 : array_length(self.suspended_stack_frames);

		self.__invoke_resolved_event(self.current_state_name_hash, _event_name_hash, _args);

		if ((_event_name_hash == self.STEP_HASH) && (self.state_version == _state_version)) {
			self.state_timer_in_steps += 1;
		}

		self.active_stack_frame_depth = _previous_stack_frame_depth;

		return self;
	};

	/// @desc Runs a state's event handler
	/// @ignore
	/// @param {Real} _state_name_hash State name hash
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Array<Any>,Undefined} [_args] Arguments to forward, or none
	/// @returns {Struct.SnowState}
	static __execute_state_event_by_hash = function(_state_name_hash, _event_name_hash, _args = undefined) {
		var _events = struct_get_from_hash(self.states, _state_name_hash);

		if (struct_exists_from_hash(_events, _event_name_hash)) {
			var _event = struct_get_from_hash(_events, _event_name_hash);
			if (is_undefined(_args)) {
				_event();
			} else {
				method_call(_event, _args);
			}
		}

		return self;
	};

	/// @desc Runs a resolved event on a state
	/// @ignore
	/// @param {Real} _state_name_hash State name hash
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Array<Any>,Undefined} _args_array Arguments to forward, or none
	/// @param {Function} [_override_func] Runs instead of the resolved handler
	/// @param {Any} [_override_arg] Single argument passed to _override_func
	/// @returns {Struct.SnowState}
	static __invoke_resolved_event = function(_state_name_hash, _event_name_hash, _args_array, _override_func = undefined, _override_arg = undefined) {
		if (!self.resolution_enabled) {
			// just do the thing
			if (!is_undefined(_override_func)) {
				_override_func(_override_arg);
			} else {
				self.__execute_state_event_by_hash(_state_name_hash, _event_name_hash, _args_array);
			}
			return self;
		}

		var _state_node = struct_get_from_hash(self.state_hash_to_inheritance_tree_node, _state_name_hash);
		var _resolved_event = struct_get_from_hash(_state_node.active_events, _event_name_hash);

		var _prev_resolved_event = self.current_resolved_event;
		var _prev_event_args = self.current_event_args;

		// set up inherit() context
		self.current_resolved_event = _resolved_event;
		self.current_event_args = _args_array;

		if (!is_undefined(_override_func)) {
			_override_func(_override_arg);
		} else if (!is_undefined(_resolved_event)) {
			if (is_undefined(_args_array)) {
				_resolved_event.func();
			} else {
				method_call(_resolved_event.func, _args_array);
			}
		}

		// revert inherit() context
		self.current_resolved_event = _prev_resolved_event;
		self.current_event_args = _prev_event_args;

		return self;
	};

	/// @desc Registers an event name
	/// @ignore
	/// @param {Any} _event_name Event name to register
	/// @returns {Struct.SnowState}
	static __register_event = function(_event_name) {
		var _event_name_hash = variable_get_hash(_event_name);
		if (!array_contains(self.registered_event_hashes, _event_name_hash)) {
			array_push(self.registered_event_hashes, _event_name_hash);
		}
		return self;
	};

	/// @desc Checks if an event exists
	/// @param {String} _event_name Event name to check
	/// @returns {Bool}
	static event_exists = function(_event_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_event_name, "event_exists", "_event_name");
		}

		if (!SNOWSTATE_ASSUME_STRING_NAMES) _event_name = string(_event_name);
		return array_contains(self.registered_event_hashes, variable_get_hash(_event_name));
	};

	/// @desc Sets an event's default function
	/// @param {String} _event_name Event name
	/// @param {Function} _function Default function to assign
	/// @returns {Struct.SnowState}
	static event_set_default_function = function(_event_name, _function) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_event_name, "event_set_default_function", "_event_name");
			self.__assert_callable(_function, "event_set_default_function", "_function");
		}

		if (!SNOWSTATE_ASSUME_STRING_NAMES) _event_name = string(_event_name);

		self.__enable_event_resolution();

		if (is_undefined(self.default_events)) {
			self.default_events = {};
		}
		struct_set(self.default_events, _event_name, new self.ResolvedEvent(_function, undefined, true));

		self.__register_event(_event_name);
		self.__resolve_all_states();

		return self;
	};

	/// @desc Executes a named event
	/// @param {String} _event_name Event to execute
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event = function(_event_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_event_name, "execute_event", "_event_name");
		}

		if (!SNOWSTATE_ASSUME_STRING_NAMES) {
			_event_name = string(_event_name);
		}

		var _args = undefined;
		if (argument_count > 1) {
			_args = array_create(argument_count-1);
			for (var _i = 1; _i < argument_count; ++_i) {
				_args[_i-1] = argument[_i];
			}
		}

		return self.__execute_event_hashed(variable_get_hash(_event_name), _args);
	};

	/// @desc Executes an event by precomputed hash
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event_by_hash = function(_event_name_hash) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_hash(_event_name_hash, "execute_event_by_hash", "_event_name_hash");
		}

		var _args = undefined;
		if (argument_count > 1) {
			_args = array_create(argument_count-1);
			for (var _i = 1; _i < argument_count; ++_i) {
				_args[_i-1] = argument[_i];
			}
		}

		return self.__execute_event_hashed(_event_name_hash, _args);
	};

	#endregion

	#region Stack

	/// @desc Dispatches an event to a stack frame
	/// @ignore
	/// @param {Real} _depth Frame depth from stack base
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Array<Any>,Undefined} _args Arguments to forward
	/// @returns {Struct.SnowState}
	static __execute_event_at_depth = function(_depth, _event_name_hash, _args) {
		var _top_depth = is_undefined(self.suspended_stack_frames) ? 0 : array_length(self.suspended_stack_frames);
		if ((_depth < 0) || (_depth > _top_depth)) return self;

		var _is_current = (_depth == _top_depth);
		var _state_hash = _is_current ? self.current_state_name_hash : self.suspended_stack_frames[_depth].state_name_hash;

		if (SNOWSTATE_CHECK_NON_EXISTENT_STATE && !struct_exists_from_hash(self.states, _state_hash)) {
			var _state_name = _is_current ? self.current_state_name : self.suspended_stack_frames[_depth].state_name;
			self.__snowstate_error($"State '{_state_name}' not defined.");
			return self;
		}

		var _previous_stack_frame_depth = self.active_stack_frame_depth;
		var _state_version = self.state_version;

		self.active_stack_frame_depth = _depth;
		self.__invoke_resolved_event(_state_hash, _event_name_hash, _args);

		if ((_event_name_hash == self.STEP_HASH) && (self.state_version == _state_version)) {
			if (_is_current) {
				self.state_timer_in_steps += 1;
			} else {
				self.suspended_stack_frames[_depth].state_timer_in_steps += 1;
			}
		}

		self.active_stack_frame_depth = _previous_stack_frame_depth;

		return self;
	};

	/// @desc Pushes a state
	/// @ignore
	/// @param {Any} _state_name State to push
	/// @param {Any} _data Data for suspend/enter handlers
	/// @param {String,Undefined} _transition_name Triggering transition, or undefined
	/// @returns {Struct.SnowState}
	static __push_state = function(_state_name, _data, _transition_name) {
		if (SNOWSTATE_CHECK_NON_EXISTENT_STATE && !struct_exists(self.states, _state_name)) {
			self.__snowstate_error($"State {_state_name} not defined.");
			return self;
		}

		var _data_array = is_undefined(_data) ? undefined : [_data];

		var _previous_stack_frame_depth = self.active_stack_frame_depth;

		// suspend current state
		self.active_stack_frame_depth = is_undefined(self.suspended_stack_frames) ? 0 : array_length(self.suspended_stack_frames);
		self.__invoke_resolved_event(self.current_state_name_hash, self.SUSPEND_HASH, _data_array);

		// push stack frame
		if (is_undefined(self.suspended_stack_frames)) {
			self.suspended_stack_frames = [];
		}
		array_push(self.suspended_stack_frames, new self.StackFrame(self.current_state_name, self.current_state_name_hash, self.state_timer_in_steps));

		// change state
		self.__apply_state_change(_state_name, variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_name : string(_state_name)));
		self.state_timer_in_steps = 0;

		// enter new state
		self.active_stack_frame_depth = array_length(self.suspended_stack_frames);
		self.__invoke_resolved_event(self.current_state_name_hash, self.ENTER_HASH, _data_array);

		self.active_stack_frame_depth = _previous_stack_frame_depth;

		self.__broadcast_state_change(_transition_name, self.CHANGE_KIND_PUSH);

		return self;
	};

	/// @desc Executes a named event on a stack frame
	/// @param {Real} _depth Frame depth from stack base
	/// @param {String} _event_name Event to execute
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event_at_depth = function(_depth, _event_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_numeric(_depth, "execute_event_at_depth", "_depth");
			self.__assert_name(_event_name, "execute_event_at_depth", "_event_name");
		}

		var _args = undefined;
		if (argument_count > 2) {
			_args = array_create(argument_count-2);
			for (var _i = 2; _i < argument_count; ++_i) {
				_args[_i-2] = argument[_i];
			}
		}

		return self.__execute_event_at_depth(_depth,
			variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _event_name : string(_event_name)),
			_args);
	};

	/// @desc Executes an event on a stack frame by hash
	/// @param {Real} _depth Frame depth from stack base
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event_at_depth_by_hash = function(_depth, _event_name_hash) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_numeric(_depth, "execute_event_at_depth_by_hash", "_depth");
			self.__assert_hash(_event_name_hash, "execute_event_at_depth_by_hash", "_event_name_hash");
		}

		var _args = undefined;
		if (argument_count > 2) {
			_args = array_create(argument_count-2);
			for (var _i = 2; _i < argument_count; ++_i) {
				_args[_i-2] = argument[_i];
			}
		}

		return self.__execute_event_at_depth(_depth, _event_name_hash, _args);
	};

	/// @desc Executes a named event on the frame below
	/// @param {String} _event_name Event to execute
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event_below = function(_event_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_event_name, "execute_event_below", "_event_name");
		}

		var _args = undefined;
		if (argument_count > 1) {
			_args = array_create(argument_count-1);
			for (var _i = 1; _i < argument_count; ++_i) {
				_args[_i-1] = argument[_i];
			}
		}

		return self.__execute_event_at_depth(
			self.active_stack_frame_depth-1,
			variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _event_name : string(_event_name)),
			_args
		);
	};

	/// @desc Executes an event on the frame below by hash
	/// @param {Real} _event_name_hash Event name hash
	/// @param {Any} [_args] Arguments to forward to handler
	/// @returns {Struct.SnowState}
	static execute_event_below_by_hash = function(_event_name_hash) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_hash(_event_name_hash, "execute_event_below_by_hash", "_event_name_hash");
		}

		var _args = undefined;
		if (argument_count > 1) {
			_args = array_create(argument_count-1);
			for (var _i = 1; _i < argument_count; ++_i) {
				_args[_i-1] = argument[_i];
			}
		}

		return self.__execute_event_at_depth(self.active_stack_frame_depth-1, _event_name_hash, _args);
	};

	/// @desc Returns the state stack
	/// @returns {Array<Any>} Fresh array, safe to modify
	static get_stack = function() {
		if (is_undefined(self.suspended_stack_frames)) return [self.current_state_name];

		var _len = array_length(self.suspended_stack_frames);
		var _names = array_create(_len+1);
		for (var _i = 0; _i < _len; ++_i) {
			_names[_i] = self.suspended_stack_frames[_i].state_name;
		}
		_names[_len] = self.current_state_name;

		return _names;
	};

	/// @desc Returns the stack depth
	/// @returns {Real}
	static get_stack_depth = function() {
		return is_undefined(self.suspended_stack_frames) ? 1 : (array_length(self.suspended_stack_frames) + 1);
	};

	/// @desc Pops the state stack
	/// @param {Any} [_data] Data for exit/resume handlers
	/// @returns {Struct.SnowState}
	static pop_state = function(_data = undefined) {
		if (is_undefined(self.suspended_stack_frames) || (array_length(self.suspended_stack_frames) == 0)) {
			if (SNOWSTATE_SHOW_WARNING) self.__snowstate_trace($"Cannot pop state '{self.current_state_name}', the stack is already flat.");
			return self;
		}

		var _data_array = is_undefined(_data) ? undefined : [_data];

		var _previous_stack_frame_depth = self.active_stack_frame_depth;

		// exit current state
		self.active_stack_frame_depth = array_length(self.suspended_stack_frames);
		self.__invoke_resolved_event(self.current_state_name_hash, self.EXIT_HASH, _data_array);

		// pop stack frame
		var _frame = array_pop(self.suspended_stack_frames);
		if (array_length(self.suspended_stack_frames) == 0) {
			self.suspended_stack_frames = undefined;
		}

		// change state
		self.__apply_state_change(_frame.state_name, _frame.state_name_hash);
		self.state_timer_in_steps = _frame.state_timer_in_steps;

		// resume previous state
		self.active_stack_frame_depth = is_undefined(self.suspended_stack_frames) ? 0 : array_length(self.suspended_stack_frames);
		self.__invoke_resolved_event(self.current_state_name_hash, self.RESUME_HASH, _data_array);

		self.active_stack_frame_depth = _previous_stack_frame_depth;

		self.__broadcast_state_change(undefined, self.CHANGE_KIND_POP);

		return self;
	};

	/// @desc Pushes a state onto the stack
	/// @param {Any} _state_name State to push
	/// @param {Any} [_data] Data for suspend/enter handlers
	/// @returns {Struct.SnowState}
	static push_state = function(_state_name, _data = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_state_name, "push_state", "_state_name");
		}

		return self.__push_state(_state_name, _data, undefined);
	};

	#endregion

	#region Inheritance

	/// @desc Checks for circular inheritance
	/// @ignore
	/// @param {Any} _src_state_name Child state being (re)parented
	/// @param {Any} _parent_state_name Proposed parent state
	/// @returns {Struct.SnowState}
	static __assert_non_circular_inheritance = function(_src_state_name, _parent_state_name) {
		var _src_state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _src_state_name : string(_src_state_name));
		var _current_state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _parent_state_name : string(_parent_state_name));
		while (true) {
			if (_current_state_name_hash == _src_state_name_hash) {
				self.__snowstate_error($"Circular inheritance found for '{_src_state_name}'.");
			}
			if (!struct_exists_from_hash(self.parent_state_name_hash, _current_state_name_hash)) break;
			_current_state_name_hash = struct_get_from_hash(self.parent_state_name_hash, _current_state_name_hash);
		}
		return self;
	};

	/// @desc Enables event resolution
	/// @ignore
	/// @returns {Struct.SnowState}
	static __enable_event_resolution = function() {
		if (self.resolution_enabled) return self;

		self.resolution_enabled = true;
		self.inheritance_tree = {};
		self.state_hash_to_inheritance_tree_node = {};
		self.parent_state_name_hash = {};
		var _existing_names = struct_get_names(self.states);
		for (var _i = 0; _i < array_length(_existing_names); ++_i) {
			var _existing_hash = variable_get_hash(_existing_names[_i]);
			struct_set_from_hash(self.state_hash_to_inheritance_tree_node, _existing_hash,
				new self.InheritanceTreeNode(_existing_hash));
		}

		return self.__resolve_all_states();
	};

	/// @desc Resolves all states
	/// @ignore
	/// @returns {Struct.SnowState}
	static __resolve_all_states = function() {
		var _names = struct_get_names(self.states);
		var _names_len = array_length(_names);

		for (var _i = 0; _i < _names_len; ++_i) {
			var _hash = variable_get_hash(_names[_i]);
			if (struct_exists_from_hash(self.parent_state_name_hash, _hash)) {
				// not a root
				continue;
			}
			self.__resolve_inheritance_subtree(_hash);
		}

		return self;
	};

	/// @desc Resolves a state's inheritance subtree
	/// @ignore
	/// @param {Real} _state_hash State hash to resolve
	static __resolve_inheritance_subtree = function(_state_hash) {
		var _node = struct_get_from_hash(self.state_hash_to_inheritance_tree_node, _state_hash);
		var _state_events = struct_get_from_hash(self.states, _state_hash);
		var _active_events = {};

		var _parent_hash = struct_get_from_hash(self.parent_state_name_hash, _state_hash);
		var _parent_events = undefined;
		if (!is_undefined(_parent_hash)) {
			var _parent_node = struct_get_from_hash(self.state_hash_to_inheritance_tree_node, _parent_hash);
			_parent_events = _parent_node.active_events;
		}

		var _reg_events_len = array_length(self.registered_event_hashes);
		for (var _i = 0; _i < _reg_events_len; ++_i) {
			var _ev_hash = self.registered_event_hashes[_i];

			var _inherited_event = is_undefined(_parent_events) ? undefined : struct_get_from_hash(_parent_events, _ev_hash);
			if (!is_undefined(_inherited_event) && _inherited_event.is_default) {
				// a default event is not part of inheritance, ignore
				_inherited_event = undefined;
			}

			var _own_event = struct_get_from_hash(_state_events, _ev_hash);
			if (!is_undefined(_own_event)) {
				// has own event
				struct_set_from_hash(_active_events, _ev_hash, new self.ResolvedEvent(_own_event, _inherited_event));
			} else if (!is_undefined(_inherited_event)) {
				// has parent event
				struct_set_from_hash(_active_events, _ev_hash, _inherited_event);
			} else if (!is_undefined(self.default_events)) {
				// if nothing is declared, check default
				var _default_event = struct_get_from_hash(self.default_events, _ev_hash);
				if (!is_undefined(_default_event)) {
					struct_set_from_hash(_active_events, _ev_hash, _default_event);
				}
			}
		}

		_node.active_events = _active_events;

		// resolve descendants
		if (struct_exists_from_hash(self.inheritance_tree, _state_hash)) {
			var _children = struct_get_from_hash(self.inheritance_tree, _state_hash);
			for (var _i = 0; _i < array_length(_children); ++_i) {
				self.__resolve_inheritance_subtree(_children[_i]);
			}
		}
	};

	/// @desc Adds a child state
	/// @param {Any} _parent_state_name Parent state to inherit from
	/// @param {Any} _state_name Child state to add
	/// @param {Array<Struct.SnowState.Event>} [_event_or_events] Event handlers, or none
	/// @returns {Struct.SnowState}
	static add_child_state = function(_parent_state_name, _state_name, _event_or_events = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_parent_state_name, "add_child_state", "_parent_state_name");
			self.__assert_name(_state_name, "add_child_state", "_state_name");
			if (is_array(_event_or_events)) {
				self.__assert_event_list(_event_or_events, "add_child_state", "_event_or_events");
			} else if (!is_undefined(_event_or_events)) {
				for (var _i = 1; _i < argument_count; ++_i) {
					self.__assert_event(argument[_i], "add_child_state", $"argument {_i}");
				}
			}
		}

		if (SNOWSTATE_CHECK_NON_EXISTENT_STATE && !struct_exists(self.states, _parent_state_name)) {
			if (SNOWSTATE_SHOW_WARNING) self.__snowstate_trace($"Parent state '{_parent_state_name}' not defined, state '{_state_name}' not added.");
			return self;
		}

		self.__enable_event_resolution();

		var _parent_state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _parent_state_name : string(_parent_state_name));
		var _state_name_hash = variable_get_hash(SNOWSTATE_ASSUME_STRING_NAMES ? _state_name : string(_state_name));

		if (SNOWSTATE_CHECK_CIRCULAR_INHERITANCE) {
			self.__assert_non_circular_inheritance(_state_name, _parent_state_name);
		}

		// only add the state, initial enter is handled later
		var _exec_initial_enter = self.exec_initial_enter;
		self.exec_initial_enter = false;
		self.add_state(_state_name, _event_or_events);
		self.exec_initial_enter = _exec_initial_enter;

		// handle inheritance
		if (struct_exists_from_hash(self.parent_state_name_hash, _state_name_hash)) {
			var _old_parent_state_name_hash = struct_get_from_hash(self.parent_state_name_hash, _state_name_hash);
			if (_old_parent_state_name_hash != _parent_state_name_hash) {
				// needs re-parenting
				if (SNOWSTATE_SHOW_WARNING) {
					var _old_parent_state_name = struct_get_from_hash(self.state_name_by_hash, _old_parent_state_name_hash);
					self.__snowstate_trace($"State '{_state_name}' already has parent '{_old_parent_state_name}', re-parenting to '{_parent_state_name}'.");
				}
				// remove state from old parent children list
				var _old_children = struct_get_from_hash(self.inheritance_tree, _old_parent_state_name_hash);
				if (!is_undefined(_old_children)) {
					var _old_child_index = array_get_index(_old_children, _state_name_hash);
					if (_old_child_index >= 0) {
						array_delete(_old_children, _old_child_index, 1);
					}
				}
			}
		}

		struct_set_from_hash(self.parent_state_name_hash, _state_name_hash, _parent_state_name_hash);

		// update children list for the parent
		var _children = struct_get_from_hash(self.inheritance_tree, _parent_state_name_hash);
		if (is_undefined(_children)) {
			_children = [];
			struct_set_from_hash(self.inheritance_tree, _parent_state_name_hash, _children);
		}
		if (!array_contains(_children, _state_name_hash)) {
			array_push(_children, _state_name_hash);
		}
		self.__resolve_inheritance_subtree(_state_name_hash);

		// finally, handle initial enter
		self.__try_exec_initial_enter(_state_name);

		return self;
	};

	/// @desc Runs the overridden handler
	/// @returns {Struct.SnowState}
	static inherit = function() {
		var _current_event = self.current_resolved_event;
		if (is_undefined(_current_event)) return self;

		var _parent_event = _current_event.parent_resolved_event;
		if (is_undefined(_parent_event)) return self;

		var _prev_event_args = self.current_event_args;

		var _args = _prev_event_args;
		if (argument_count > 0) {
			_args = array_create(argument_count);
			for (var _i = 0; _i < argument_count; ++_i) {
				_args[_i] = argument[_i];
			}
		}

		self.current_resolved_event = _parent_event;
		self.current_event_args = _args;

		if (is_undefined(_args)) {
			_parent_event.func();
		} else {
			method_call(_parent_event.func, _args);
		}

		self.current_resolved_event = _current_event;
		self.current_event_args = _prev_event_args;

		return self;
	};

	#endregion

	#region Transitions

	/// @desc Adds a transition
	/// @ignore
	/// @param {String} _transition_name Transition name
	/// @param {String,Array<String>} _src_state_name_or_names Source state name(s)
	/// @param {String} _dest_state_name Destination state (or "=" for reflexive)
	/// @param {Function,Undefined} _condition Condition function, or undefined
	/// @param {Function,Undefined} _src_state_exit Source exit callback, or undefined
	/// @param {Function,Undefined} _dest_state_enter Destination enter callback, or undefined
	/// @param {Bool} _is_push Whether to push instead of replace
	/// @returns {Struct.SnowState}
	static __add_transition = function(_transition_name, _src_state_name_or_names, _dest_state_name, _condition, _src_state_exit, _dest_state_enter, _is_push) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_transition_name, "add_transition", "_transition_name");
			self.__assert_name_or_names(_src_state_name_or_names, "add_transition", "_src_state_name_or_names");
			self.__assert_name(_dest_state_name, "add_transition", "_dest_state_name");
			self.__assert_callable_or_undefined(_condition, "add_transition", "_condition");
			self.__assert_callable_or_undefined(_src_state_exit, "add_transition", "_src_state_exit");
			self.__assert_callable_or_undefined(_dest_state_enter, "add_transition", "_dest_state_enter");
		}

		if (!SNOWSTATE_ASSUME_STRING_NAMES) {
			_transition_name = string(_transition_name);
			if (!is_array(_src_state_name_or_names)) {
				_src_state_name_or_names = string(_src_state_name_or_names);
				if (_dest_state_name != SNOWSTATE_REFLEXIVE_TRANSITION_NAME) _dest_state_name = string(_dest_state_name);
			}
		}

		if (is_array(_src_state_name_or_names)) {
			var _src_state_names_len = array_length(_src_state_name_or_names);
			for (var _i = 0; _i < _src_state_names_len; ++_i) {
				self.__add_transition(_transition_name, _src_state_name_or_names[_i], _dest_state_name, _condition, _src_state_exit, _dest_state_enter, _is_push);
			}
		} else {
			if (!struct_exists(self.transitions, _transition_name)) {
				self.transitions[$ _transition_name] = {};
			}
			if (!struct_exists(self.transitions[$ _transition_name], _src_state_name_or_names)) {
				self.transitions[$ _transition_name][$ _src_state_name_or_names] = [];
			}
			var _transition = new self.Transition(_transition_name, _src_state_name_or_names, _dest_state_name, _condition, _src_state_exit, _dest_state_enter, _is_push);
			array_push(self.transitions[$ _transition_name][$ _src_state_name_or_names], _transition);
		}

		return self;
	};

	/// @desc Runs the first passing trigger
	/// @ignore
	/// @param {Array<Struct.SnowState.Transition>,Undefined} _triggers Candidate transitions
	/// @param {Any} _data Data for condition/callbacks
	/// @returns {Bool} Whether a trigger fired
	static __try_triggers = function(_triggers, _data) {
		if (is_undefined(_triggers)) return false;

		var _triggers_len = array_length(_triggers);
		for (var _i = 0; _i < _triggers_len; ++_i) {
			var _transition = _triggers[_i];
			if (is_undefined(_transition.condition) || _transition.condition(_data)) {
				var _dest_state_name = _transition.dest_state_name;
				if (_dest_state_name == SNOWSTATE_REFLEXIVE_TRANSITION_NAME) {
					_dest_state_name = self.current_state_name;
				}

				if (_transition.is_push) {
					self.__push_state(_dest_state_name, _data, _transition.transition_name);
					return true;
				} else if (self.__change_state(_dest_state_name, _transition.src_state_exit, _transition.dest_state_enter, _data)) {
					self.__broadcast_state_change(_transition.transition_name, self.CHANGE_KIND_CHANGE);
					return true;
				} else {
					if (SNOWSTATE_SHOW_WARNING) {
						self.__snowstate_trace($"Transition '{_transition.transition_name}' matched but the change to '{_dest_state_name}' failed, nothing was broadcast.");
					}
					return false;
				}
			}
		}
		return false;
	};

	/// @desc Adds a push transition
	/// @param {String} _transition_name Transition name
	/// @param {String,Array<String>} _src_state_name_or_names Source state name(s)
	/// @param {String} _dest_state_name State to push
	/// @param {Function} [_condition] Condition for the push
	/// @returns {Struct.SnowState}
	static add_push_transition = function(_transition_name, _src_state_name_or_names, _dest_state_name, _condition = undefined) {
		return self.__add_transition(_transition_name, _src_state_name_or_names, _dest_state_name, _condition, undefined, undefined, true);
	};

	/// @desc Adds a reflexive transition
	/// @param {String} _transition_name Transition name
	/// @param {String,Array<String>} _src_state_name_or_names Source state name(s)
	/// @param {Function} [_condition] Condition function, or undefined
	/// @param {Function} [_src_state_exit] Source exit callback, or undefined
	/// @param {Function} [_dest_state_enter] Destination enter callback, or undefined
	/// @returns {Struct.SnowState}
	static add_reflexive_transition = function(_transition_name, _src_state_name_or_names, _condition = undefined, _src_state_exit = undefined, _dest_state_enter = undefined) {
		return self.add_transition(_transition_name, _src_state_name_or_names, SNOWSTATE_REFLEXIVE_TRANSITION_NAME, _condition, _src_state_exit, _dest_state_enter);
	};

	/// @desc Adds a transition
	/// @param {String} _transition_name Transition name
	/// @param {String,Array<String>} _src_state_name_or_names Source state name(s)
	/// @param {String} _dest_state_name Destination state
	/// @param {Function} [_condition] Condition for the transition
	/// @param {Function} [_src_state_exit] Source exit callback, or undefined
	/// @param {Function} [_dest_state_enter] Destination enter callback, or undefined
	/// @returns {Struct.SnowState}
	static add_transition = function(_transition_name, _src_state_name_or_names, _dest_state_name, _condition = undefined, _src_state_exit = undefined, _dest_state_enter = undefined) {
		return self.__add_transition(_transition_name, _src_state_name_or_names, _dest_state_name, _condition, _src_state_exit, _dest_state_enter, false);
	};

	/// @desc Adds a wildcard transition
	/// @param {String} _transition_name Transition name
	/// @param {String} _dest_state_name Destination state
	/// @param {Function} [_condition] Condition function, or undefined
	/// @param {Function} [_src_state_exit] Source exit callback, or undefined
	/// @param {Function} [_dest_state_enter] Destination enter callback, or undefined
	/// @returns {Struct.SnowState}
	static add_wildcard_transition = function(_transition_name, _dest_state_name, _condition = undefined, _src_state_exit = undefined, _dest_state_enter = undefined) {
		return self.add_transition(_transition_name, SNOWSTATE_WILDCARD_TRANSITION_NAME, _dest_state_name, _condition, _src_state_exit, _dest_state_enter);
	};

	/// @desc Checks if a transition exists
	/// @param {String} _transition_name Transition name to check
	/// @returns {Bool}
	static transition_exists = function(_transition_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_transition_name, "transition_exists", "_transition_name");
		}
		if (!SNOWSTATE_ASSUME_STRING_NAMES) _transition_name = string(_transition_name);

		return struct_exists(self.transitions, _transition_name);
	};

	/// @desc Checks if a transition exists for a state
	/// @param {String} _transition_name Transition name to check
	/// @param {String} _source_state_name Source state to check
	/// @returns {Bool}
	static transition_for_state_exists = function(_transition_name, _source_state_name) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name(_transition_name, "transition_for_state_exists", "_transition_name");
			self.__assert_name(_source_state_name, "transition_for_state_exists", "_source_state_name");
		}
		if (!SNOWSTATE_ASSUME_STRING_NAMES) {
			_transition_name = string(_transition_name);
			_source_state_name = string(_source_state_name);
		}

		return struct_exists(self.transitions, _transition_name) && struct_exists(self.transitions[$ _transition_name], _source_state_name);
	};

	/// @desc Fires a transition
	/// @param {String,Array<String>} _transition_name_or_names Transition name(s) to attempt
	/// @param {Any} [_data] Data for condition/callbacks
	/// @returns {Bool}
	static trigger = function(_transition_name_or_names, _data = undefined) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_name_or_names(_transition_name_or_names, "trigger", "_transition_name_or_names");
		}
		if (!SNOWSTATE_ASSUME_STRING_NAMES && !is_array(_transition_name_or_names)) {
			_transition_name_or_names = string(_transition_name_or_names);
		}

		if (is_array(_transition_name_or_names)) {
			var _transition_names_len = array_length(_transition_name_or_names);
			for (var _i = 0; _i < _transition_names_len; ++_i) {
				if (self.trigger(_transition_name_or_names[_i], _data)) {
					return true;
				}
			}
		} else {
			var _transitions = self.transitions[$ _transition_name_or_names];

			if (is_undefined(_transitions)) {
				if (SNOWSTATE_SHOW_WARNING) self.__snowstate_trace($"Transition '{_transition_name_or_names}' is not defined.");
				return false;
			}

			var _triggers = struct_get_from_hash(_transitions, self.current_state_name_hash);
			if (self.__try_triggers(_triggers, _data)) {
				return true;
			}

			if (struct_exists(_transitions, SNOWSTATE_WILDCARD_TRANSITION_NAME)) {
				if (self.__try_triggers(_transitions[$ SNOWSTATE_WILDCARD_TRANSITION_NAME], _data)) {
					return true;
				}
			}

			var _current_state_name_hash = self.current_state_name_hash;
            if (self.resolution_enabled) {
    			while (struct_exists_from_hash(self.parent_state_name_hash, _current_state_name_hash)) {
    				_current_state_name_hash = struct_get_from_hash(self.parent_state_name_hash, _current_state_name_hash);
    				var _resolved_triggers = struct_get_from_hash(_transitions, _current_state_name_hash);
    				if (self.__try_triggers(_resolved_triggers, _data)) {
    					return true;
    				}
    			}
            }
		}

		return false;
	};

	#endregion

	#region History

	/// @desc Records the current state in history
	/// @ignore
	/// @returns {Struct.SnowState}
	static __history_push_current_state = function() {
		if (self.history_max_size == 0) return self;

		var _len = array_length(self.history);
		if (_len < self.history_max_size) {
			array_insert(self.history, 0, self.current_state_name);
		} else {
			for (var _i = _len-2; _i >= 0; --_i) {
				self.history[_i+1] = self.history[_i];
			}
			self.history[0] = self.current_state_name;
		}

		return self;
	};

	/// @desc Returns the history array
	/// @returns {Array<Any>} Machine's own array -- do NOT modify
	static history_get = function() {
		return self.history;
	};

	/// @desc Checks if history is enabled
	/// @returns {Bool}
	static history_get_enabled = function() {
		return self.history_enabled;
	};

	/// @desc Returns the maximum history size
	/// @returns {Real}
	static history_get_max_size = function() {
		return self.history_max_size;
	};

	/// @desc Enables or disables history
	/// @param {Bool} _enabled Whether to enable history
	/// @returns {Struct.SnowState}
	static history_set_enabled = function(_enabled) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_bool(_enabled, "history_set_enabled", "_enabled");
			_enabled = bool(_enabled);
		}

		if (self.history_enabled != _enabled) {
			self.history_enabled = _enabled;
			if (self.history_enabled) {
				self.__history_push_current_state();
			} else {
				array_resize(self.history, 0);
			}
		}
		return self;
	};

	/// @desc Sets the maximum history size
	/// @param {Real} _size Maximum history size
	/// @returns {Struct.SnowState}
	static history_set_max_size = function(_size) {
		if (SNOWSTATE_VERIFY_USER_ARGS) {
			self.__assert_size(_size, "history_set_max_size", "_size");
		}

		var _prev_max_size = self.history_max_size;
		self.history_max_size = _size;
		var _len = array_length(self.history);
		if (_len > _size) {
			array_resize(self.history, _size);
		}
		if (self.history_enabled && (_prev_max_size == 0) && (_size > 0)) {
			self.__history_push_current_state();
		}
		return self;
	};

	#endregion

	#region Interfaces

	/// @desc Creates an event
	/// @param {String} _name Event name (built-in or custom)
	/// @param {Function} _func Handler to execute
	static Event = function(_name, _func) constructor {
		self.name = SNOWSTATE_ASSUME_STRING_NAMES ? _name : string(_name);
		self.func = _func;
	};

	/// @desc Holds a state's resolved events
	/// @param {Real} _state_name_hash State name hash
	static InheritanceTreeNode = function(_state_name_hash) constructor {
		self.state_name_hash = _state_name_hash;
		self.active_events = {};
	};

	/// @desc A resolved event handler
	/// @param {Function} _func Handler to run
	/// @param {Struct.ResolvedEvent} [_parent_resolved_event] What inherit() reaches
	/// @param {Bool} [_is_default] Whether this is a default handler
	static ResolvedEvent = function(_func, _parent_resolved_event, _is_default = false) constructor {
		self.func = _func;
		self.parent_resolved_event = _parent_resolved_event;
		self.is_default = _is_default;
	};

	/// @desc A suspended stack frame
	/// @param {String} _state_name Suspended state name
	/// @param {Real} _state_name_hash Suspended state hash
	/// @param {Real} _state_timer_in_steps Suspended step timer
	static StackFrame = function(_state_name, _state_name_hash, _state_timer_in_steps) constructor {
		self.state_name = _state_name;
		self.state_name_hash = _state_name_hash;
		self.state_timer_in_steps = _state_timer_in_steps;
	};

	/// @desc The state change broadcast payload
	/// @param {String} _current_state_name State now active
	/// @param {String,Undefined} _previous_state_name State active before
	/// @param {String,Undefined} _transition_name Triggering transition, or undefined
	/// @param {String} _change_kind Change kind (CHANGE/PUSH/POP)
	static StateChange = function(_current_state_name, _previous_state_name, _transition_name, _change_kind) constructor {
		self.current_state_name = _current_state_name;
		self.previous_state_name = _previous_state_name;
		self.transition_name = _transition_name;
		self.change_kind = _change_kind;
	};

	/// @desc A single transition
	/// @param {String} _transition_name Transition name
	/// @param {String} _src_state_name Source state
	/// @param {String} _dest_state_name Destination state (or "=" for reflexive)
	/// @param {Function} [_condition] Condition function, or undefined
	/// @param {Function} [_src_state_exit] Source exit callback, or undefined
	/// @param {Function} [_dest_state_enter] Destination enter callback, or undefined
	/// @param {Bool} [_is_push] Whether to push instead of replace
	static Transition = function(_transition_name, _src_state_name, _dest_state_name, _condition = undefined, _src_state_exit = undefined, _dest_state_enter = undefined, _is_push = false) constructor {
		self.transition_name = _transition_name;
		self.src_state_name = _src_state_name;
		self.dest_state_name = _dest_state_name;
		self.condition = _condition;
		self.src_state_exit = _src_state_exit;
		self.dest_state_enter = _dest_state_enter;
		self.is_push = _is_push;
	};

	#endregion

	#region Deprecated

	/// @desc Deprecated alias for add_state()
	/// @deprecated
	/// @ignore
	static add = add_state;
	/// @desc Deprecated alias for add_child_state()
	/// @deprecated
	/// @ignore
	static add_child = add_child_state;
	/// @desc Deprecated alias for change_state()
	/// @deprecated
	/// @ignore
	static change = change_state;
	/// @desc Deprecated alias for get_current_state_name()
	/// @deprecated
	/// @ignore
	static get_current_state = get_current_state_name;
	/// @desc Deprecated alias for get_previous_state_name()
	/// @deprecated
	/// @ignore
	static get_previous_state = get_previous_state_name;
	/// @desc Deprecated alias for history_set_enabled(false)
	/// @deprecated
	/// @ignore
	/// @returns {Struct.SnowState}
	static history_disable = function() { return self.history_set_enabled(false); };
	/// @desc Deprecated alias for history_set_enabled(true)
	/// @deprecated
	/// @ignore
	/// @returns {Struct.SnowState}
	static history_enable = function() { return self.history_set_enabled(true); };
	/// @desc Deprecated alias for history_get_enabled()
	/// @deprecated
	/// @ignore
	static history_is_enabled = history_get_enabled;

	#endregion

	#region Removed

	/// @desc Removed in v4
	/// @ignore
	static event_get_current_function = undefined;

	#endregion
}

#macro SNOWSTATE_VERSION "4.0.0-alpha"
show_debug_message($"[SnowState] You are using SnowState by @sohomsahaun (Version: {SNOWSTATE_VERSION})");