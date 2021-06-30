var _x = room_width + random_range(0, 100);
var _y = random_range(80, 180);

with (instance_create_layer(_x, _y, "SmallClouds", oCloud)) {
	sprite_index = choose(sSmallCloud1, sSmallCloud2, sSmallCloud3);
	hspeed = -random_range(.2, .4);
}

alarm[0] = irandom_range(5, 15) * game_get_speed(gamespeed_fps);
