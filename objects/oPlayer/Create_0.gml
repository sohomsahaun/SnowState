// Setup
randomize();
mask_index = sPlayerMask;

// Variables
spd = 3;
hspd = 0;
vspd = 0;
grav = .6;
vspdMax = 12;
jspd = 10;
airjump = 1;

hitDir = 1;
hitAcc = .05;

controls = {
	right: vk_right,
	left: vk_left,
	jump: vk_up,
	attack: vk_space,
	interact: ord("E")
}

// Functions
on_ground = function() {
	return (place_meeting(x, y+1, oWall));	
};

move_and_collide = function() {
	if (place_meeting(x+hspd, y, oWall)) {
		while (!place_meeting(x+sign(hspd), y, oWall)) x += sign(hspd);
		hspd = 0;
	}
	x += hspd;
	if (place_meeting(x, y+vspd, oWall)) {
		while (!place_meeting(x, y+sign(vspd), oWall)) y += sign(vspd);
		vspd = 0;
	}
	y += vspd;
};

apply_gravity = function() {
	vspd += grav;
	if (vspd > vspdMax) vspd = vspdMax;
	move_and_collide();
};

check_treasure = function() {
	var _inst = instance_place(x, y, oTreasure);
	with (_inst) interact();
}

// State Machine
state = new StateMachine("idle",

	"idle", {
		enter: function() {
			sprite_index = sPlayerIdle;
			image_index = 0;
			hspd = 0;
			vspd = 0;
		},
		step: function() {
			var _hdir = keyboard_check(controls.right) - keyboard_check(controls.left);
			if (abs(_hdir)) state_switch("walk");
			
			if (keyboard_check_pressed(controls.jump)) state_switch("rising");
			apply_gravity();
			
			if (keyboard_check_pressed(controls.attack)) state_switch("attack");
			
			if (keyboard_check_pressed(controls.interact)) check_treasure();
		}
	},
	
	"walk", {
		enter: function() {
			sprite_index = sPlayerWalk;
			image_index = 0;
		},
		step: function() {
			var _hdir = keyboard_check(controls.right) - keyboard_check(controls.left);
			if (abs(_hdir)) image_xscale = _hdir;
				else state_switch("idle");
			hspd = _hdir * spd;
			
			if (keyboard_check_pressed(controls.jump)) state_switch("rising");
			if (!on_ground()) state_switch("falling");
			apply_gravity();
			
			if (keyboard_check_pressed(controls.attack)) state_switch("attack");
		}
	},
	
	"attack", {
		enter: function() {
			sprite_index = sPlayerSlash;
			image_index = 0;
			hspd = 0;
			vspd = 0;
			
			var _slash = instance_create_depth(x, y-sprite_yoffset, depth, oSlash);
			_slash.image_xscale = image_xscale;
		},
		step: function() {
			if (animation_end()) state_switch("idle");
		}
	},
	
	"rising", {
		enter: function() {
			sprite_index = sPlayerRising;	
			image_index = 0;
			vspd = -jspd;
		},
		step: function() {
			var _hdir = keyboard_check(controls.right) - keyboard_check(controls.left);
			if (abs(_hdir)) image_xscale = _hdir;
			hspd = _hdir * spd;
			
			if (keyboard_check_pressed(controls.jump) && airjump) {
				airjump = 0;
				state_switch("rising");
			}
			apply_gravity();
			if (vspd >= 0) state_switch("falling");
		}
	},
	
	"falling", {
		enter: function() {
			sprite_index = sPlayerFalling;
			image_index = 0;
		},
		step: function() {
			var _hdir = keyboard_check(controls.right) - keyboard_check(controls.left);
			if (abs(_hdir)) image_xscale = _hdir;
			hspd = _hdir * spd;
			
			if (keyboard_check_pressed(controls.jump) && airjump) {
				airjump = 0;
				state_switch("rising");
			}
			apply_gravity();
			
			// Enable airjump only when falling to the ground
			if (on_ground()) state_switch("idle", true, function() {
				airjump = 1;	
			});
		}
	}
);
