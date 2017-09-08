import basic2d, math, times, random, sdl2, xmlparser, xmltree, strtabs, strutils, sdl2.image, base64, tables

let tilesPerRow = 57
let tileSize = (x:16, y:16)

proc arraySolution(input: seq[int]) =

    var map: array[1000, Point2d]

    for i in low(map)..high(map):
        map[i] = point2d(((i mod tilesPerRow) * (tileSize.x + 1)).float, ((i div tilesPerRow) * (tileSize.y + 1)).float)
    
    var tilePos = point2d(0,0)
    for tileNr in input:
        tilePos = map[tileNr]

proc calcSolution(input: seq[int]) = 
    var x = 0
    var y = 0
    for tileNr in input:
        x = (tileNr mod tilesPerRow) * (tileSize.x + 1)
        y = (tileNr div tilesPerRow) * (tileSize.y + 1)

type
    MapMatrix = array[0..10, array[0..10, uint]]
    TestMap = ref object
        data: TableRef[string, MapMatrix]
    LayerEnum {.pure.} = enum GROUND, RUG, WALL, DECO, HIGH
    Map = ref object
        textures: seq[TexturePtr]
        width: int
        height: int
        tileSize: Point
        layers: array[LayerEnum, seq[Point2d]]

proc parseTmxMap(path: string, renderer: RendererPtr) = 
    let xmlMap = loadXml("../falkenstein_1.tmx")
    if not xmlMap.attrs.hasKey("width"):
        echo "Map width not defined"
        quit(QuitFailure)
    elif not xmlMap.attrs.hasKey("height"):
        echo "Map height not defined"
        quit(QuitFailure)
    elif not xmlMap.attrs.hasKey("tilewidth"):
        echo "Tile width not defined"
        quit(QuitFailure)
    elif not xmlMap.attrs.hasKey("tileheight"):
        echo "Tile height not defined"
        quit(QuitFailure)
    
    var map: Map
    new map
    map.width = parseInt(xmlMap.attrs["width"])
    map.height = parseInt(xmlMap.attrs["height"])
    map.tileSize = (parseInt(xmlMap.attrs["tilewidth"]).cint, parseInt(xmlMap.attrs["tileheight"]).cint)

    var tilesets: seq[XmlNode] = @[]
    var layers: seq[XmlNode] = @[]

    xmlMap.findAll("tileset", tilesets)
    for tileset in tilesets:
        map.textures.add(renderer.loadTexture(tileset.attrs["source"]))
    
    xmlMap.findAll("layer", layers)
    for layer in layers:
        var data = layer.child("data")
        case data.attrs["name"]:
        of "ground":
            var groundArray = newSeq[Point2d](map.width*map.height)
            map.layers[LayerEnum.GROUND] = groundArray
        of "rug":
            var rugArray = newSeq[Point2d](map.width*map.height)
            map.layers[LayerEnum.RUG] = rugArray
        of "wall":
            var wallArray = newSeq[Point2d](map.width*map.height)
            map.layers[LayerEnum.WALL] = wallArray
        of "deco":
            var decoArray = newSeq[Point2d](map.width*map.height)
            map.layers[LayerEnum.DECO] = decoArray
        of "high":
            var highArray = newSeq[Point2d](map.width*map.height)
            map.layers[LayerEnum.HIGH] = highArray
        else:
            break

proc decodeBase64(filename: string) =
    var tree = loadXml(filename)
    var layer = tree.child("layer")
    var data = layer.child("data")
    echo data.innerText.len
    var decoded: string = decode(data.innerText)
    var decodedData: seq[uint] = @[]
    for str in countup(0, len(decoded)-3, 4):
        var result = cast[uint](decoded[str])
        result = result or cast[uint](decoded[str+1]) shl 8
        result = result or cast[uint](decoded[str+2]) shl 16
        result = result or cast[uint](decoded[str+3]) shl 24
        decodedData.add(result)
    echo decodedData

proc initMapMatrix(): MapMatrix =
    return result
    # for w in 0..result.len - 1:
    #     for h in low(result[w])..high(result[w]):
    #         result[w][h] = 0

proc `$`(matrix: MapMatrix): string =
    result = ""
    for w in low(matrix)..high(matrix):
        for h in low(matrix[w])..high(matrix[w]):
            result &= $matrix[w][h] & ","


# # Initialization
# const max = 1000
# const N = 10000000
# var input: seq[int] = newSeq[int](N)

# for i in 0..N-1:
#     input[i] = random(max)

# var t = cpuTime()
# arraySolution(input)
# echo "Time arraySolution: ", cpuTime() - t

# t = cpuTime()
# calcSolution(input)
# echo "Time calcSolution: ", cpuTime() - t
# decodeBase64("../default.tmx")
var 
    table = newTable[string, MapMatrix]()
    matrix: MapMatrix
    sequence: seq[string]

sequence = newSeq[string]()
sequence.add("F")
sequence.add("A")
sequence.add("B")
sequence.add("I")