/// @desc Methods

init_sprites = function() {
	var _i = 0; repeat (argument_count div 2) {
		var _noSword = asset_get_index("sPlayer" + argument[_i+1]);
		if (_noSword == -1) _noSword = sPlayerIdle;
		
		var _sword = asset_get_index("sPlayerSword" + argument[_i+1]);
		if (_sword == -1) _sword = sPlayerSwordIdle;
		
		sprites[$ argument[_i]] = [_noSword, _sword];
		_i += 2;
	}
};

init_effect_sprites = function() {
	var _i = 0; repeat (argument_count div 2) {
		var _effect = asset_get_index("sSwordEffect" + argument[_i+1]);
		effectSprites[$ argument[_i]] = _effect;
		_i += 2;
	}
};

get_sprite = function() {
	return sprites[$ fsm.get_current_state()][@ hasSword];
};

check_input = function() {
	with (input) {
		hdir	= max(keyboard_check(ord("D")), keyboard_check(vk_right)) -
				  max(keyboard_check(ord("A")), keyboard_check(vk_left));
		jump	= max(keyboard_check_pressed(ord("W")), keyboard_check_pressed(vk_up));
		attack	= max(keyboard_check_pressed(ord("Z")), keyboard_check_pressed(vk_space));
		throwSword = max(keyboard_check_pressed(ord("E")), keyboard_check_pressed(ord("X")));
		recallSword = max(keyboard_check_pressed(ord("Q")), keyboard_check_pressed(ord("C")));
	}
};

on_ground = function() {
	return (place_meeting(x, y+1, oWall));	
};

apply_gravity = function() {
	vspd = min(vspd+grav, vspdMax);
};

set_movement = function() {
	var _dir = input.hdir;
	hspd = spd * _dir;
	if (_dir != 0) face = _dir;
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

spawn_sword = function() {
	with (instance_create_depth(x+6*face, y-14, depth, oSword)) {
		owner = other.id;
		face  = owner.face;
		fsm.change("spinning");
	}
};

equip_sword = function() {
	hasSword = true;
	sprite_index = get_sprite();
};

recall_sword = function() {
	if (!hasSword and input.recallSword) {
		var _sword = instance_find(oSword, 0);
		_sword.recall();
	}	
};