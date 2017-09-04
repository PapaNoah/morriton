import xmlparser, xmltree, strutils, streams, parsecsv, base64, strtabs
from zip.zlib import uncompress, ZStreamHeader

type
    XMLParseError =  object of Exception
    TmxMapDimensionError = object of Exception
    TmxMapLayerSizeError = object of Exception
    CompressionNotImplementedError = object of Exception
    TmxMissingGidInTileError = object of Exception

type
    Format* {.pure.} = enum XML
    Encoding* {.pure.} = enum CSV = "csv", BASE64 = "base64", NONE = ""
    Orientation* {.pure.} = enum ORTHO = "orthogonal", ISOM = "isometric", STAGG = "staggerd", HEXA = "hexagonal"
    RenderOrder* {.pure.} = enum RIGHTDOWN = "right-down", RIGHTUP = "right-up", LEFTDOWN = "left-down", LEFTUP = "left-up"
    ImageFormat* {.pure.} = enum PNG = "png", GIF = "gif", JPG = "jpg", BMP = "bmp"
    Compression* {.pure.} = enum GZIP = "gzip", ZLIB = "zlib", NONE = ""
    DrawOrder* {.pure} = enum INDEX = "index", TOPDOWN = "topdown"
    TextAlign* {.pure.} = enum CENTER = "center", TOP = "top", LEFT = "left", RIGHT = "right", BOTTOM = "bottom"

const
    newLine = "\n"
    maxWidth = 1024
    maxHeight = 1024
    maxLayers = 64
type
    Parser* = ref object of RootObj
        format: Format
        log: string
    TmxParser* = ref object of Parser
        encoding: Encoding
        errors: seq[string]
    Map = ref object of RootObj
        width, height: uint
        tileWidth, tileHeight: uint
        data: array[0..maxLayers, array[0..maxWidth, array[0..maxHeight, uint]]]
    TmxMap = ref object of Map
        version: string
        orientation: Orientation
        renderOrder: RenderOrder
        layers: seq[string]
    

proc decompressBase64(compressed: string, compression: Compression): string =
    case compression:
        of Compression.GZIP:
            return uncompress(compressed, stream = ZStreamHeader.GZIP_STREAM)
        of Compression.ZLIB:
            return uncompress(compressed, stream = ZStreamHeader.ZLIB_STREAM)
        of Compression.NONE:
            return compressed
        else:
            raise CompressionNotImplementedError.newException("No behavior for compression implemented: %s" % $compression)

proc readBase64(dataNode: XmlNode): seq[uint] =
    result = @[]
    var base64Decompressed: string = dataNode.innerText
    if dataNode.attrs.hasKey("compression"):
        let compression = parseEnum[Compression](dataNode.attr("compression"))
        base64Decompressed = decompressBase64(dataNode.innerText, compression)
    let base64Decoded: string = decode(base64Decompressed)
    for byteIndex in countup(0, len(base64Decoded) - 3, 4):
        var tileId = cast[uint](base64Decoded[byteIndex])
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 1])
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 2])
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 3])
        result.add(tileId)

proc readCSV(dataNode: XmlNode, filename: string): seq[uint] =
    result = @[]
    var
        csvParser: CsvParser
        stringStream = newStringStream(dataNode.innerText)
    csvParser.open(stringStream, filename)
    while csvParser.readRow():
        for tileId in items(csvParser.row):
            result.add(parseUInt(tileId))
    csvParser.close()

proc readXML(dataNode: XmlNode): seq[uint] =
    result = @[]
    for tileNode in dataNode.findAll("tile"):
        if not tileNode.attrs.hasKey("gid"):
            raise TmxMissingGidInTileError.newException("No 'gid' attribute found for tile.")
        result.add(parseUint(tileNode.attr("gid")))

proc parseLayerData(map: var TmxMap, tree: XmlNode) =
    var layerId = 0
    for layerNode in tree.findAll("layer"):
        let data = layerNode.child("data")
        if data.isNil:
            raise XMLParseError.newException("Layer without data tag: layer name is '%s'" % layerNode.tag)
        map.layers.add(layerNode.attr("name"))
        var gidSequence: seq[uint]
        var encoding: Encoding
        var compression: Compression
        if not data.attrs.hasKey("encoding"):
            encoding = Encoding.NONE
        else:
            encoding = parseEnum[Encoding](data.attr("encoding"))
        case encoding:
            of Encoding.NONE:
                gidSequence = readXML(data)
            of Encoding.CSV:
                gidSequence = readCSV(data, data.tag)
            of Encoding.BASE64:
                gidSequence = readBase64(data)
            else:
                raise XMLParseError.newException("Data encoding not recognized: %s" % data.attr("encoding"))
        inc(layerId)
                

        

proc newTmxMap(xmlMap: XmlNode): TmxMap =
    new result
    result.version = xmlMap.attr("version")
    result.width = parseUint(xmlMap.attr("width"))
    result.height = parseUint(xmlMap.attr("height"))
    if result.width > maxWidth.uint or result.height > maxHeight.uint:
        raise TmxMapDimensionError.newException("Map is too big: max 1024x1024 < actual %sx%s" % [$result.width, $result.height])
    result.tileWidth = parseUint(xmlMap.attr("tilewidth"))
    result.tileHeight = parseUint(xmlMap.attr("tileheight"))
    result.orientation = parseEnum[Orientation](xmlMap.attr("orientation"))
    result.renderOrder = parseEnum[RenderOrder](xmlMap.attr("renderorder"))
    let layerLength = len(xmlMap.findAll("layer"))
    if layerLength > maxLayers:
        raise TmxMapLayerSizeError.newException("Too many layers. 64 < %s" % $layerLength)

    for layerNr in 0..maxLayers:
        for mapWidth in 0..maxWidth:
            for mapHeight in 0..maxHeight:
                result.data[layerNr][mapWidth][mapHeight] = 0;
    result.layers = @[]

template echoLine(line: string) =
    echo line & newLine

proc newTmxParser(encoding: Encoding): TmxParser =
    new result
    result.format = Format.XML
    result.encoding = encoding
    result.errors = @[]

proc parseTmxMap(parser: TmxParser, path: string): XmlNode =
    var tree = loadXml(path, parser.errors)
    if len(parser.errors) != 0:
        for error in parser.errors:
            echoLine error
        raise XMLParseError.newException("Error while parsing '" & path & "': XML file not well formed")
    if tree.attr("version") != "1.0": 
        echo "warning: this parser was written for tmx version 1.0. This version is " & tree.attr("version")
    return tree

# var parser = newTmxParser(Encoding.CSV)
# var tree = parser.parseTmxMap("default.tmx")