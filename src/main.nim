import basic2d, strutils, times, math, strfmt
import sdl2, sdl2.image, sdl2.ttf
import utils

type 
    SDLException = object of Exception
type
    Input {.pure.} = enum none, left, right, up, down, restart, quit, action
    Collision {.pure.} = enum x, y, corner
    Direction {.pure.} = enum stand, left, right, up
    
    Time = ref object
        begin, finish, best: int

    Player = ref object
        texture: TexturePtr
        direction: Direction
        pos: Point2d
        vel: Vector2d
        time: Time
        action: bool

    Map = ref object
        texture: TexturePtr
        width, height: int
        tiles: seq[uint16]

    Game = ref object
        inputs: array[Input, bool]
        renderer: RendererPtr
        font: FontPtr
        player: Player
        map: Map
        objects: Map
        camera: Vector2d
    
    CacheLine = object
        texture: TexturePtr
        w, h: cint
    
    TextCache = ref object
        text: string
        cache: array[2, CacheLine]

const
    tilesPerRow = 57
    tileSize: Point = (16.cint, 16.cint)
    windowSize: Point = (1280.cint, 720.cint)
    playerSize = vector2d(16, 16)
    start = 78
    finish = 110
    ground = {5, 6, 7, 8, 9, 62, 63, 64, 65, 66, 119, 120, 121, 122, 123, 124, 176, 177, 178, 179, 180, 233, 234, 235, 236, 237, 290, 291, 292, 293, 294, 347, 348, 349, 350, 351, 456, 457, 513, 514, 515, 516, 517, 541, 542, 543, 544, 570, 571, 572, 573, 574, 627, 628, 629, 630, 631}

proc restartPlayer(player: Player)
proc triggerAction(game: Game, pos: Point2d)

proc newTextCache(): TextCache =
    new result

proc newTime(): Time =
    new result
    result.finish = -1
    result.best = -1

proc newPlayer(texture: TexturePtr): Player =
    new result
    result.texture = texture
    result.time = newTime()
    result.restartPlayer()

proc newMap(texture: TexturePtr, file: string): Map =
    new result
    result.texture = texture
    result.tiles = @[]

    for line in file.lines:
        var width = 0
        for word in line.split(' '):
            if word == "": continue
            let value = parseUInt(word)
            if value > uint(uint16.high):
                raise ValueError.newException("Invalid value " & word & " in line " & line)
            result.tiles.add(value.uint16)
            inc(width)
        if result.width > 0 and result.width != width:
            raise ValueError.newException("Incompatible line length in " & file)
        result.width = width
        inc(result.height)

proc newGame(renderer: RendererPtr): Game =
    new result
    result.renderer = renderer
    
    when defined(bold):
        result.font = openFont("fonts/Lato-Bold.ttf", 28)
    elif defined(heavy):
        result.font = openFont("fonts/Lato-Heavy.ttf", 28)
    elif defined(thin):
        result.font = openFont("fonts/Lato-Thin.ttf", 28)
    else:
        result.font = openFont("fonts/Lato-Regular.ttf", 28)
    sdlFailIf(result.font.isNil): "Failed to load font"

    result.player = newPlayer(renderer.loadTexture("img/character.png"))
    result.map = newMap(renderer.loadTexture("img/tilemap.png"), "default.map")
    result.objects = newMap(renderer.loadTexture("img/tilemap.png"), "default_objects.map")

proc restartPlayer(player: Player) =
    player.pos = point2d(0, 0)
    player.vel = vector2d(0, 0)
    player.time.finish = -1
    player.time.begin = -1
    player.direction = Direction.stand

proc toInput(key: Scancode): Input =
    case key
    of SDL_SCANCODE_A: Input.left
    of SDL_SCANCODE_D: Input.right
    of SDL_SCANCODE_W: Input.up
    of SDL_SCANCODE_S: Input.down
    of SDL_SCANCODE_R: Input.restart
    of SDL_SCANCODE_Q: Input.quit
    of SDL_SCANCODE_SPACE: Input.action
    else: Input.none

