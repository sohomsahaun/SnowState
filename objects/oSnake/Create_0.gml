// Setup
mask_index = sSnakeMask;
image_xscale = choose(-1,1);

// Variables
spd = random_range(1,2);
hspd = spd*image_xscale;
vspd = 0;
grav = .6;
vspdMax = 12;

hpMax = 3;
hp = hpMax;
hitDir = 1;
hitAcc = .08;

// Functions
flip = function() {
	hspd *= -1;
	image_xscale *= -1;
	return hspd;
};

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

hit = function(_damage, _direction) {
	hp -= _damage;
	hitDir = _direction;
	state.change("hit");	
};

// State Machine
state = new SnowState("walk");

state
	.add("walk", {
		enter: function() {
			sprite_index = sSnakeWalk;
			image_index = 0;
			hspd = spd*image_xscale;
		},
		step: function() {
			if (place_meeting(x+hspd, y, oWall) || (!place_meeting(x+sprite_width/2, y+1, oWall))) flip();
			if (on_ground()) move_and_collide();
				else state.change("falling");
		}
	})
	
	.add("falling", {
		enter: function() {
			sprite_index = sSnakeFall;
			image_index = 0;
			hspd = 0;
		},
		step: function() {
			apply_gravity();
			if (on_ground()) state.change("walk");	
		}
	})
	
	.add("hit", {
		enter: function() {
			sprite_index = sSnakeHit;
			image_index = 0;
			hspd = spd * hitDir;
		},
		step: function() {
			if (hspd != 0) {
				hspd = approach(hspd, 0, hitAcc);
			} else {
				state.change("walk");
				return;
			}
			if (place_meeting(x+hspd, y, oWall)) flip();
			move_and_collide();
		},
		draw: function() {
			var _ww = 6, _hh = 24, _height = 2;
			draw_healthbar(x-_ww, y-_hh, x+_ww, y-_hh+_height, (hp/hpMax)*100, c_black, c_red, c_green, 0, true, true);
			draw_self();
		}
	});