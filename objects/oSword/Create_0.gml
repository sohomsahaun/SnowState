// Setup
mask_index = sSwordMask;

// Declare methods
event_user(15);

// Variables
owner = noone;
spd = 6;
hspd = 0;
face = 1;

// State Machine
fsm = new SnowState("NULL");

fsm
	.event_set_default_function("draw", function() {
		// Draw this no matter what state we are in
		// (Unless it is overridden, ofcourse)
		draw_sprite_ext(sprite_index, image_index, x, y, face * image_xscale, image_yscale, image_angle, image_blend, image_alpha);
	})
	.add("NULL")
	.add("idle")
	.add("spinning", {
		enter: function() {
			sprite_index = sSwordSpinning;
			mask_index = sSwordMask;
			image_speed = 1;
			image_index = 0;
			
			hspd = face * spd;
		},
		step: function() {
			if (place_meeting(x+hspd, y, oWall)) {
				fsm.change("embedded");
				return;
			}
			x += hspd;
		}
	})
	.add("embedded", {
		enter: function() {
			sprite_index = sSwordEmbedded;
			mask_index = sSwordEmbeddedMask;
			image_speed = 1;
			image_index = 0;
			
			// Embed into the wall
			while (!place_meeting(x+hspd, y, oWall)) x += hspd;
			while (!place_meeting(x+sign(hspd), y, oWall)) x += sign(hspd);
			
			hspd = 0;
		},
		step: function() {
			// Play the animation once
			if (animation_end()) {
				image_speed = 0;
				image_index = image_number - 1;
			}
		}
	})
	.add("recall", {
		enter: function() {
			sprite_index = sSwordSpinning;
			mask_index = sSwordMask;
			image_speed = 1;
			image_index = 0;
			
			speed = spd;
		},
		step: function() {
			if (!instance_exists(owner)) {
				instance_destroy();
				return;
			}
			
			direction = point_direction(x, y, owner.x, owner.y-owner.sprite_height/2);
			face = (x > xprevious) * 2 - 1;
			if (place_meeting(x, y, owner)) {
				owner.equip_sword();
				instance_destroy();
				return;
			}
		}
	});