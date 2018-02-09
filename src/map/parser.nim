import xmlparser, xmltree, strutils, streams, parsecsv, base64, strtabs, tables, colors
from zip.zlib import uncompress, ZStreamHeader

type
    XMLParseError =  object of XmlError
    TmxMapDimensionError = object of Exception
    TmxMapLayerSizeError = object of Exception
    TmxMapVersionMismatchError = object of Exception
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
    version = "1.0"

type
    MapMatrix = ref array[0..maxWidth, array[0..maxHeight, uint]]

    MapObject* = ref object of RootObj
        id*: uint
        name*: string
        objType*: string
    GeneralObject* = ref object of MapObject
        x: uint
        y: uint
        width: int
        height: int
        rotation: float
        gid: uint
        visible: bool
        tid: uint
    ObjectGroup* = ref object of RootObj
        name: string
        objects*: seq[MapObject]
        color: Color
        opacity: bool
        visible: bool
        offsetx: float
        offsety: float
        drawOrder: DrawOrder
    TextObject = ref object of MapObject
        fontfamily: string
        pixelsize: uint
        wrap: bool
        color: Color
        bold: bool
        italic: bool
        underline: bool
        strikeout: bool
        kerning: bool
        halign: TextAlign
        valign: TextAlign

type
    Parser* = ref object of RootObj
        format: Format
        log: string
    TmxParser* = ref object of Parser
    Map* = ref object of RootObj
        width, height: uint
        tileWidth, tileHeight: uint
        data*: Table[string, MapMatrix]
        objectGroups*: Table[string, ObjectGroup]
    TmxMap* = ref object of Map
        version*: string
        orientation*: Orientation
        renderOrder*: RenderOrder
        layers*: seq[string]
    

proc loadXmlFromFile(path: string): XmlNode
proc verifyTmxVersion(rootNode: XmlNode)
proc newTmxParser(): TmxParser
proc newTmxMap(xmlMap: XmlNode): TmxMap
proc newObjectGroup(groupNode: XmlNode): ObjectGroup
proc newGeneralObject(objectNode: XmlNode): GeneralObject
proc getNameOrDefault(nodeAttributes: XmlAttributes, default: string): string
proc parseObjectGroups(map: var TmxMap, tree: XmlNode)
proc parseLayerData(map: var TmxMap, tree: XmlNode)
proc parse(parser: TmxParser, path: string): TmxMap

proc parse(parser: TmxParser, path: string): TmxMap =
    var 
        xmlTree: XmlNode = loadXmlFromFile(path)
    verifyTmxVersion(xmlTree)
    var map: TmxMap = newTmxMap(xmlTree)
    map.parseObjectGroups(xmlTree)
    map.parseLayerData(xmlTree)
    return map

proc loadXmlFromFile(path: string): XmlNode =
    try:
        var rootNode = loadXml(path)
        return rootNode
    except XmlError:
        echo "loading map did not work"
    finally:
        raise newException(XMLParseError, "")

proc verifyTmxVersion(rootNode: XmlNode) =
    if(rootNode.attr("version") != version):
        raise newException(TmxMapVersionMismatchError, rootNode.attr("version") & " did not match expected version " & version)
    
proc newTmxParser(): TmxParser =
    new result
    result.format = Format.XML

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
    result.data = initTable[string, MapMatrix]()
    result.objectGroups = initTable[string, ObjectGroup]()
    result.layers = @[]

proc parseObjectGroups(map: var TmxMap, tree: XmlNode) =
    for groupIndex, objectGroupNode in tree.findAll("objectgroup"):
        let name = objectGroupNode.attrs.getNameOrDefault($groupIndex)
        var objectGroup: ObjectGroup = newObjectGroup(objectGroupNode)
        map.objectGroups[name] = objectGroup

proc getNameOrDefault(nodeAttributes: XmlAttributes, default: string): string =
    if nodeAttributes.isNil or not nodeAttributes.hasKey("name"):
        return default
    else:
        return nodeAttributes["name"]

proc newObjectGroup(groupNode: XmlNode): ObjectGroup =
    new result
    let attributes = if groupNode.attrs.isNil: newStringTable(modeCaseInsensitive) else: groupNode.attrs
    result.name = attributes.getOrDefault("name", "")
    result.opacity = parseBool(attributes.getOrDefault("opacity", "true"))
    result.visible = parseBool(attributes.getOrDefault("visible", "true"))
    result.offsetx = parseFloat(attributes.getOrDefault("offsetx", "0.0"))
    result.offsety = parseFloat(attributes.getOrDefault("offsety", "0.0"))
    result.drawOrder = parseEnum[DrawOrder](attributes.getOrDefault("draworder", $DrawOrder.TOPDOWN))
    result.objects = newSeq[MapObject]()
    for objectNode in groupNode.findAll("object"):
        result.objects.add(newGeneralObject(objectNode))

proc newGeneralObject(objectNode: XmlNode): GeneralObject =
    new result
    template attributes: untyped = objectNode.attrs
    result.id = parseUInt(attributes["id"])
    result.name = attributes.getOrDefault("name", "")
    result.objType = attributes.getOrDefault("type", "")
    result.x = parseUInt(attributes["x"])
    result.y = parseUInt(attributes["y"])
    result.width = parseInt(attributes.getOrDefault("width", "0"))
    result.height = parseInt(attributes.getOrDefault("height", "0"))
    result.rotation = parseFloat(attributes.getOrDefault("rotation", "0.0"))
    result.gid = parseUInt(attributes.getOrDefault("gid", "0"))
    result.visible = parseBool(attributes.getOrDefault("visible", "true"))
    result.tid = parseUInt(attributes.getOrDefault("tid", "0"))


proc parseLayerData(map: var TmxMap, tree: XmlNode) =
    for layerNode in tree.findAll("layer"):
        let data = layerNode.child("data")
        if data.isNil:
            raise XMLParseError.newException("Layer without data tag: layer name is '%s'" % layerNode.tag)
        let layerName = layerNode.attr("name")
        var gidSequence: seq[uint] = @[]
        var encoding: Encoding
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
        map.fillLayerData(layerName, gidSequence)

        


proc decompressBase64(compressed: string, compression: Compression): string =
    case compression:
        of Compression.GZIP:
            echo uncompress(compressed, stream = ZStreamHeader.DETECT_STREAM)
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
        # https://github.com/nim-lang/zip/issues/23 temporary solution
        raise CompressionNotImplementedError.newException("decompression not implemented")
        # let compression = parseEnum[Compression](dataNode.attr("compression"))
        # base64Decompressed = decompressBase64(dataNode.innerText, compression)
        # echo base64Decompressed
    let base64Decoded: string = decode(base64Decompressed)
    for byteIndex in countup(0, len(base64Decoded) - 3, 4):
        var tileId = cast[uint](base64Decoded[byteIndex])
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 1]) shl 8
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 2]) shl 16
        tileId = tileId or cast[uint](base64Decoded[byteIndex + 3]) shl 24
        result.add(tileId)
    return result

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


proc initMapMatrix(): MapMatrix =
    new result

proc fillLayerData*(map: var TmxMap, layer: string, gidSequence: seq[uint]) =

    map.data.add(layer, initMapMatrix())

    let layerData = map.data[layer]
    var gidIndex: int = 0
        
    for height in 0..map.height - 1:
        for width in 0..map.width - 1:
            layerData[width][height] = gidSequence[gidIndex]
            inc(gidIndex)
    

template echoLine(line: string) =
    echo line & newLine
