/// @desc Methods

recall = function() {
	if (instance_exists(owner) && fsm.state_is("embedded")) {
		fsm.change("recall");
	}
};