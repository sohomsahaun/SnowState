check_input();

if (abs(input.hdir)) fsm.trigger("run");
if (input.jump) fsm.trigger("jump");
if (input.attack) fsm.trigger("attack");
if (input.throwSword) fsm.trigger("throw");

fsm.trigger("cyote");
fsm.step();
fsm.trigger("transition");



