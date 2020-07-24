<h1 align="center">SnowState 1.0.0</h1>
<p align="center">@sohomsahaun</p>
<p align="center">Quick links: <a href="https://sahaun.itch.io/snowstate">itch</a></p>

---

**SnowState** is a robust finite state machine for GameMaker Studio 2.3+. It's easy to set up and keeps the code neat and organized. No more managing a thousand different scripts for an object, it's all in one place!

You only need the `SnowState` script for your game. This repository contains a demo project demonstrating the basics of SnowState.

&nbsp;

<p align="center">
  <img src="https://user-images.githubusercontent.com/27750907/88289811-a1c1dc80-cd17-11ea-81b2-7e3e63d81768.gif">
</p>


## Usage 

* Copy the `SnowState` script in your game.

* In the Create event of an object, create a variable holding a new instance of `StateMachine`. You need to define the initial state for the state machine, and then declare the state names and their behavior.

```gml
// This is a part of the state machine for oSnake in the demo

state = new StateMachine("walk",
  "walk", {
    enter: function() {
      sprite_index = sSnakeWalk;
      image_index = 0;
      hspd = spd*image_xscale;
    },
    step: function() {
      if (place_meeting(x+hspd, y, oWall) || (!place_meeting(x+sprite_width/2, y+1, oWall))) flip();
      if (on_ground()) move_and_collide();
        else state_switch("falling");
    }
  },
  "falling", {
    enter: function() {
      sprite_index = sSnakeFall;
      image_index = 0;
      hspd = 0;
    },
    step: function() {
      apply_gravity();
      if (on_ground()) state_switch("walk");
    }
  }
);
```

Alternatively:
```gml
// This is a part of the state machine for oSnake in the demo

state = new StateMachine("walk");
state.add("walk", {
    enter: function() {
      sprite_index = sSnakeWalk;
      image_index = 0;
      hspd = spd*image_xscale;
    },
    step: function() {
      if (place_meeting(x+hspd, y, oWall) || (!place_meeting(x+sprite_width/2, y+1, oWall))) flip();
      if (on_ground()) move_and_collide();
        else state_switch("falling");
    }
});
state.add("falling", {
  enter: function() {
    sprite_index = sSnakeFall;
    image_index = 0;
    hspd = 0;
  },
  step: function() {
    apply_gravity();
    if (on_ground()) state_switch("walk");
  }
});
```

* In the Step event of the object, call:
```gml
state.step();
```

* In the Draw event of the object, call:
```gml
state.draw();
```

Aaaaand that's it!

&nbsp;
&nbsp;

## Documentation
To know the available functions/structs and their usage, visit the [Wiki](https://github.com/sohomsahaun/SnowState/wiki)!
