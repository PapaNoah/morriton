import strfmt

template sdlFailIf*(cond: typed, reason: string) =
    if cond: raise SDLException.newException(reason & ", SDL Error: " & $getError())

proc formatTime*(ticks: int): string =
    let
        mins = (ticks div 50) div 60
        secs = (ticks div 50) mod 60

    interp"${mins:02}:${secs:02}"

proc formatTimeExact*(ticks: int): string =
    let cents = (ticks mod 50) * 2
    interp"${formatTime(ticks)}:${cents:02}"