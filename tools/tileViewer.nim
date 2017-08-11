import iup, sdl2.image, sdl2, strutils

discard open(nil, nil)

const tilesPerRow = 57

proc txt_ValueChange(ih: PIhandle): cint {.cdecl.}
proc tileNumber2Pos(tileNr: int): tuple[x: cint, y: cint]
proc newImageLabel(surface: SurfacePtr): PIhandle

var 
    titleLabel = label("Morriton Tile Viewer")
    idInput = iup.text(nil)
    imageMainLabel = iup.label("main")
    imageLeft1Label = iup.label("left1")
    imageLeft2Label = iup.label("left2")
    imageRight1Label = iup.label("right1")
    imageRight2Label = iup.label("right2")

    labelArr: array[-2..2, PIhandle] = [-2: imageLeft1Label, -1:imageLeft2Label, 0:imageMainLabel, 1:imageRight1Label, 2:imageRight2Label]
    tileNumberLabels: array[-2..2, PIhandle] = [label(""), label(""), label(""), label(""), label("")]
    vBoxArr: array[-2..2, PIhandle] = [
        vbox(tileNumberLabels[-2], labelArr[-2], nil),
        vbox(tileNumberLabels[-1], labelArr[-1], nil),
        vbox(tileNumberLabels[0], labelArr[0], nil),
        vbox(tileNumberLabels[1], labelArr[1], nil),
        vbox(tileNumberLabels[2], labelArr[2], nil)
    ]
    imageBox = iup.hbox(vBoxArr[-2], vBoxArr[-1], vBoxArr[0], vBoxArr[1], vBoxArr[2], nil)
    inputBox = iup.vbox(titleLabel, imageBox, idInput, nil)
    dialog = iup.dialog(inputBox)
    tileMap = image.load("img/tilemap.png")
    srcR: ptr Rect = cast[ptr Rect](alloc(sizeof(Rect)))
    cut = image.load("img/cutout.png")
    clean = sdl2.createRGBSurface(0, 128, 128, 32, 255.uint32, 65280.uint32, 16711680.uint32, 0)
    tileImages: array[-2..2, PIhandle] = [-2:newImageLabel(cut), -1:newImageLabel(cut), 0:newImageLabel(cut), 1:newImageLabel(cut), 2:newImageLabel(cut)]
    tileNumber = 0

let destR: ptr Rect = cast[ptr Rect](alloc(sizeof(Rect)))
destR[] = rect(0.cint,0.cint,128.cint,128.cint)

proc main() =
    setCallback(idInput, "VALUECHANGED_CB", cast[Icallback](txt_ValueChange))
    setAttribute(idInput, "SPIN", "YES")
    setAttribute(idInput, "SPINMAX", "1766")
    setAttribute(idInput, "FILTER", "NUMBER")
    setAttribute(idInput, "NC", "10")
    setAttribute(idInput, "VISIBLECOLUMNS", "10")

    setAttribute(inputBox, "ALIGNMENT", "ACENTER")
    setAttribute(inputBox, "GAP", "15x15")
    setAttribute(inputBox, "MARGIN", "15x15")

    setAttribute(titleLabel, "FONT", "Helvetica, 20")

    for box in vBoxArr:
        setAttribute(box, "ALIGNMENT", "ACENTER")
    for label in tileNumberLabels:
        setAttribute(label, "FONT", "Helvetica, 14")


    setAttributeHandle(imageMainLabel, "IMAGE", tileImages[0])
    setAttributeHandle(imageLeft1Label, "IMAGE", tileImages[-1])
    setAttributeHandle(imageLeft2Label, "IMAGE", tileImages[-2])
    setAttributeHandle(imageRight1Label, "IMAGE", tileImages[1])
    setAttributeHandle(imageRight2Label, "IMAGE", tileImages[2])


    discard showXY(dialog, IUP_CENTER, IUP_CENTER)
    discard mainLoop()
    iup.close()


proc txt_ValueChange(ih: PIhandle): cint =
    let textValue = $getAttribute(idInput, "VALUE")
    if textValue == "": return 0

    tileNumber = strutils.parseInt(textValue)
    for labelNr in low(labelArr)..high(labelArr):
        iup.destroy(tileImages[labelNr])
        let (x,y) = tileNumber2Pos(clamp(tileNumber + labelNr, 0, 1766))
        srcR[] = rect(x, y, 16, 16)
        clean.blitSurface(destR, cut, destR)
        tileMap.blitScaled(srcR, cut, destR)

        tileImages[labelNr] = newImageLabel(cut)
        setAttributeHandle(labelArr[labelNr], "IMAGE", tileImages[labelNr])
        setAttribute(tileNumberLabels[labelNr], "TITLE", $(tileNumber + labelNr))
    iup.refresh(dialog)

    return 1

proc tileNumber2Pos(tileNr: int): tuple[x: cint, y: cint] =
    let 
        x = (tileNr mod tilesPerRow) * 17
        y = (tileNr div tilesPerRow) * 17
    return (x: x.cint, y: y.cint)

proc newImageLabel(surface: SurfacePtr): PIhandle =
    result = imageRGBA(surface.w, surface.h, surface.pixels)

main()
dealloc(srcR)
dealloc(destR)
dealloc(cut)