/**
*	SnowState | v1.0.0
*
*
*	Struct(s):
*		> StateMachine(initial_state, [state_name, state_struct])
*			- add(state, state_struct)
*			- enter()
*			- step()
*			- draw()
*			- leave()
*			- get_time()
*			- get_current()
*			- get_previous()
*
*
*	Function(s):
*		> state_switch(state, [perf, leave_func, enter_func])
*		> get_current_state([id])
*		> get_previous_state([id])
*
*
*	Author: Sohom Sahaun | @sohomsahaun
*/

/// @func	  StateMachine(initial_state, [state_name, state_struct])
/// @param	  {string} initial_state			Initial state for the state machine
/// @param	  {string} [state					Name for the state
/// @param	  {struct} state_struct]			Struct { enter | step | draw | leave }
function StateMachine(_state) constructor {
	#region System
	states = {};
	stateTimer = 0;
	defState   = _state;
	currState  = undefined;
	prevState  = undefined;
	currEvents = undefined;
	
	if (variable_instance_exists(other, "__stateStruct__")) {
		var _message = "State Machine already exists for " + string(object_get_name(other.object_index)) + ".";
		show_error(_message, true);
	}
	variable_instance_set(other, "__stateStruct__", self);
	
	/// @func		__get_struct([state])
	/// @param		{string} [state]			State to get the struct of
	/// @returns	{struct}					Struct for the state
	static __get_events = function(_state) {
		if (0) return argument[0];
		if (_state == undefined) _state = currState;
		
		var _events = variable_struct_get(states, _state);
		if (is_undefined(_events)) {
			var _message = "State \"" + string(_state) + "\" does not exist for " + string(object_get_name(other.object_index)) + ".";
			show_error(_message, true);	
		}
		return _events;
	};
	
	/// @func		__execute(event)
	/// @param		{real} event				Event to execute [__STATE_EVENT]
	/// @returns	N/A
	// enum __STATE_EVENT {ENTER, STEP, DRAW, LEAVE}
	static __execute = function(_event) {
		if (is_undefined(currState)) {
			currState  = defState;
			currEvents = __get_events();
			enter();
		}
		currEvents[_event]();
	};
	
	/// @func		__switch(event)
	/// @param		{string} state				State to switch to
	/// @param		{bool}	 perf				If enter/leave events should be performed | Default: true
	/// @param		{func}	 leave_function		Custom function for leave event of current state | Default: -1
	/// @param		{func}	 enter_function		Custom function for enter event of next state    | Default: -1
	/// @returns	N/A
	static __switch = function(_state, _perf, _leave, _enter) {
		stateTimer = 0;
		
		if (_perf) {
			if (_leave == -1) leave();
				else _leave();
		}
		prevState = currState;
		currState  = _state;
		currEvents = __get_events();
		if (_perf) {
			if (_enter == -1) enter();
				else _enter();
		}
	};
	#endregion
	
	/// @func		add(state, state_struct)
	/// @param		{string} state				Name for the state
	/// @param		{struct} state_struct		Struct { enter | step | draw | leave }
	/// @returns	N/A
	static add = function(_name, _struct) {
		if (!is_string(_name) || (_name == "")) {
			var _message = "State identifier should be a non-empty string.";
			show_error(_message, true);	
		}
		
		if (!variable_struct_exists(_struct, "enter")) _struct.enter = function() {};
		if (!variable_struct_exists(_struct, "step") ) _struct.step  = function() {};
		if (!variable_struct_exists(_struct, "draw") ) _struct.draw  = function() { draw_self(); };
		if (!variable_struct_exists(_struct, "leave")) _struct.leave = function() {};
		
		variable_struct_set(states, _name, [method(other, _struct.enter),
											method(other, _struct.step),
											method(other, _struct.draw),
											method(other, _struct.leave)]);
	};
	
	/// @func		enter()
	/// @returns	N/A
	static enter = function() {
		__execute(0);
	};
	
	/// @func		step()
	/// @returns	N/A
	static step = function() {
		++stateTimer;
		__execute(1);
	};
	
	/// @func		draw()
	/// @returns	N/A
	static draw = function() {
		__execute(2);
	};
	
	/// @func		leave()
	/// @returns	N/A
	static leave = function() {
		__execute(3);
	};
	
	/// @func		get_time()
	/// @returns	{real}						Time (in steps) the current state has been running for
	static get_time = function() {
		return stateTimer;
	};
	
	/// @func		get_current()
	/// @returns	{string}					Current state the system is in
	static get_current = function() {
		return currState;
	};
	
	/// @func		get_previous()
	/// @returns	{string}					Previous state the system was in
	static get_previous = function() {
		return prevState;
	};
	
	// Add optional args
	for (var _i = 1; _i < argument_count; _i += 2) add(argument[_i], argument[_i+1]);
}

/// @func		state_switch(state, [perf, leave_func, enter_func])
/// @param		{string} state				State to switch to
/// @param		{bool}	 [perf				Whether leave/enter events should be performed (true) or not (false) | Default: true
/// @param		{func}	 leave_func			Custom function for leave event of current state | Default: -1
/// @param		{func}	 enter_func]		Custom function for enter event of next state    | Default: -1
/// @returns	N/A
function state_switch(_state, _perf, _leave, _enter) {
	if (0) return argument[0];
	if (_perf == undefined) _perf = true;
	if (!is_method(_leave)) _leave = -1;
	if (!is_method(_enter)) _enter = -1;
	__stateStruct__.__switch(_state, _perf, _leave, _enter);
}

/// @func		get_current_state(id)
/// @param		{real} id					Instance ID
/// @returns	{string/undefined}			Current state for an instance
function get_current_state(_id) {
	if (!variable_instance_exists(_id, "__stateStruct__")) return undefined;
	return _id.__stateStruct__.currState;
}

/// @func		get_previous_state(id)
/// @param		{real} id					Instance ID
/// @returns	{string/undefined}			Previous state for an instance
function get_previous_state(_id) {
	if (!variable_instance_exists(_id, "__stateStruct__")) return undefined;
	return _id.__stateStruct__.prevState;
};