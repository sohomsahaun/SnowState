// Stay in the correct layer
if (layer_exists("Controllers")) layer = layer_get_id("Controllers");

width = 480;
height = 270;

targetPos = [x,y];
targetInst = (DEMO == "D") ? oPlayerD : oPlayerT;
rate = 2;

// Resize window and app surface
scale = 2;
var _width = width*scale, _height = height*scale;
window_set_size(_width, _height);
surface_resize(application_surface, _width, _height);
display_set_gui_size(_width, _height);

// Resize camera
camera_set_view_size(CAM, width, height);

// Room settings
view_enabled = true;
view_visible[0] = true;

// Center Window
alarm[0] = 1;

// State Machine
fsm = new SnowState("instance");

fsm
	.add("instance", {
		step: function() {
			var _targ = targetInst;
			if (!instance_exists(_targ)) return;
			
			var _cw = CAM_W, _ch = CAM_H;
			var _rate = rate;
			
			x = clamp(_targ.x-_cw/2., 0, room_width -_cw);
			y = clamp(_targ.y-_ch/2., 0, room_height-_ch);
			
			camera_set_view_pos(CAM, lerp_smooth(CAM_X, x, _rate),
									 lerp_smooth(CAM_Y, y, _rate));
		}
	});
