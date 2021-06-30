// Setup
mask_index = sPlayerMask;

// Declare methods
event_user(15);

// Sprite management
sprites = {};
init_sprites(
	"idle", "Idle",
	"run",	"Run",
	"jump",	"Jump",
	"fall",	"Fall",
	"groundAttack1", "Attack1",
	"groundAttack2", "Attack2",
	"groundAttack3", "Attack3",
	"airAttack1", "AirAttack1",
	"airAttack2", "AirAttack2",
	"throwSword", "ThrowSword"
);

effectSprites = {};
init_effect_sprites(
	"groundAttack1", "Attack1",
	"groundAttack2", "Attack2",
	"groundAttack3", "Attack3",
	"airAttack1", "AirAttack1",
	"airAttack2", "AirAttack2"
);

// Variables
spd = 3;
hspd = 0;
vspd = 0;
vspdMax = 15;

jspd = 12;
gravGround = .6;	// Normal gravity
gravAttack = .05;	// Low gravity when air attacking
grav = gravGround;

face = 1;
hasSword = 1;
coyoteDuration = 8;
nextAttack = false;
canAirAttack = true;

// Input
input = {};
check_input();

// State Machine
state = new SnowState("idle");

state
	.history_enable()
	.set_history_max_size(20)
	.event_set_default_function("draw", function() {
		// Draw this no matter what state we are in
		// (Unless it is overridden, ofcourse)
		draw_sprite_ext(sprite_index, image_index, x, y, face * image_xscale, image_yscale, image_angle, image_blend, image_alpha);
	})
	.add("idle", {
		enter: function() {
			sprite_index = get_sprite();
			image_speed = 1;
			
			hspd = 0;
			vspd = 0;
		},
		step: function() {
			check_input();
			
			// If left or right keys are pressed, run
			if (abs(input.hdir)) {
				state.change("run");
				return;
			}
			
			// If jump key is pressed, jump
			if (input.jump) {
				state.change("jump");
				return;
			}
			
			if (hasSword) {
				// If attack key is pressed, go into groundAttack1
				if (input.attack) {
					state.change("groundAttack1");
					return;
				}
			
				// Throw the sword
				if (input.throwSword && hasSword) {
					state.change("throwSword");
					return;
				}
			} else {
				// Recall the sword
				if (input.recallSword) {
					var _sword = instance_find(oSword, 0);
					_sword.recall();
				}
			}
			
			// Movement
			apply_gravity();
			move_and_collide();
			
			// Check if I'm flating
			if (!on_ground()) {
				state.change("fall");
				return;
			}
		}
	})
	.add("run", {
		enter: function() {
			sprite_index = get_sprite();
			image_speed = 1;
		},
		step: function() {
			check_input();
			
			var _dir = input.hdir;
			hspd = spd * _dir;
			
			// If left and right keys are not pressed, switch back to idle
			if (_dir == 0) {
				state.change("idle");
				return;
			}
			
			face = _dir;
			
			// If jump key is pressed, jump
			if (input.jump) {
				state.change("jump");
				return;
			}
			
			if (hasSword) {
				// If attack key is pressed, go into groundAttack1
				if (input.attack) {
					state.change("groundAttack1");
					return;
				}
			
				// Throw the sword
				if (input.throwSword && hasSword) {
					state.change("throwSword");
					return;
				}
			} else {
				// Recall the sword
				if (input.recallSword) {
					var _sword = instance_find(oSword, 0);
					_sword.recall();
				}
			}
			
			// Movement
			apply_gravity();
			move_and_collide();
			
			// Check if I'm flating
			if (!on_ground()) {
				state.change("fall");
				return;
			}
		}
	})
	.add("jump", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			vspd = -jspd;	// Jump
		},
		step: function() {
			// Play the animation once
			if (animation_end()) {
				image_speed = 0;
				image_index = image_number - 1;
			}
			
			check_input();
			
			// Throw the sword
			if (input.throwSword && hasSword) {
				state.change("throwSword");
				return;
			}
			
			// Recall the sword
			if (input.recallSword && !hasSword) {
				var _sword = instance_find(oSword, 0);
				_sword.recall();
			}
			
			// Movement
			apply_gravity();
			move_and_collide();
			
			// Check when we should start falling
			if (vspd >= 0) {
				state.change("fall");
				return;
			}
		}
	})
	.add("fall", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			// If I have not done air attack when falling now, activate air attack
			// Air attack can be done once when falling
			if (state.state_is("airAttack", state.get_previous_state())) canAirAttack = false;
				else canAirAttack = true;
			
		},
		step: function() {
			// Play the animation once
			if (animation_end()) {
				image_speed = 0;
				image_index = image_number - 1;
			}
			
			check_input();
			var _dir = input.hdir;
			hspd = spd * _dir;
			if (_dir != 0) face = _dir;
			
			if (hasSword) {
				// If attack key is pressed, go into airAttack1
				if (input.attack && canAirAttack) {
					state.change("airAttack1");
					return;
				}
			
				// Throw the sword
				if (input.throwSword) {
					state.change("throwSword");
					return;
				}
			} else {
				// Recall the sword
				if (input.recallSword) {
					var _sword = instance_find(oSword, 0);
					_sword.recall();
				}
			}
			
			// Coyote time
			if ((state.get_time() <= coyoteDuration) && input.jump) {
				// Apply only if we were running
				if (state.get_previous_state() == "run") {
					state.change("jump");
					return;
				}
			}
			
			// Movement
			apply_gravity();
			move_and_collide();
			
			// Check when we land
			if (on_ground()) {
				state.change("idle");
				return;
			}
		}
	})
	.add("attack", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			nextAttack = false;
			
			// Create effect
			var _sprite = effectSprites[$ state.get_current_state()];
			var _face = face;
			var _x = x + _face * 8;
			with (instance_create_depth(_x, y, depth, oEffect)) {
				sprite_index = _sprite;
				image_xscale = _face;
			}
		},
		step: function() {
			check_input();
			
			// If attack key is pressed any time during the current state,
			// go to the next attack state after the animation ends
			if (input.attack) {
				nextAttack = true;	
			}
		}
	})
	.add_child("attack", "groundAttack", {
		/// @override
		enter: function() {
			state.inherit();
			
			// Stop
			hspd = 0;
			vspd = 0;
		},
			
		/// @override
		step: function() {
			state.inherit();
			
			// When the animation ends, go to the next attack state if attack has been pressed
			// Otherwise, just go idle
			if (animation_end()) {
				if (nextAttack) {
					var _state = state.get_current_state();
					var _curr = real(string_digits(_state));
					var _next = string_letters(_state) + string(_curr+1);
					state.change(_next);
				} else {
					state.change("idle");
				}
				return;
			}
		}
	})
	.add_child("groundAttack", "groundAttack1")
	.add_child("groundAttack", "groundAttack2")
	.add_child("groundAttack", "groundAttack3", {
		/// @override
		step: function() {
			// When the animation ends, go to idle state
			if (animation_end()) {
				state.change("idle");
				return;
			}
		}
	})
	.add_child("attack", "airAttack", {
		/// @override
		enter: function() {
			state.inherit();
			
			// Lower the gravity
			grav = gravAttack;
			vspd = 0;
		},			
		/// @override
		step: function() {
			state.inherit();
			
			// Go down, slowly
			apply_gravity();
			move_and_collide();
			
			// Check when we land
			if (on_ground()) {
				state.change("idle");
				return;
			}
			
			// When the animation ends, go to the next attack state if attack has been pressed
			// Otherwise, just back to falling again
			if (animation_end()) {
				if (nextAttack) {
					var _state = state.get_current_state();
					var _curr = real(string_digits(_state));
					var _next = string_letters(_state) + string(_curr+1);
					state.change(_next);
				} else {
					state.change("fall");
				}
				return;
			}
		},
		leave: function() {
			grav = gravGround;	
		}
	})
	.add_child("airAttack", "airAttack1")
	.add_child("airAttack", "airAttack2", {
		/// @override
		step: function() {
			// Go down, slowly
			apply_gravity();
			move_and_collide();
			
			// When the animation ends, go to fall state again
			if (animation_end()) {
				state.change("fall");
				return;
			}
		}
	})
	.add("throwSword", {
		enter: function() {
			sprite_index = get_sprite();
			image_index = 0;
			image_speed = 1;
			
			hspd = 0;
			vspd = 0;
			
			// Lower the gravity
			grav = gravAttack;
		},
		step: function() {
			if (animation_end()) {
				// Switch the state to idle or fall,
				// depending on what the previous state was
				var _state = "idle";
				if (state.get_previous_state() == "jump") _state = "fall";
				if (state.get_previous_state() == "fall") _state = "fall";
				state.change(_state);
				return;
			}
			
			// Movement
			apply_gravity();
			move_and_collide();
		},
		throwSword: function() {
			if (event_data[? "event_type"] == "sprite event") {
				spawn_sword();
				
				// Unequip the sword
				hasSword = false;
			}
		},
		leave: function() {
			grav = gravGround;	
		}
	});
