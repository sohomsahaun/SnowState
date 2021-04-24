// Setup
image_speed = 0;
image_index = 0;

// Variables 
arrowImg = 0;
arrowImgSpd = .1;

// Functions
interact = function() {
	var _state = state.get_current_state();
	if (_state == "closed")	state.change("opened");
		else if (_state == "opened") state.change("empty");	
}

// State Machine
state = new SnowState("closed");
state
	.event_set_default_function("draw", function() {
			if (place_meeting(x, y, oPlayer)) {
				draw_sprite(sTreasureArrow, arrowImg, x, y-20);
				arrowImg += arrowImgSpd;
			} else arrowImg = 0;
			draw_self();
	})
	.add("closed", {
		enter: function() {
			image_index = 0;
		}
	})
	
	.add("opened", {
		enter: function() {
			image_index = 1;	
		}
	})
	
	.add("empty", {
		enter: function() {
			image_index	= 2;
		},
		draw: function() {
			draw_self();
		}
	});