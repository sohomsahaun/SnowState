/**
*	SnowState | v2.0.0
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
		stateTimer		: 0,
		initState		: _initState,
		execEnter		: _execEnter,
		history			: [],
		historyMaxSize	: max(1, SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE),
		historyEnabled	: SNOWSTATE_HISTORY_ENABLED,
	};
	
	static __snowstate_error = function() {
		var _str = "SnowState Error:\n";
		var _i = 0; repeat(argument_count) {
			_str += string(argument[_i++]);	
		}
		show_error(_str, true);
	}
	
	static __snowstate_trace = function() {
		var _str = "[SnowState] ";
		var _i = 0; repeat(argument_count) {
			_str += string(argument[_i++]);	
		}
		show_debug_message(_str);
	}
	
	static __is_state_defined = function(_state) {
		return (is_string(_state) && variable_struct_exists(__this.states, _state));
	};
	
	static __fill_state_struct = function(_struct) {
		if (!variable_struct_exists(_struct, "enter")) _struct.enter = function() {};
		if (!variable_struct_exists(_struct, "step") ) _struct.step  = function() {};
		if (!variable_struct_exists(_struct, "draw") ) _struct.draw  = function() { draw_self(); };
		if (!variable_struct_exists(_struct, "leave")) _struct.leave = function() {};	
		return _struct;
	};
	
	static __create_events_array = function(_struct) {
		var _events = array_create(__SNOWSTATE_EVENT.SIZE__);
		_events[@ __SNOWSTATE_EVENT.ENTER] = method(__this.owner, _struct.enter);
		_events[@ __SNOWSTATE_EVENT.STEP ] = method(__this.owner, _struct.step );
		_events[@ __SNOWSTATE_EVENT.DRAW ] = method(__this.owner, _struct.draw );
		_events[@ __SNOWSTATE_EVENT.LEAVE] = method(__this.owner, _struct.leave);
		return _events;
	};
	
	static __get_events_array = function(_state) {
		return __this.states[$ _state];
	};
	
	static __history_fit_contents = function() {
		array_resize(__this.history, min(array_length(__this.history), __this.historyMaxSize));
		return self;
	};
	
	static __history_resize = function(_size) {
		__this.historyMaxSize = _size;
		__history_fit_contents();
	};
	
	static __history_add = function(_state) {
		if (__this.historyEnabled) {
			array_insert(__this.history, 0, _state);
			__history_fit_contents();
		} else {
			__this.history[@ 0] = _state;
		}
		return self;
	};
	
	static __execute = function(_event) {
		var _state = __this.history[@ 0];
		if (!__is_state_defined(_state)) {
			__snowstate_error("State \"", _state, "\" is not defined.");
			return undefined;
		}
		if (!__is_state_defined(_state)) {
			
		}
		__get_events_array(_state)[@ _event]();
		return self;
	};
	
	static __switch = function(_state, _leave, _enter) {
		__this.stateTimer = 0;
		_leave();
		__history_add(_state);
		_enter();
		return self;
	};
	#endregion
	
	static enter = function() {
		__execute(__SNOWSTATE_EVENT.ENTER);
		return self;
	};
	
	static step = function() {
		++__this.stateTimer;
		__execute(__SNOWSTATE_EVENT.STEP);
		return self;
	};
	
	static draw = function() {
		__execute(__SNOWSTATE_EVENT.DRAW);
		return self;
	};
	
	static leave = function() {
		__execute(__SNOWSTATE_EVENT.LEAVE);
		return self;
	};
	
	static add = function(_name, _struct) {
		if (!is_string(_name) || (_name == "")) {
			__snowstate_error("State name should be a non-empty string.");
			return undefined;
		}
		
		if (!is_struct(_struct)) {
			__snowstate_error("State struct should be a struct.");
			return undefined;
		}
		
		if (__is_state_defined(_name)) {
			__snowstate_error("State \"", _name, "\" has been defined already.");
			return undefined;
		}
		
		__this.states[$ _name] = __create_events_array(__fill_state_struct(_struct));
		
		if (_name == __this.initState) {
			if (__this.execEnter) enter();
		}
		
		return self;
	};
	
	static change = function(_state, _leave, _enter) {
		if (_leave == undefined) _leave = -1;
		if (_enter == undefined) _enter = -1;
		
		if (!is_method(_leave)) {
			if (_leave != -1) {
				__snowstate_error("Invalid command \"", _leave, "\" in change().");
				return undefined;
			}
			_leave = leave;
		}
		
		if (!is_method(_enter)) {
			if (_enter != -1) {
				__snowstate_error("Invalid command \"", _enter, "\" in change().");
				return undefined;
			}
			_enter = enter;
		}
		
		__switch(_state, _leave, _enter);
		return self;
	};
	
	static history_is_enabled = function() {
		return __this.historyEnabled;
	};
	
	static history_enable = function() {
		if (!__this.historyEnabled) {
			__this.historyEnabled = true;
			__history_resize(__this.historyMaxSize);
		}
		return self;
	};
	
	static history_disable = function() {
		if (__this.historyEnabled) {
			__this.historyEnabled = false;
			array_resize(__this.history, 1);
		}
		return self;
	};
	
	static get_history = function() {
		if (!__this.historyEnabled) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("History is disabled, can not get history.");	
			}
			return [];
		}
		var _len = array_length(__this.history);
		var _arr = array_create(_len);
		array_copy(_arr, 0, __this.history, 0, _len);
		return _arr;
	};
	
	static set_history_max_size = function(_size) {
		if (!is_real(_size)) {
			__snowstate_error("Size should be a number.");
			return undefined;
		}
		if (_size < 1) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("History size should be 1 or more. Setting the size to 1 instead of ", _size, ".");
			}
			_size = 1;
		}
		__history_resize(_size);
		return self;
	};
	
	static get_history_max_size = function() {
		return __this.historyMaxSize;	
	};
	
	static get_current_state = function() {
		return ((array_length(__this.history) > 0) ? __this.history[@ 0] : "");
	};
	
	static get_previous_state = function() {
		if (!__this.historyEnabled) {
			if (SNOWSTATE_DEBUG_WARNING) {
				__snowstate_trace("History is disabled, can not get previous state.");	
			}
			return "";
		}
		return ((array_length(__this.history) > 1) ? __this.history[@ 1] : "");
	};
	
	static get_time = function() {
		return __this.stateTimer;
	};
	
	// Initialization
	if (!is_string(_initState) || (_initState == "")) {
		__snowstate_error("State name should be a non-empty string.");
	}
	__history_add(_initState);
	
	if (__this.historyEnabled) history_enable();
		else history_disable();
}


#macro SNOWSTATE_VERSION "2.0.0"
#macro SNOWSTATE_DATE "23-02-2021"
enum __SNOWSTATE_EVENT {
	ENTER, STEP, DRAW, LEAVE,
	SIZE__
}

show_debug_message("[SnowState] You are using SnowState by @sohomsahaun (Version: " + string(SNOWSTATE_VERSION) + " | Date: " + string(SNOWSTATE_DATE) + ")");