proc handleInput(game: Game) =
    var event = defaultEvent
    while pollEvent(event):
        case event.kind
        of QuitEvent:
            game.inputs[Input.quit] = true
        of KeyDown:
            game.inputs[event.key.keysym.scancode.toInput] = true
        of KeyUp:
            game.inputs[event.key.keysym.scancode.toInput] = false
        else:
            discard

template renderTextCached(game: Game, text: string, x, y: cint, color: Color) =
    block:
        var tc {.global.} = newTextCache()
        game.renderText(text, x, y, color, tc)

proc renderText(renderer: RendererPtr, font: FontPtr, text: string, x, y, outline: cint, color: Color): CacheLine =
    font.setFontOutline(outline)
    let surface = font.renderUtf8Blended(text.cstring, color)
    sdlFailIf(surface.isNil): "Could not render text surface"

    discard surface.setSurfaceAlphaMod(color.a)

    result.w = surface.w
    result.h = surface.h
    result.texture = renderer.createTextureFromSurface(surface)

    sdlFailIf(result.texture.isNil): "Could not create texture from rendered text"

    surface.freeSurface()

proc renderText(game: Game, text: string, x, y: cint, color: Color, tc: TextCache) =
    let passes = [(color: color(0, 0, 0, 64), outline: 2.cint), (color: color, outline: 0.cint)]

    if text != tc.text:
        for i in 0..1:
            tc.cache[i].texture.destroy()
            tc.cache[i] = game.renderer.renderText(game.font, text, x, y, passes[i].outline, passes[i].color)
        tc.text = text
    
    for i in 0..1:
        var source = rect(0, 0, tc.cache[i].w, tc.cache[i].h)
        var dest = rect(x - passes[i].outline, y - passes[i].outline, tc.cache[i].w, tc.cache[i].h)
        game.renderer.copyEx(tc.cache[i].texture, source, dest, angle = 0.0, center = nil)

proc getTile(map: Map, x, y: int): uint16 =
    let
        nx = clamp(x div tileSize.x, 0, map.width - 1)
        ny = clamp(y div tileSize.y, 0, map.height - 1)
        pos = ny * map.width + nx
    map.tiles[pos]

proc getTile(map: Map, point: Point2d): uint16 =
    map.getTile(point.x.round.int, point.y.round.int)

proc isSolid(map: Map, x, y: int): bool =
    map.getTile(x,y) notin ground

proc isSolid(map: Map, point: Point2d): bool =
    map.isSolid(point.x.round.int, point.y.round.int)

proc testBox(map: Map, pos: Point2d, size: Vector2d): bool =
    let size = 0.5 * size
    result =
        map.isSolid(point2d(pos.x, pos.y)) or
        map.isSolid(point2d(pos.x + 2*size.x - 2, pos.y)) or
        map.isSolid(point2d(pos.x, pos.y + 2*size.y - 2)) or
        map.isSolid(point2d(pos.x + 2*size.x - 2, pos.y + 2*size.y - 2))

proc moveBox(map: Map, pos: var Point2d, vel: var Vector2d, size: Vector2d): set[Collision] {.discardable.} =
    let 
        distance = vel.len
        maximum = distance.int

    if distance < 0: return

    let fraction = 1.0 / float(maximum+1)

    for i in 0 .. maximum:
            var newPos = pos + vel * fraction
            if map.testBox(newPos, size):
                var hit = false
                if map.testBox(point2d(pos.x, newPos.y), size):
                    result.incl(Collision.y)
                    newPos.y = pos.y
                    vel.y = 0
                    hit = true

                if map.testBox(point2d(newPos.x, pos.y), size):
                    result.incl(Collision.x)
                    newPos.x = pos.x
                    vel.x = 0
                    hit = true
                
                if not hit:
                    result.incl(Collision.corner)
                    newPos = pos
                    vel = vector2d(0, 0)
            pos = newPos

