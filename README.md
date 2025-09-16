# Game of Life Card
A custom PCB that uses a TI MSP430 MCU to run a finite version of Conway's Game of Life on an ePaper display.
# Documentation
To read about the development of this project, please go to the `gol_card_docs` directory to find many markdown files documenting the development process of this project.
# Building
This project can be built using commit `f857bf72e` of [Zig](https://github.com/ziglang/zig), but should work on Zig 0.14.0.

After cloning this repository and its submodules, you will need to make a change to the `build.zig.zon` of raylib-zig. Change the lines specifying the raylib dependency to:
```
.raylib = .{
    .url = "https://github.com/raysan5/raylib/archive/a1de60f3ba253ce59b2e6fa5cdb69c15eaadc1cb.zip",
    .hash = "1220fe6b72d0e4c4e4d255ea4ee1e8121fc54490a6574c2499fb4ee7e642188e8039",
},
```
Then run `zig build run` to try out the desktop simulator.