# morriton
A rougelike adventure game based on a [pen and paper adventure](https://www.youtube.com/watch?v=bdoMeomazZQ) written in [Nim](http://nim-lang.org) using [SDL2](https://www.libsdl.org/) with the [nim sdl wrapper](https://github.com/nim-lang/sdl2).

## Requirements

* Nim - [https://nim-lang.org/install.html](https://nim-lang.org/install.html)
* SDL2 development binaries - [https://wiki.libsdl.org/Installation](https://wiki.libsdl.org/Installation)
* Git - [https://git-scm.com/downloads](https://git-scm.com/downloads)
* Mercurial (for nim package _strfmt_) - [https://www.mercurial-scm.org/downloads](https://www.mercurial-scm.org/downloads)
* Extra Nim packages (install using **nimble**)
  * sdl2 (**git** needed)
  * strfmt (**mercurial** needed)
* Tiled (map creator) - [http://www.mapeditor.org/](http://www.mapeditor.org/)

## Documentation (Third Party)

* Nim manual - [https://nim-lang.org/docs/manual.html](https://nim-lang.org/docs/manual.html)
* SDL2 wiki - [https://wiki.libsdl.org](https://wiki.libsdl.org/)
* TMX tilemap format (Tiled) - [http://doc.mapeditor.org/reference/tmx-map-format/](http://doc.mapeditor.org/reference/tmx-map-format/)
* Nim style guide - [https://nim-lang.org/docs/nep1.html](https://nim-lang.org/docs/nep1.html)
* Hookrace tutorial (Inspiration) - [https://hookrace.net/blog/writing-a-2d-platform-game-in-nim-with-sdl2/](https://hookrace.net/blog/writing-a-2d-platform-game-in-nim-with-sdl2/)

## Installation

Once Nim is installed, navigate to the `src/` folder using a terminal or command line tool like `cmd` or `powershell` in Windows. Execute the following command:

```
\src> nim c -d:release --app:gui main.nim
```

If it compiled successfully, the `main.exe` was created within the `src/` folder. Double click on the executable and the game will start!