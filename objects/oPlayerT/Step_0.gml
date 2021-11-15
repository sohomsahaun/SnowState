check_input();

fsm.trigger("coyote");
fsm.step();
if (abs(input.hdir)) fsm.trigger("run");
if (input.jump) fsm.trigger("jump");
if (input.throwSword) fsm.trigger("throw");
if (input.attack) fsm.trigger("attack");
fsm.trigger("transition");