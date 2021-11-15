#macro DEMO "D"		// D = Changing States Directly
					// T = Changing States Using Triggered Transitions

#macro CAM   view_camera[0]					// Main camera view
#macro CAM_W camera_get_view_width(CAM)		// Width of the camera
#macro CAM_H camera_get_view_height(CAM)	// Height of the camera
#macro CAM_X camera_get_view_x(CAM)			// x position of the camera
#macro CAM_Y camera_get_view_y(CAM)			// y position of the camera