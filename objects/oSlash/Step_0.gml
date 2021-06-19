if (animation_end()) instance_destroy();

var _list = ds_list_create();
var _num = instance_place_list(x, y, oSnake, _list, false);

if (_num) {
	for (var i = 0; i < _num; ++i) {
		var _inst = _list[| i];
		if (ds_list_find_index(hitList, _inst) != -1) continue;
		
		_inst.hit(1, (x > owner.x) * 2 - 1);
		ds_list_add(hitList, _inst);
	}
}

ds_list_destroy(_list);