If you take a look at the source code for this project, you may notice that there is not a single line of C present (at least as of when I wrote this). For a project of this type, that's an unusual occurrence. C is *the* standard language for low-level and embedded programming. C also has some of the best support for cross compilation out there. Since this project aims to share parts of the codebase between the desktop simulator and the embedded microcontroller, this should be all the more reason to use C.

Instead, you will find that this project is written in [Zig](https://ziglang.org/). The creator of this language, Andrew Kelly, [wants it to be a replacement for C](https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html), especially in the areas mentioned previously. I think that Zig is on the right track to reach that goal from what I've seen. I want to go over some of my favorite features of Zig that have led me to try it out and use it in this project.

# Comptime
The C macro system is a very clever way to enable changing code at compile time. Through a series of what are essentially string replacements, a C codebase can be reconfigured with just a few flags at compille time. However, it seems that we can do a lot better than glorified search-and-replace. From what I've heard from others and the little that I have personally seen, dealing with C codebases that use extensive amounts of macros in "hacky" ways is awful.

A related but very different concept is the idea of running code at compile time. I first learned about this concept from [a description of the unreleased Jai language](https://github.com/BSVino/JaiPrimer/blob/master/JaiPrimer.md). This seems incredible at first, but there is really nothing special going on. We already have the ability to compile and run programs. Why not do that recursively? One of my favorite uses for systems like this is creating look-up tables. This way the code to generate the table can stay in the same program (as opposed to having something like a Python script to generate it) while being readable (as opposed to pasting the table into the source file with no explanation).

Here's an example from the program:
```zig
const stateTable = table: {
    var table: [64]u8 = undefined;
    @memset(&table, 0);
    for (0..512) |i| {
        const neighborhood = (i & 1) + ((i >> 1) & 1) + ((i >> 2) & 1) + ((i >> 3) & 1) + ((i >> 5) & 1) + ((i >> 6) & 1) + ((i >> 7) & 1) + ((i >> 8) & 1);
        if (((i >> 4) & 1) > 0) {
            table[i / 8] |= @as(u8, @intFromBool((neighborhood >= 2) and (neighborhood <= 3))) << @as(u3, i & 0x7);
        } else {
            table[i / 8] |= @as(u8, @intFromBool(neighborhood == 3)) << @as(u3, i & 0x7);
        }
    }
    break :table table;
};
```
This table is used to look up the next state of a cell given the cell's current state and those of its neighbors. I talk more about the lookup table system in [11-30-24], but here I want to focus on how I implemented the table using Zig's comptime system. If I was using C, I probably would have written a Python script to compute the table, print it, and manually turn it into a Zig array. This has the disadvantage of looking like a opaque blob to readers and requiring a separate Python script to be included.

The first thing to notice is that this does not look like a normal array initialization. There is no type provided, nor is there a list of elements to include. What is here is a labeled [block](https://ziglang.org/documentation/master/#Blocks). The value of the block will be equal to what is returned using the `break` keyword. The key part is that this does not happen when the program is run. Rather, the compiler will evaluate the code inside of the block, take the value it outputs, and embed it into the program as if we had initialized `stateTable` with that value directly.

The next bonus is that the code in this block, minus the `break` statement. is perfectly normal runtime Zig code. If you wanted, you could take it and paste it in the `main` function and it would word just fine.

# Types
One other use of the comptime system that is not used in this project but is used extensively in the standard library is typing. I am a fan of having types in languages. I much prefer using Typescript over Javascript, and I appreciate type annotations in Python code.

Zig's types follow a simple rule: they only exist at compile time. There is no reflection style type checking of arbitrary values at runtime. If you try to, the compiler will make sure to let you know. But as long as the code you are running stays in compile time, you can do all of the reflection you want. This is actually used one time in the project, albeit in a minor manor.

```zig
var row_idx: u32 = 0;
comptime {
    std.debug.assert((1 << @typeInfo(@TypeOf(row_idx)).int.bits) >= height);
}
```
The variable `row_idx` is used to simulate row-by-row drawing functionality in the desktop hal while actually only drawing once. As such, the specific type of this number is not terribly important. However, the type of the number must be big enough to hold the number of rows of the board (minus 1). With another use of comptime code, we can make sure that the type satisfies this requiement. Inside the `comptime` block, we can perform `@typeInfo(@TypeOf(row_idx)).int.bits`. This gets the type of `row_idx`, which is used to get a struct containing information about it, and then uses that struct to find the number of bits `row_idx` holds.

Another very common use of types is to achieve a system similar to generics in languages like Java. This system relies on two facts:
1. Types can be used as parameters for a function
2. New types can be created and returned from a function
The Zig documentation gives [an example](https://ziglang.org/documentation/master/#struct) of this (do a search for `LinkedList`). In this example, the function `LinkedList` takes in a type at compile time and returns a custom struct type tailored to that data type. This allows one piece of code to be reused for many different types without having to store any type information at runtime.

# Build System
When I've taken a look at C in the past, I've been confused by the number of build systems out there. Judging from what I've seen online, this is a common sentiment. This is why I appreciate languages like Rust and Zig that have one very obvious and almost universally utilized way to build projects. With Zig, your entire project's build is controlled from `build.zig`. Just like comptime, this allows you to use the Zig language itself to help with building your application. 

Zig also has built in dependency management too. While it's not my favorite, it follows the Zig pattern of reusing existing functionality in a clever way. Any dependencies your project needs are listed in `build.zig.zon`. The `zon` stands for Zig Object Notation, which is nearly if not exactly the same syntax that Zig uses for `struct`s. The contents are described in more detail [here](https://github.com/ziglang/zig/blob/master/doc/build.zig.zon.md), but the core is attaching either a URL and hash or a local path to each dependency. I started off using the first method, but had to switch to the second after I needed to manually make the external libraries I was using build with a newer release of Zig.
A very simple solution that gets the job done.

Speaking of the Zig switch, Zig's packaging is also very convenient. Before I upgraded to master, I was just using 0.13.0 provided in Fedora's repos. Here are all the steps I took to switch to a new release of Zig:
1. Download the new version as a prebuilt archive from https://ziglang.org/download/.
2. Decompress the archive into my project.
3. Switch from using `zig` to `./zig-master/zig` to run commands.
That's it. Once I had fixed the very few breaking changes from 0.13.0 to the master branch at the time, everything worked as normal. No convoluted build process, no polluted `PATH`, everything just works. 

The archive from Zig's website for Zig 0.13.0 for x86_64 Linux is 45MiB, and supports building to any supported target on [this table](https://ziglang.org/download/0.13.0/release-notes.html#Tier-3-Support) ([more](https://ziglang.org/learn/overview/), see "Cross-compiling is a first-class use case"). There is no need to rebuild the compiler or download a special version for obscure architectures. It can pull this off by only shipping with the source code for various libraries it needs and only building them for a target when requested.

In addition to being able to cross-compile Zig in this manner, an install of Zig can also serve as a fully featured C compiler. This combination of features has led to some people using Zig as a build system for C projects. Raylib, the C graphics library used in this project, actually supports building in this manner.
# End
If you want to hear more about these features as well as some others, you should watch [this talk](https://www.youtube.com/watch?v=Gv2I7qTux7g) given by Andrew Kelly. Even though it is a few years old, all of the points made still hold up today. 

I view Zig as an effort to update C with all of the knowledge gained in computer science and software engineering over the past half a century. I hope that it will one day gain as much traction as C has now. Because of these new features, and its support for the MSP430 architecture, I have chosen it as the language of choice in this project.