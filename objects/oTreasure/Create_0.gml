// Setup
image_speed = 0;
image_index = 0;

// Variables 
arrowImg = 0;
arrowImgSpd = .1;

// Functions
interact = function() {
	var _state = get_current_state();
	if (_state == "closed")	state_switch("opened");
		else if (_state == "opened") state_switch("empty");	
}

// State Machine
state = new StateMachine("closed",
	
	"closed", {
		enter: function() {
			image_index = 0;
		},
		draw: function() {
			if (place_meeting(x, y, oPlayer)) {
				draw_sprite(sTreasureArrow, arrowImg, x, y-20);
				arrowImg += arrowImgSpd;
			} else arrowImg = 0;
			draw_self();
		}
	},
	
	"opened", {
		enter: function() {
			image_index = 1;	
		},
		draw: function() {
			if (place_meeting(x, y, oPlayer)) {
				draw_sprite(sTreasureArrow, arrowImg, x, y-20);
				arrowImg += arrowImgSpd;
			} else arrowImg = 0;
			draw_self();
		}
	},
	
	"empty", {
		enter: function() {
			image_index	= 2;
		}
	}
);