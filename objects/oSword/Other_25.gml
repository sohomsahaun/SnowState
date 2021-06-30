/// @desc Methods

recall = function() {
	if (instance_exists(owner) && state.state_is("embedded")) {
		state.change("recall");
	}
};