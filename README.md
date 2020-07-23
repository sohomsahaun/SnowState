<h1 align="center">SnowState 1.0.0</h1>
<p align="center">@sohomsahaun</p>
<p align="center">Quick links: <a href="https://sahaun.itch.io/snowstate">itch</a></p>

---

**SnowState** is a powerful and organized finite state machine for GameMaker Studio 2.3+. 

You only need the `SnowState` script for your game. This repository contains a demo project demonstrating the basics of SnowState.

<p align="center">
  <img src="https://user-images.githubusercontent.com/27750907/88289811-a1c1dc80-cd17-11ea-81b2-7e3e63d81768.gif">
</p>


# Usage 

In the Create event of an object, create a variable holding a new instance of `StateMachine`. You need to define the initial state for the state machine, and then declare the state behavior.
You can do either of the following:

```gml
state = new StateMachine("idle",
  "idle", {
    enter: function() {},
    step : function() {},
    draw : function() {},
    leave: function() {}
  }
);
```
```gml
state = new StateMachine("idle");
state.add("idle", {
    enter: function() {},
    step : function() {},
    draw : function() {},
    leave: function() {}
  });
```

In the Step event, call:
```gml
state.step();
```

In the Draw event, call:
```gml
state.draw();
```

Aaaaand that's it!


To know the available functions/structs and their usage, visit the [Wiki](https://github.com/sohomsahaun/SnowState/wiki)!