proc logic(game: Game, tick: int) =
    template time: untyped = game.player.time
    case game.map.getTile(game.player.pos)
    of start:
        time.begin = tick
    of finish:
        if time.begin >= 0:
            time.finish = tick - time.begin
            time.begin = -1
            if time.best < 0 or time.finish < time.best:
                time.best = time.finish
            echo "Finished in ", formatTime(time.finish)
    else:
        discard
    
    if game.inputs[Input.action] and game.player.action == false:
        game.player.action = true
    
proc triggerAction(game: Game, pos: Point2d) =
    let tile = game.objects.getTile(pos)
    case tile
    of 731:
        game.renderTextCached("Oh look! I found the key to the castle.", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 730, 729, 732:
        game.renderTextCached("Hmm... Nothing here but old books", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 21:
        game.renderTextCached("Sign: To the fountain...", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 425:
        game.renderTextCached("A bottle of water. Probably to water the plants", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 230, 288, 232, 174:
        game.renderTextCached("Beautiful fountain. It must be fun to swim in here", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 401, 403, 459, 345:
        game.renderTextCached("Nice flowers, altough I only like edible ones", 50.cint, 50.cint, color(255, 255, 255, 255))
    of 539:
        game.renderTextCached("What is the cactus doing here?", 50.cint, 50.cint, color(255, 255, 255, 255))
    else:
        game.player.action = false


proc renderTee(renderer: RendererPtr, player: Player, campos: Vector2d) =
    let
        pos = player.pos - campos
        x: cint = pos.x.cint
        y: cint = pos.y.cint
    var source: Rect
    case player.direction
    of Direction.stand:
        source = rect(0, 0, 16, 16)
    of Direction.right:
        source = rect(17, 0, 14, 16)
    of Direction.left:
        source = rect(32, 0, 14, 16)
    else:
        source = rect(47 , 0, 16, 16)
    var dest: Rect = rect(x, y, source.w, 16)

    renderer.copyEx(player.texture, source, dest, angle = 0.0, center = nil, flip = SDL_FLIP_NONE)

proc moveCamera(game: Game) =
    const halfWin = float(windowSize.x div 2)
    const halfWinY = float(windowSize.y div 2)
    when defined(fluidCamera):
        let dist = game.camera.x - game.player.pos.x + halfWin
        game.camera.x -= 0.05 * dist
    elif defined(innerCamera):
        let
            leftArea = game.player.pos.x - halfWin - 150
            rightArea = game.player.pos.x - halfWin + 150
            topArea = game.player.pos.y - halfWinY - 150
            bottomArea = game.player.pos.y - halfWinY + 150
        game.camera.x = clamp(game.camera.x, leftArea, rightArea)
        game.camera.y = clamp(game.camera.y, topArea, bottomArea)
    else:
        game.camera.x = game.player.pos.x - halfWin
        game.camera.y = game.player.pos.y - halfWinY

proc renderMap(renderer: RendererPtr, map: Map, camera: Vector2d) =
    var
        clip = rect(0, 0, tileSize.x, tileSize.y)
        dest = rect(0, 0, tileSize.x, tileSize.y)
    
    for i, tileNr in map.tiles:
        clip.x = cint(tileNr mod tilesPerRow) * (tileSize.x + 1)
        clip.y = cint(tileNr div tilesPerRow) * (tileSize.y + 1)
        dest.x = cint(i mod map.width) * tileSize.x - camera.x.cint
        dest.y = cint(i div map.width) * tileSize.y - camera.y.cint

        renderer.copy(map.texture, unsafeAddr clip, unsafeAddr dest)

proc renderObjects(renderer: RendererPtr, map: Map, camera: Vector2d) =
    var
        clip = rect(0, 0, tileSize.x, tileSize.y)
        dest = rect(0, 0, tileSize.x, tileSize.y)
    
    for i, tileNr in map.tiles:
        if tileNr == 5 or tileNr == 6: continue
        clip.x = cint(tileNr mod tilesPerRow) * (tileSize.x + 1)
        clip.y = cint(tileNr div tilesPerRow) * (tileSize.y + 1)
        dest.x = cint(i mod map.width) * tileSize.x - camera.x.cint
        dest.y = cint(i div map.width) * tileSize.y - camera.y.cint

        renderer.copy(map.texture, unsafeAddr clip, unsafeAddr dest)


proc render(game: Game, tick: int) =
    game.renderer.clear()
    game.renderer.renderMap(game.map, game.camera)
    game.renderer.renderObjects(game.objects, game.camera)
    game.renderer.renderTee(game.player, game.camera)

    let time = game.player.time
    const white = color(255, 255, 255, 255)
    if time.begin >= 0:
        game.renderTextCached(formatTime(tick - time.begin), 50, 100, white)
    elif time.finish >= 0:
        game.renderTextCached("Finished in: " & formatTimeExact(time.finish), 50, 100, white)
    
    if time.best >= 0:
        game.renderTextCached("Best time: " & formatTimeExact(time.best), 50, 150, white)

    if game.player.action:
        let size = playerSize / 2
        case game.player.direction
        of Direction.stand:
            game.triggerAction(game.player.pos + size + vector2d(0, playerSize.y))
        of Direction.up:
            game.triggerAction(game.player.pos + size + vector2d(0, -playerSize.y))
        of Direction.left:        
            game.triggerAction(game.player.pos + size + vector2d(-playerSize.x, 0))
        of Direction.right:
            game.triggerAction(game.player.pos + size + vector2d(playerSize.x, 0))
        else:
            discard

    game.renderer.present()


proc physics(game: Game) =
    if game.inputs[Input.restart]:
        game.player.restartPlayer()

    if game.inputs[Input.left]: game.player.direction = Direction.left
    elif game.inputs[Input.right]: game.player.direction = Direction.right
    elif game.inputs[Input.up]: game.player.direction = Direction.up
    elif game.inputs[Input.down]: game.player.direction = Direction.stand
    
    let horizontal = game.inputs[Input.right].int - game.inputs[Input.left].int
    let vertical = (game.inputs[Input.down].int - game.inputs[Input.up].int) * (1 - horizontal.abs)

    game.player.vel.x = 1.5 * horizontal.float
    game.player.vel.y = 1.5 * vertical.float
    
    game.objects.moveBox(game.player.pos, game.player.vel, playerSize)

proc main =
    sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)): "SDL initialization failed"

    defer: sdl2.quit()

    sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
        "Linear texture filtering could not be enabled"
    
    let window = createWindow(title = "Was geschah auf Morriton Manor?", x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED, w = 1280, h = 720, flags =  SDL_WINDOW_SHOWN)
    
    sdlFailIf(window.isNil): "Window could not be created"
    defer: window.destroy()

    let renderer = window.createRenderer(index = -1, flags = Renderer_Accelerated or Renderer_PresentVsync)
    
    sdlFailIf(renderer.isNil): "Renderer could not be created"
    defer: renderer.destroy()

    sdlFailIf(ttfInit() == SdlError): "SDL2 TTF initialization failed"
    defer: ttfQuit()

    const imgFlags = IMG_INIT_PNG
    sdlFailIf(image.init(imgFlags) != imgFlags):
        "SDL2 image initialization failed"

    renderer.setDrawColor(r = 110, g = 132, b = 174)

    var
        game = newGame(renderer)
        startTime = epochTime()
        lastTick = 0


    while not game.inputs[Input.quit]:
        game.handleInput()
        
        let newTick = int((epochTime() - startTime) * 50)
        for tick in lastTick+1..newTick:
            game.physics()
            game.moveCamera()
            game.logic(tick)
        lastTick = newTick

        game.render(lastTick)

main()