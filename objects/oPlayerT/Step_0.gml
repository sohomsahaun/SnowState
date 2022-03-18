check_input();

fsm.trigger("t_coyote");
fsm.step();
if (abs(input.hdir)) fsm.trigger("t_run");
if (input.jump) fsm.trigger("t_jump");
if (input.throwSword) fsm.trigger("t_throw");
if (input.attack) fsm.trigger("t_attack");
fsm.trigger("t_transition");