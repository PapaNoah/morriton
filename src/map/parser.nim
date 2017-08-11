import xmlparser, xmltree

type
    XMLParseException =  object of Exception
type
    Format* {.pure.} = enum XML
    Encoding* {.pure.} = enum CSV = "csv", BASE64 = "base64", NONE = ""
    Orientation* {.pure.} = enum ORTHO = "orthogonal", ISOM = "isometric", STAGG = "staggerd", HEXA = "hexagonal"
    RenderOrder* {.pure.} = enum RIGHTDOWN = "right-down", RIGHTUP = "right-up", LEFTDOWN = "left-down", LEFTUP = "left-up"
    ImageFormat* {.pure.} = enum PNG = "png", GIF = "gif", JPG = "jpg", BMP = "bmp"
    Compression* {.pure.} = enum GZIP = "gzip", ZLIB = "zlib", NONE = ""
    DrawOrder* {.pure} = enum INDEX = "index", TOPDOWN = "topdown"
    TextAlign* {.pure.} = enum CENTER = "center", TOP = "top", LEFT = "left", RIGHT = "right", BOTTOM = "bottom"

type
    Parser* = ref object of RootObj
        format: Format
        log: string
    TmxParser* = ref object of Parser
        encoding: Encoding
        errors: seq[string]
    Map = ref object of RootObj
        width, height: int
        tileWidth, tileHeight: int
        data: array[int, int]
    TmxMap = ref object of Map
        layers: array

const newLine = "\n"

template echoLine(line: string) =
    echo line & newLine

proc newTmxParser(encoding: Encoding): TmxParser =
    new result
    result.encoding = encoding
    result.errors = @[]

proc parseTmxMap(parser: TmxParser, path: string): XmlNode =
    var tree = loadXml(path, parser.errors)
    if len(parser.errors) != 0:
        for error in parser.errors: 
            echoLine error
        raise XMLParseException.newException("Error while parsing '" & path & "': XML file not well formed")
    return tree

var parser: TmxParser = newTmxParser(Encoding.CSV)
discard parser.parseTmxMap("default.tmx")