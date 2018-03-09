import basic2d, math, times, random, sdl2, xmlparser, xmltree, strtabs, strutils, sdl2.image, base64, tables
import ../src/map/parser
{.experimental.}

var tmxParser: TmxParser = newTmxParser()
var tmxMap: TmxMap = tmxParser.parseTmxMap("../default.tmx")
for layer in tmxMap.data.keys:
    echo layer & " " & $tmxMap.data[layer].len

for group in tmxMap.objectGroups.values:
    for obj in group.objects:
        echo obj.id
        echo obj.objType