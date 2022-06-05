local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local opt = require 'mp.options'
local utils = require 'mp.utils'

-- Windows: C:\Users\USER\AppData\Roaming\mpv\script-opts\tethys.conf
-- Linux: ~/config/mpv/script-opts/tethys.conf
local tethys = {
    -- Config
    showPictureInPictureButton = true,
    showSpeedButton = true,
    showChapterTooltip = true, -- Show chapter above timestamp in seekbar tooltip
    skipBy = 5, -- skipback/skipfrwd amount in seconds
    skipByMore = 30, -- RightClick skipback/skipfrwd amount in seconds
    skipMode = "exact", -- "exact" (mordenx default) or "relative+keyframes" (mpv default)
    pipGeometry = "33%+-10+-10", -- PictureInPicture 33% screen width, 10px from bottom right
    pipAllWorkspaces = true, -- PictureInPicture will show video on all virtual desktops

    -- Sizes
    thumbnailSize = 256, -- 16:9 = 256x144
    seekbarHeight = 20,
    controlsHeight = 64,
    smallButtonSize = 42, -- controlsHeight * 2/3
    trackButtonSize = 36, -- controlsHeight / 2
    buttonTooltipSize = 20,
    windowBarHeight = 44,
    windowButtonSize = 44,
    windowTitleSize = 24,
    cacheTextSize = 20,
    timecodeSize = 27,
    seekbarTimestampSize = 30,
    seekbarTimestampOutline = 1,
    chapterTickSize = 6,
    windowTitleOutline = 1,
    sidebarWidth = 480,
    playlistEntryTextSize = 32,
    playlistEntryNumLines = 2,
    playlistEntryNumChars = 34,

    -- Misc
    osdSymbolFont = "mpv-osd-symbols", -- Seems to be hardcoded and unchangeable

    -- Colors (uses GGBBRR for some reason)
    -- Alpha ranges 0 (opaque) .. 255 (transparent)
    textColor = "FFFFFF",
    buttonColor = "CCCCCC",
    buttonHoveredColor = "FFFFFF",
    buttonHoveredRectColor = "000000",
    buttonHoveredRectAlpha = 255, -- Easily debug button geometry by setting to 80
    tooltipColor = "CCCCCC",
    windowBarColor = "000000",
    windowBarAlpha = 255, -- (80 is mpv default) (255 morden default)
    windowButtonColor = "CCCCCC",
    closeButtonHoveredColor = "1111DD", -- #DD1111
    seekbarHandleColor = "FFFFFF",
    seekbarFgColor = "483DD7", -- #d73d48
    seekbarBgColor = "929292",
    seekbarCacheColor = "000000",
    seekbarCacheAlpha = 128,
    chapterTickColor = "CCCCCC",
}
read_options(tethys, "tethys")

local function parseColor(color)
    if string.find(color, "#") then
        local colorU = string.upper(color)
        local r = string.sub(colorU, 2, 3)
        local g = string.sub(colorU, 4, 5)
        local b = string.sub(colorU, 6, 7)
        return b..g..r
    else
        return color
    end
end
local function parseConfig(configTable)
    for k,v in pairs(configTable) do
        if string.find(k, "Color") then
            configTable[k] = parseColor(v)
        end
    end
end

parseConfig(tethys)

tethys.bottomBarHeight = tethys.seekbarHeight + tethys.controlsHeight
tethys.buttonW = tethys.controlsHeight
tethys.buttonH = tethys.controlsHeight
tethys.smallButtonSize = math.min(tethys.controlsHeight, tethys.smallButtonSize)
tethys.trackButtonSize = math.min(tethys.controlsHeight, tethys.trackButtonSize)
tethys.windowButtonSize = math.min(tethys.windowBarHeight, tethys.windowButtonSize)
tethys.windowControlsRect = {
    w = tethys.windowButtonSize * 3,
    h = tethys.windowBarHeight,
}

tethys.trackTextScale = 105

-- [1] Foreground, [2] Karaoki Foreground, [3] Border, [4] Shadow
-- https://aegi.vmoe.info/docs/3.0/ASS_Tags/#index22h3
tethys.windowBarAlphaTable = {[1] = tethys.windowBarAlpha, [2] = 255, [3] = 255, [4] = 255}
tethys.seekbarCacheAlphaTable = {[1] = tethys.seekbarCacheAlpha, [2] = 255, [3] = 255, [4] = 255}
tethys.tooltipAlphaTable =  {[1] = 0, [2] = 255, [3] = 88, [4] = 255} -- Opache Text, 65% opacity outlines

tethys.showButtonHoveredRect = tethys.buttonHoveredRectAlpha < 255 -- Note: 255=transparent

tethys.isPictureInPicture = false
tethys.pipWasFullscreen = false
tethys.pipWasMaximized = false
tethys.pipWasOnTop = false
tethys.pipHadBorders = false

tethys.hideSeekbar = false


-- https://github.com/libass/libass/wiki/ASSv5-Override-Tags#color-and-alpha---c-o
function genColorStyle(color)
    return "{\\c&H"..color.."&}" -- Not sure why &H...& is used in santa_hat_lines
    -- return "{\\c("..color..")}" -- Works
    -- return "{\\c(#"..color..")}" -- Only works for paths, and breaks other stuff.
end

---- mpv's stats.lua has some ASS formatting
-- https://aegi.vmoe.info/docs/3.0/ASS_Tags/
-- https://github.com/libass/libass/wiki/ASSv5-Override-Tags
-- https://github.com/mpv-player/mpv/blob/master/player/lua/stats.lua#L62
-- https://github.com/mpv-player/mpv/blob/master/player/lua/stats.lua#L176
-- "{\\r}{\\an7}{\\fs%d}{\\fn%s}{\\bord%f}{\\3c&H%s&}{\\1c&H%s&}{\\alpha&H%s&}{\\xshad%f}{\\yshad%f}{\\4c&H%s&}"
-- {\\bord%f} = border size
-- {\\3c&H%s&} = border color
-- {\\1c&H%s&} = font color
-- {\\alpha&H%s&} = alpha
-- {\\xshad%f}{\\yshad%f} = shadow x,y offset
-- {\\4c&H%s&} = shadow color
-- {\\b(400)} = font weight, 400=normal, 700=bold
---- \\q2 in windowTitle is unknown
---- Not sure why \1c is rect fill color. Here's docs for \3c:
-- https://github.com/libass/libass/wiki/Libass'-ASS-Extensions#borderstyle4
-- "{\\1c&H"..color.."}"
local tethysStyle = {
    button = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)\\fn(%s)}"):format(tethys.buttonColor, tethys.buttonH, tethys.osdSymbolFont),
    buttonHovered = genColorStyle(tethys.buttonHoveredColor),
    buttonHoveredRect = ("{\\rDefault\\blur0\\bord0\\1c&H%s\\1a&H%X&}"):format(tethys.buttonHoveredRectColor, tethys.buttonHoveredRectAlpha),
    smallButton = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)\\fn(%s)}"):format(tethys.buttonColor, tethys.smallButtonSize, tethys.osdSymbolFont),
    trackButton = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)\\fn(%s)}"):format(tethys.buttonColor, tethys.trackButtonSize, tethys.osdSymbolFont),
    trackText = ("{\\fscx%s\\fscy%s\\fn(%s)}"):format(tethys.trackTextScale, tethys.trackTextScale, mp.get_property("options/osd-font")),
    windowBar = ("{\\1c&H%s}"):format(tethys.windowBarColor),
    windowButton = ("{\\blur0\\bord(%d)\\1c&H%s\\3c&H000000\\fs(%d)\\fn(%s)}"):format(tethys.windowTitleOutline, tethys.windowButtonColor, tethys.windowButtonSize, tethys.osdSymbolFont),
    closeButtonHovered = genColorStyle(tethys.closeButtonHoveredColor),
    windowTitle = ("{\\blur0\\bord(%d)\\1c&H%s\\3c&H000000\\fs(%d)}"):format(tethys.windowTitleOutline, tethys.textColor, tethys.windowTitleSize),
    buttonTooltip = ("{\\blur0\\bord(1)\\1c&H%s\\3c&H000000\\fs(%d)}"):format(tethys.tooltipColor, tethys.buttonTooltipSize),
    buttonKeybindFormat = ("{\\bord(3)\\b(700)} %s {\\bord(1)\\b(400)}"), -- Spaces around the key to accound for thick outlines
    timecode = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)}"):format(tethys.textColor, tethys.timecodeSize),
    cacheText = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)}"):format(tethys.textColor, tethys.cacheTextSize, tethys.osdSymbolFont),
    seekbar = ("{\\blur0\\bord0\\1c&H%s\\3c&HFFFFFF\\fs(%d)}"):format(tethys.seekbarFgColor, tethys.seekbarHeight),
    seekbarTimestamp = ("{\\blur0\\bord(%d)\\1c&H%s\\3c&H000000\\fs(%d)}"):format(tethys.seekbarTimestampOutline, tethys.textColor, tethys.seekbarTimestampSize),
    text = genColorStyle(tethys.textColor),
    seekbarHandle = genColorStyle(tethys.seekbarHandleColor),
    seekbarFg = genColorStyle(tethys.seekbarFgColor),
    seekbarBg = genColorStyle(tethys.seekbarBgColor),
    seekbarCache = genColorStyle(tethys.seekbarCacheColor),
    chapterTick = genColorStyle(tethys.chapterTickColor),
}

---- Icons
-- 44x44
local tethysIcon_play = "{\\p1}m 0 0   m 44 44   m 37.236218 17.599999   b 41.584084 20.610064 41.584084 21.923269 37.236218 24.933333   b 22.516553 35.123867 9.369549 44 6.436216 44   b 3.502883 44 3.502883 39.6 3.502883 21.266665   b 3.502883 4.4 3.502883 0 6.436216 0   b 9.369549 0 22.516553 7.409462 37.236218 17.599999{\\p0}"
local tethysIcon_pause = "{\\p1}m 0 0   m 44 44   m 17.5 40.2064   b 17.5 45.263808 4.5 45.263808 4.5 40.2107   l 4.5 3.793057   b 4.5 -1.264352 17.5 -1.264352 17.5 3.793057   m 39.5 40.2064   b 39.5 45.263808 26.5 45.263808 26.5 40.2107   l 26.5 3.793057   b 26.5 -1.264352 39.5 -1.264352 39.5 3.793057{\\p0}"
local mpvOsdIcon_close = "{\\p1}m 0 0   m 44 44   m 34 34   l 30.571428 34   l 22 25.535715   l 13.535714 34   l 10 34   l 10 30.571428   l 18.464286 22   l 10 13.535714   l 10 10   l 13.535714 10   l 22 18.464286   l 30.571428 10   l 34 10   l 34 13.535714   l 25.535715 22   l 34 30.464285{\\p0}"
local mpvOsdIcon_maximize = "{\\p1}m 0 0   m 44 44   m 34 33   l 10 33   l 10 11   l 34 11   m 32 31   l 32 15   l 12 15   l 12 31{\\p0}"
local mpvOsdIcon_minimize = "{\\p1}m 0 0   m 44 44   m 34 25   l 10 25   l 10 19   l 34 19{\\p0}"
local mpvOsdIcon_restore = "{\\p1}m 0 0   m 44 44   m 34 25   l 27.999999 25   l 27.999999 33   l 10 33   l 10 18.999999   l 16 18.999999   l 16 11   l 34 11   m 32 23.000001   l 32 15   l 18 15   l 18 18.999999   l 27.999999 18.999999   l 27.999999 23.000001   m 26 31   l 26 23.000001   l 12 23.000001   l 12 31{\\p0}"
-- 32x28
local mpvOsdIcon_fs_enter = "{\\p1}m 0 0   m 32 28   m 0 23.454546   l 0 4.545454   b 0 3.454545 1.090909 2.363636 2.181818 2.363636   l 29.818182 2.363636   b 30.90909 2.363636 32 3.454545 32 4.545454   l 32 23.454546   b 32 24.545456 30.90909 25.636364 29.818182 25.636364   l 2.181818 25.636364   b 1.090909 25.636364 0 24.545456 0 23.454546   m 2.181818 23.454546   l 29.818182 23.454546   l 29.818182 4.545454   l 2.181818 4.545454   m 21.090909 6.727272   l 27.636363 6.727272   l 27.636363 13.272728   m 22.036363 11.09091   l 22.036363 16.872726   l 9.963636 16.872726   l 9.963636 11.09091   m 10.909091 21.272728   l 4.363636 21.272728   l 4.363636 14.727272{\\p0}"
local mpvOsdIcon_fs_exit = "{\\p1}m 0 0   m 32 28   m 0 23.454546   l 0 4.545454   b 0 3.454545 1.090909 2.363636 2.181818 2.363636   l 29.818182 2.363636   b 30.909091 2.363636 32 3.454545 32 4.545454   l 32 23.454546   b 32 24.545454 30.909091 25.636364 29.818182 25.636364   l 2.181818 25.636364   b 1.090909 25.636364 0 24.545454 0 23.454546   m 2.181818 23.454546   l 29.818182 23.454546   l 29.818182 4.545454   l 2.181818 4.545454   m 8.254546 14.000001   l 4.363636 18   l 4.363636 10   m 27.636364 18   l 23.745455 14.000001   l 27.636364 10   m 21.636364 10.181818   l 21.636364 17.781818   l 10.363636 17.781818   l 10.363636 10.181818{\\p0}"
-- 28x28
local tethysIcon_ch_prev = "{\\p1}m 0 0   m 28 28   m 15.555834 12.5   b 14.073607 13.526159 14.073607 13.973842 15.555834 15.000001   b 20.573903 18.474048 25.055836 21.5 26.055836 21.5   b 27.055835 21.5 27.055835 20.000001 27.055835 13.75   b 27.055835 8.000001 27.055835 6.5 26.055836 6.5   b 25.055836 6.5 20.573903 9.025952 15.555834 12.5   m 2.055835 12.5   b 0.573608 13.526159 0.573608 13.973842 2.055835 15.000001   b 7.073904 18.474048 11.555837 21.5 12.555836 21.5   b 13.555836 21.5 13.555836 20.000001 13.555836 13.75   b 13.555836 8.000001 13.555836 6.5 12.555836 6.5   b 11.555837 6.5 7.073904 9.025952 2.055835 12.5{\\p0}"
local tethysIcon_ch_next = "{\\p1}m 0 0   m 28 28   m 12.444166 12.5   b 13.926393 13.526159 13.926393 13.973842 12.444166 15.000001   b 7.426097 18.474048 2.944164 21.5 1.944165 21.5   b 0.944165 21.5 0.944165 20.000001 0.944165 13.75   b 0.944165 8.000001 0.944165 6.5 1.944165 6.5   b 2.944164 6.5 7.426097 9.025952 12.444166 12.5   m 25.944165 12.5   b 27.426392 13.526159 27.426392 13.973842 25.944165 15.000001   b 20.926096 18.474048 16.444163 21.5 15.444164 21.5   b 14.444164 21.5 14.444164 20.000001 14.444164 13.75   b 14.444164 8.000001 14.444164 6.5 15.444164 6.5   b 16.444163 6.5 20.926096 9.025952 25.944165 12.5{\\p0}"
local tethysIcon_pip_enter = "{\\p1}m 0 0   m 28 28   m 14 16   l 22 16   l 22 21   l 14 21   m 2 5   b 2 5 2 22 2 23   b 2 24 3 25 4 25   b 5 25 24 25 24 25   b 25 25 26 24 26 23   l 26 5   b 26 4 25 3 24 3   l 4 3   b 3 3 2 4 2 5   m 4 5   l 24 5   l 24 23   l 4 23{\\p0}"
local tethysIcon_pip_exit = "{\\p1}m 0 0   m 28 28   m 14 3   l 14 5   l 24 5   l 24 23   l 4 23   l 4 16   l 2 16   l 2 23   b 2 24 3 25 4 25   l 24 25   b 25 25 26 24 26 23   l 26 5   b 26 4 25 3 24 3   m 2 3   l 2 12   l 4 12   l 4 7   l 18 20   l 20 18   l 6 5   l 11 5   l 11 3{\\p0}"
local tethysIcon_pl_prev = "{\\p1}m 0 0   m 28 28   m 10.133332 11.8   b 7.959399 13.305034 7.959399 13.961635 10.133332 15.466668   b 17.493166 20.561937 24.066668 25 25.533334 25   b 27 25 27 22.800002 27 13.633333   b 27 5.200001 27 3 25.533334 3   b 24.066668 3 17.493166 6.70473 10.133332 11.8   m 1 23.103196   b 1 25.631901 7.574631 25.631901 7.574631 23.105396   l 7.574631 4.896528   b 7.574631 2.367824 1 2.367824 1 4.896528{\\p0}"
local tethysIcon_pl_next = "{\\p1}m 0 0   m 28 28   m 17.866668 11.8   b 20.040601 13.305034 20.040601 13.961635 17.866668 15.466668   b 10.506834 20.561937 3.933332 25 2.466666 25   b 1 25 1 22.800002 1 13.633333   b 1 5.200001 1 3 2.466666 3   b 3.933332 3 10.506834 6.70473 17.866668 11.8   m 27 23.103196   b 27 25.631901 20.425369 25.631901 20.425369 23.105396   l 20.425369 4.896528   b 20.425369 2.367824 27 2.367824 27 4.896528{\\p0}"
local tethysIcon_skipback = "{\\p1}m 0 0   m 28 28   m 2.511898 -0   l 2.511898 9.57764   l 12.089539 9.57764   l 12.089539 6.385093   l 8.163287 6.385093   b 11.540598 3.999689 16.093522 3.879191 19.632345 6.243757   b 23.661324 8.935835 25.219633 14.07368 23.365296 18.550442   b 21.510961 23.027205 16.775533 25.558703 12.023026 24.613371   b 7.27052 23.668038 3.864989 19.515531 3.864989 14.669918   l 0.672442 14.669918   b 0.672442 21.018992 5.172403 26.50492 11.399482 27.743563   b 17.626561 28.982206 23.884976 25.638369 26.314661 19.772589   b 28.744346 13.906809 26.684352 7.114815 21.40529 3.587458   b 18.765759 1.82378 15.680838 1.117147 12.694376 1.411288   b 10.187051 1.658238 7.750413 2.61433 5.704444 4.242179   l 5.704444 -0{\\p0}"
local tethysIcon_skipfrwd = "{\\p1}m 0 0   m 28 28   m 25.488102 -0   l 25.488102 9.57764   l 15.910461 9.57764   l 15.910461 6.385093   l 19.836712 6.385093   b 16.459402 3.999689 11.906478 3.879191 8.367655 6.243757   b 4.338676 8.935835 2.780367 14.07368 4.634704 18.550442   b 6.489039 23.027205 11.224467 25.558703 15.976974 24.613371   b 20.729479 23.668038 24.135011 19.515531 24.135011 14.669918   l 27.327558 14.669918   b 27.327558 21.018992 22.827597 26.50492 16.600518 27.743563   b 10.373439 28.982206 4.115024 25.638369 1.685339 19.772589   b -0.744346 13.906809 1.315648 7.114815 6.59471 3.587458   b 9.234241 1.82378 12.319162 1.117147 15.305624 1.411288   b 17.812949 1.658238 20.249586 2.61433 22.295555 4.242179   l 22.295555 -0{\\p0}"
local tethysIcon_speed = "{\\p1}m 0 0   m 28 28   m 14 2.053711   b 10.414212 2.053711 6.827634 3.417483 4.099609 6.145508   b -1.35644 11.601557 -1.35644 20.490239 4.099609 25.946289   l 6.017578 24.02832   b 1.597151 19.607893 1.597151 12.483903 6.017578 8.063476   b 10.438006 3.64305 17.561994 3.64305 21.982422 8.063476   b 26.402849 12.483903 26.402849 19.607893 21.982422 24.02832   l 23.900391 25.946289   b 29.35644 20.490239 29.35644 11.601557 23.900391 6.145508   b 21.172366 3.417483 17.585788 2.053711 14 2.053711   m 17.886719 10.034179   l 14.351562 13.571289   b 14.235118 13.554564 14.117639 13.54608 14 13.545898   b 13.336959 13.545898 12.701074 13.80929 12.232233 14.278131   b 11.763392 14.746972 11.5 15.382857 11.5 16.045898   b 11.5 17.42661 12.619288 18.545898 14 18.545898   b 14.663041 18.545898 15.298926 18.282506 15.767767 17.813665   b 16.236608 17.344824 16.5 16.708939 16.5 16.045898   b 16.499911 15.927607 16.491426 15.809472 16.47461 15.692382   l 20.009767 12.155273{\\p0}"
local tethysIcon_vol_033 = "{\\p1}m 0 0   m 28 28   m 4.710272 20.331519   l 1.360222 18.656494   b 0.489258 18.221011 0.489258 18.221011 0.489258 17.165758   l 0.489258 14   l 0.489258 10.83424   b 0.489258 9.778988 0.48926 9.778988 1.337532 9.354852   l 4.710272 7.668481   m 5.765524 7.674466   l 9.986538 3.453454   b 10.706239 2.706516 12.097044 1.342947 12.097044 3.453454   l 12.097044 24.558517   b 12.097044 26.669023 10.738402 25.263082 9.986538 24.558517   l 5.765524 20.337504   m 16.562393 10.929048   l 14.418911 13.150849   l 14.418911 14.870154   l 16.488207 17.07095   b 17.436586 16.089838 17.82417 15.024196 17.820228 13.983409   b 17.816228 12.942625 17.530838 11.909297 16.562404 10.929049{\\p0}"
local tethysIcon_vol_066 = "{\\p1}m 0 0   m 28 28   m 4.710272 20.331519   l 1.360222 18.656494   b 0.489258 18.221011 0.489258 18.221011 0.489258 17.165758   l 0.489258 14   l 0.489258 10.83424   b 0.489258 9.778988 0.48926 9.778988 1.337532 9.354852   l 4.710272 7.668481   m 5.765524 7.674466   l 9.986538 3.453454   b 10.706239 2.706516 12.097044 1.342947 12.097044 3.453454   l 12.097044 24.558517   b 12.097044 26.669023 10.738402 25.263082 9.986538 24.558517   l 5.765524 20.337504   m 20.116395 7.368459   l 17.915201 9.643849   b 18.793615 10.494225 19.496549 12.085227 19.477484 14.012366   b 19.458484 15.939505 18.683596 17.529199 17.842625 18.356568   l 20.064426 20.611347   b 21.82241 18.8818 22.618007 16.592612 22.643244 14.04122   b 22.668484 11.489827 21.937955 9.131882 20.116395 7.368459   m 16.562393 10.929048   l 14.418911 13.150849   l 14.418911 14.870154   l 16.488207 17.07095   b 17.436586 16.089838 17.82417 15.024196 17.820228 13.983409   b 17.816228 12.942625 17.530838 11.909297 16.562404 10.929049{\\p0}"
local tethysIcon_vol_100 = "{\\p1}m 0 0   m 28 28   m 4.710272 20.331519   l 1.360222 18.656494   b 0.489258 18.221011 0.489258 18.221011 0.489258 17.165758   l 0.489258 14   l 0.489258 10.83424   b 0.489258 9.778988 0.48926 9.778988 1.337532 9.354852   l 4.710272 7.668481   m 5.765524 7.674466   l 9.986538 3.453454   b 10.706239 2.706516 12.097044 1.342947 12.097044 3.453454   l 12.097044 24.558517   b 12.097044 26.669023 10.738402 25.263082 9.986538 24.558517   l 5.765524 20.337504   m 23.532835 3.779296   l 21.294544 6.017587   b 22.97216 7.695202 24.35259 10.812999 24.344937 13.990067   b 24.337337 17.167135 22.938039 20.301821 21.257445 21.982413   l 23.499858 24.220704   b 26.040275 21.680287 27.501508 17.812486 27.510697 13.99831   b 27.519997 10.184133 26.076229 6.322689 23.532835 3.779296   m 20.116395 7.368459   l 17.915201 9.643849   b 18.793615 10.494225 19.496549 12.085227 19.477484 14.012366   b 19.458484 15.939505 18.683596 17.529199 17.842625 18.356568   l 20.064426 20.611347   b 21.82241 18.8818 22.618007 16.592612 22.643244 14.04122   b 22.668484 11.489827 21.937955 9.131882 20.116395 7.368459   m 16.562393 10.929048   l 14.418911 13.150849   l 14.418911 14.870154   l 16.488207 17.07095   b 17.436586 16.089838 17.82417 15.024196 17.820228 13.983409   b 17.816228 12.942625 17.530838 11.909297 16.562404 10.929049{\\p0}"
local tethysIcon_vol_101 = "{\\p1}m 0 0   m 28 28   m 26.774083 5.201582   l 25.69218 18.248063   b 25.66035 18.693555 25.533063 18.916303 25.31033 18.916303   b 25.08759 18.916303 24.960302 18.693563 24.928482 18.248063   l 23.878399 5.201582   l 23.878399 5.074292   b 23.878399 4.660623 24.005689 4.342418 24.292068 4.119669   b 24.578454 3.865105 24.928482 3.737822 25.31033 3.737822   b 25.724 3.737822 26.042205 3.865111 26.328594 4.119669   b 26.614979 4.342409 26.774083 4.660623 26.774083 5.074292   m 26.774083 22.734783   b 26.774083 23.180275 26.614991 23.530301 26.360414 23.816689   b 26.074028 24.134895 25.724 24.262178 25.31033 24.262178   b 24.928482 24.262178 24.578454 24.134888 24.292068 23.816689   b 24.005682 23.530301 23.878399 23.180275 23.878399 22.734783   b 23.878399 22.321115 24.005689 21.971087 24.292068 21.684702   b 24.578454 21.366494 24.928482 21.239213 25.31033 21.239213   b 25.724 21.239213 26.074028 21.366487 26.360414 21.684702   b 26.614979 21.971087 26.774083 22.321115 26.774083 22.734783   m 4.710272 20.331519   l 1.360222 18.656494   b 0.489258 18.221011 0.489258 18.221011 0.489258 17.165758   l 0.489258 14   l 0.489258 10.83424   b 0.489258 9.778988 0.48926 9.778988 1.337532 9.354852   l 4.710272 7.668481   m 5.765524 7.674466   l 9.986538 3.453454   b 10.706239 2.706516 12.097044 1.342947 12.097044 3.453454   l 12.097044 24.558517   b 12.097044 26.669023 10.738402 25.263082 9.986538 24.558517   l 5.765524 20.337504   m 20.116395 7.368459   l 17.915201 9.643849   b 18.793615 10.494225 19.496549 12.085227 19.477484 14.012366   b 19.458484 15.939505 18.683596 17.529199 17.842625 18.356568   l 20.064426 20.611347   b 21.82241 18.8818 22.618007 16.592612 22.643244 14.04122   b 22.668484 11.489827 21.937955 9.131882 20.116395 7.368459   m 16.562393 10.929048   l 14.418911 13.150849   l 14.418911 14.870154   l 16.488207 17.07095   b 17.436586 16.089838 17.82417 15.024196 17.820228 13.983409   b 17.816228 12.942625 17.530838 11.909297 16.562404 10.929049{\\p0}"
local tethysIcon_vol_mute = "{\\p1}m 0 0   m 28 28   m 4.710272 20.331519   l 1.360222 18.656494   b 0.489258 18.221011 0.489258 18.221011 0.489258 17.165758   l 0.489258 14   l 0.489258 10.83424   b 0.489258 9.778988 0.48926 9.778988 1.337532 9.354852   l 4.710272 7.668481   m 5.765524 7.674466   l 9.986538 3.453454   b 10.706239 2.706516 12.097044 1.342947 12.097044 3.453454   l 12.097044 24.558517   b 12.097044 26.669023 10.738402 25.263082 9.986538 24.558517   l 5.765524 20.337504   m 26.699268 7.480125   b 26.905593 7.480125 27.111919 7.52139 27.276978 7.68645   b 27.607099 8.01657 27.607099 8.51175 27.276978 8.841871   l 22.077583 14.041265   l 27.276978 19.240659   b 27.565833 19.529515 27.565833 19.98343 27.276978 20.31355   b 26.988123 20.602406 26.492943 20.602406 26.204087 20.31355   l 21.004692 15.114157   l 15.805297 20.31355   b 15.516442 20.602406 14.979997 20.602406 14.691142 20.31355   b 14.361021 19.98343 14.361021 19.48825 14.691142 19.158129   l 19.849271 13.958735   l 14.649877 8.759341   b 14.361021 8.470485 14.361021 8.01657 14.649877 7.68645   b 14.979997 7.397594 15.433912 7.397594 15.764033 7.68645   l 20.963428 12.885844   l 26.162823 7.68645   b 26.286617 7.52139 26.492943 7.480125 26.699268 7.480125{\\p0}"

function scaleIcon(iconStr, iconScale)
    -- Match space before number to ignore {\p1} and {\p0}
    return iconStr:gsub(" ([%d%.]+)", function(numStr)
        local num = tonumber(numStr)
        num = num * iconScale
        return " " .. tostring(num)
    end)
end
local iconScale = tethys.controlsHeight / 64
if iconScale ~= 1 then
    tethysIcon_play = scaleIcon(tethysIcon_play, iconScale)
    tethysIcon_pause = scaleIcon(tethysIcon_pause, iconScale)
end
iconScale = tethys.windowButtonSize / 44
if iconScale ~= 1 then
    mpvOsdIcon_close = scaleIcon(mpvOsdIcon_close, iconScale)
    mpvOsdIcon_maximize = scaleIcon(mpvOsdIcon_maximize, iconScale)
    mpvOsdIcon_minimize = scaleIcon(mpvOsdIcon_minimize, iconScale)
    mpvOsdIcon_restore = scaleIcon(mpvOsdIcon_restore, iconScale)
end
iconScale = tethys.smallButtonSize / 42
if iconScale ~= 1 then
    mpvOsdIcon_fs_enter = scaleIcon(mpvOsdIcon_fs_enter, iconScale)
    mpvOsdIcon_fs_exit = scaleIcon(mpvOsdIcon_fs_exit, iconScale)
    tethysIcon_ch_prev = scaleIcon(tethysIcon_ch_prev, iconScale)
    tethysIcon_ch_next = scaleIcon(tethysIcon_ch_next, iconScale)
    tethysIcon_pip_enter = scaleIcon(tethysIcon_pip_enter, iconScale)
    tethysIcon_pip_exit = scaleIcon(tethysIcon_pip_exit, iconScale)
    tethysIcon_pl_prev = scaleIcon(tethysIcon_pl_prev, iconScale)
    tethysIcon_pl_next = scaleIcon(tethysIcon_pl_next, iconScale)
    tethysIcon_skipback = scaleIcon(tethysIcon_skipback, iconScale)
    tethysIcon_skipfrwd = scaleIcon(tethysIcon_skipfrwd, iconScale)
    tethysIcon_speed = scaleIcon(tethysIcon_speed, iconScale)
    tethysIcon_vol_033 = scaleIcon(tethysIcon_vol_033, iconScale)
    tethysIcon_vol_066 = scaleIcon(tethysIcon_vol_066, iconScale)
    tethysIcon_vol_100 = scaleIcon(tethysIcon_vol_100, iconScale)
    tethysIcon_vol_101 = scaleIcon(tethysIcon_vol_101, iconScale)
    tethysIcon_vol_mute = scaleIcon(tethysIcon_vol_mute, iconScale)
end



















--
-- Parameters
--
-- default user option values
-- do not touch, change them in osc.conf
local user_opts = {
    showwindowed = true,        -- show OSC when windowed?
    showfullscreen = true,      -- show OSC when fullscreen?
    scalewindowed = 1,          -- scaling of the controller when windowed
    scalefullscreen = 1,        -- scaling of the controller when fullscreen
    scaleforcedwindow = 2,      -- scaling when rendered on a forced window
    vidscale = true,            -- scale the controller with the video?
    valign = 0.8,               -- vertical alignment, -1 (top) to 1 (bottom)
    halign = 0,                 -- horizontal alignment, -1 (left) to 1 (right)
    barmargin = 0,              -- vertical margin of top/bottombar
    boxalpha = 80,              -- alpha of the background box,
                                -- 0 (opaque) to 255 (fully transparent)
    hidetimeout = 500,          -- duration in ms until the OSC hides if no
                                -- mouse movement. enforced non-negative for the
                                -- user, but internally negative is "always-on".
    fadeduration = 200,         -- duration of fade out in ms, 0 = no fade
    deadzonesize = 0.5,         -- size of deadzone
    minmousemove = 0,           -- minimum amount of pixels the mouse has to
                                -- move between ticks to make the OSC show up
    iamaprogrammer = false,     -- use native mpv values and disable OSC
                                -- internal track list management (and some
                                -- functions that depend on it)
    -- layout = "bottombar",
    layout = "tethys",
    seekbarstyle = "bar",       -- bar, diamond or knob
    seekbarhandlesize = 0.6,    -- size ratio of the diamond and knob handle
    seekrangestyle = "inverted",-- bar, line, slider, inverted or none
    seekrangeseparate = true,   -- whether the seekranges overlay on the bar-style seekbar
    seekrangealpha = 200,       -- transparency of seekranges
    seekbarkeyframes = true,    -- use keyframes when dragging the seekbar
    title = "${media-title}",   -- string compatible with property-expansion
                                -- to be shown as OSC title
    tooltipborder = 1,          -- border of tooltip in bottom/topbar
    timetotal = false,          -- display total time instead of remaining time?
    timems = false,             -- display timecodes with milliseconds?
    visibility = "auto",        -- only used at init to set visibility_mode(...)
    -- visibility = "always",        -- only used at init to set visibility_mode(...)
    boxmaxchars = 80,           -- title crop threshold for box layout
    boxvideo = false,           -- apply osc_param.video_margins to video
    windowcontrols = "auto",    -- whether to show window controls
    windowcontrols_alignment = "right", -- which side to show window controls on
    greenandgrumpy = false,     -- disable santa hat
    livemarkers = true,         -- update seekbar chapter markers on duration change
    chapters_osd = true,        -- whether to show chapters OSD on next/prev
    playlist_osd = true,        -- whether to show playlist OSD on next/prev
    chapter_fmt = "Chapter: %s", -- chapter print format for seekbar-hover. "no" to disable
}

-- read options from config and command-line
opt.read_options(user_opts, "osc", function(list) update_options(list) end)

local osc_param = { -- calculated by osc_init()
    playresy = 0,                           -- canvas size Y
    playresx = 0,                           -- canvas size X
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
    video_margins = {
        l = 0, r = 0, t = 0, b = 0,         -- left/right/top/bottom
    },
}

local osc_styles = {
    bigButtons = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs50\\fnmpv-osd-symbols}",
    smallButtonsL = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs19\\fnmpv-osd-symbols}",
    smallButtonsLlabel = "{\\fscx105\\fscy105\\fn" .. mp.get_property("options/osd-font") .. "}",
    smallButtonsR = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs30\\fnmpv-osd-symbols}",
    topButtons = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs12\\fnmpv-osd-symbols}",

    elementDown = "{\\1c&H999999}",
    timecodes = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs20}",
    vidtitle = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs12\\q2}",
    box = "{\\rDefault\\blur0\\bord1\\1c&H000000\\3c&HFFFFFF}",

    topButtonsBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs18\\fnmpv-osd-symbols}",
    smallButtonsBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs28\\fnmpv-osd-symbols}",
    timecodesBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs27}",
    timePosBar = "{\\blur0\\bord".. user_opts.tooltipborder .."\\1c&HFFFFFF\\3c&H000000\\fs30}",
    vidtitleBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs18\\q2}",

    wcButtons = "{\\1c&HFFFFFF\\fs24\\fnmpv-osd-symbols}",
    wcTitle = "{\\1c&HFFFFFF\\fs24\\q2}",
    wcBar = "{\\1c&H000000}",
}


















---- Tooltip Utils
-- See MPV's stats.lua for a full example (Shortcut: I + 4)
-- https://github.com/mpv-player/mpv/blob/master/player/lua/stats.lua#L433
local bindings = mp.get_property_native("input-bindings", {})
local active = {}  -- map: key-name -> bind-info
for _, bind in pairs(bindings) do
    if bind.priority >= 0 and (
           not active[bind.key] or
           (active[bind.key].is_weak and not bind.is_weak) or
           (bind.is_weak == active[bind.key].is_weak and
            bind.priority > active[bind.key].priority)
       ) and not bind.cmd:find("script-binding stats/__forced_", 1, true)
    then
        active[bind.key] = bind
    end
end
local ordered = {}
for _, bind in pairs(active) do
    table.insert(ordered, bind)
    _,_, bind.mods = bind.key:find("(.*)%+.")
    _, bind.mods_count = bind.key:gsub("%+.", "")
end
table.sort(ordered, function(a, b)
    if a.subject ~= b.subject then
        return a.subject < b.subject
    elseif a.mods_count ~= b.mods_count then
        return a.mods_count < b.mods_count
    elseif a.mods ~= b.mods then
        return a.mods < b.mods
    elseif a.key:len() ~= b.key:len() then
        return a.key:len() < b.key:len()
    elseif a.key:lower() ~= b.key:lower() then
        return a.key:lower() < b.key:lower()
    else
        return a.key > b.key  -- only case differs, lowercase first
    end
end)
-- for _, bind in pairs(ordered) do
--     jsonstr, err = utils.format_json(bind)
--     print(jsonstr)
-- end

function grepBindByCmd(pattern, ignoredKeys)
    ignoredKeys = ignoredKeys or {}
    local cmdBinds = {}
    for _, bind in pairs(ordered) do
        local ignored = false
        for _, ignoredKey in pairs(ignoredKeys) do
            if bind.key == ignoredKey then
                ignored = true
                break
            end
        end
        if not ignored and bind.cmd:find(pattern) then
            -- print(bind.key, bind.cmd)
            cmdBinds[#cmdBinds+1] = bind
        end
    end
    return cmdBinds
end

function grepSpeedBinds()
    local downBinds = {}
    local upBinds = {}
    for _, bind in pairs(ordered) do
        if bind.cmd:find("^add(%s+)speed(%s+)(%+?[%d%.]+)$") then
            upBinds[#upBinds+1] = bind
        elseif bind.cmd:find("^add(%s+)speed(%s+)(%-[%d%.]+)$") then
            downBinds[#downBinds+1] = bind
        elseif bind.cmd:find("^multiply(%s+)speed(%s+)([%d%.]+)/([%d%.]+)$") then
            local num, den = bind.cmd:match("^multiply%s+speed%s+([%d%.]+)/([%d%.]+)$")
            num = tonumber(num) -- numerator
            den = tonumber(den) -- denominator
            if num < den then
                downBinds[#downBinds+1] = bind
            else
                upBinds[#upBinds+1] = bind
            end
        elseif bind.cmd:find("^multiply(%s+)speed(%s+)([%d%.]+)$") then
            local x = bind.cmd:match("^multiply%s+speed%s+([%d%.]+)$")
            x = tonumber(x)
            if x < 1 then
                downBinds[#downBinds+1] = bind
            else
                upBinds[#upBinds+1] = bind
            end
        end
    end
    return downBinds, upBinds
end

function humanBindKey(key)
    if key == 'PGUP' then return 'PgUp'
    elseif key == 'PGDWN' then return 'PgDn'
    elseif key == 'UP' then return '⇧'
    elseif key == 'DOWN' then return '⇩'
    elseif key == 'LEFT' then return '⇦'
    elseif key == 'RIGHT' then return '⇨'
    elseif key == 'SHARP' then return '#'
    elseif key == 'BS' then return 'Backspace'
    elseif key == '{' then return '\\{'
    elseif key == '}' then return '\\}'
    else return key
    end
end
function formatBindKey(key)
    return tethysStyle.buttonKeybindFormat:format(humanBindKey(key))
end
function formatBinds(binds)
    local str = ""
    for i, bind in pairs(binds) do
        if i ~= 1 then -- lua arrays start at 1
            str = str .. " or "
        end
        str = str .. formatBindKey(bind.key)
    end
    return str
end
function formatSeekBind(bind)
    local seekBy = bind.cmd:match("^seek%s+([%+%-]?[%d%.]+)")
    seekBy = tonumber(seekBy) -- Note: +0.1 is parsed okay
    local label 
    if seekBy < 0 then
        return ("Back %ss %s"):format(-seekBy, formatBindKey(bind.key))
    else
        return ("Forward %ss %s"):format(seekBy, formatBindKey(bind.key))
    end
end
function formatSeekBinds(binds)
    local list = {}
    for i, bind in pairs(binds) do
        table.insert(list, formatSeekBind(bind))
    end
    return list
end

---- Filter bindings by commands using regex
---- Keys passed into grepBindByCmd() are ignored.
-- %s+ = One or more spaces
-- %- = A literal dash '-'
-- %-? = May or may not contain a dash
-- %d+ = One or more digits from 0 to 9
-- (%-?%d+) = Positive or negative integer
local pauseBinds = grepBindByCmd("^cycle(%s+)pause", {"p", "PLAYPAUSE", "MBTN_RIGHT", "PLAY", "PAUSE"})
local seekBackBinds = grepBindByCmd("^seek(%s+)(%-[%d%.]+)", {"REWIND", "Shift+PGDWN"})
local seekFrwdBinds = grepBindByCmd("^seek(%s+)(%+?[%d%.]+)", {"FORWARD", "Shift+PGUP"})
local muteBinds = grepBindByCmd("^cycle(%s+)mute", {"MUTE"})
local volDnBinds = grepBindByCmd("^add(%s+)volume(%s+)(%-%d+)", {"VOLUME_DOWN", "WHEEL_LEFT"})
local volUpBinds = grepBindByCmd("^add(%s+)volume(%s+)(%d+)", {"VOLUME_UP", "WHEEL_RIGHT"})
local plPrevBinds = grepBindByCmd("^playlist%-prev", {"PREV", "MBTN_BACK"})
local plNextBinds = grepBindByCmd("^playlist%-next", {"NEXT", "MBTN_FORWARD"})
local chPrevBinds = grepBindByCmd("^add chapter (%-%d+)", {})
local chNextBinds = grepBindByCmd("^add chapter (%d+)", {})
local audioBinds = grepBindByCmd("^cycle(%s+)audio", {})
local subBinds = grepBindByCmd("^cycle(%s+)sub$", {})
local speedResetBinds = grepBindByCmd("^set(%s+)speed(%s+)1", {})
local speedDnBinds, speedUpBinds = grepSpeedBinds()
local fullscreenBinds = grepBindByCmd("^cycle(%s+)fullscreen", {"MBTN_LEFT_DBL"})
---- Generate tooltips
local pauseTooltip = ("Play %s"):format(formatBinds(pauseBinds))
local seekBackTooltip = formatSeekBinds(seekBackBinds)
local seekFrwdTooltip = formatSeekBinds(seekFrwdBinds)
local muteTooltip = formatBinds(muteBinds)
local volDnTooltip = formatBinds(volDnBinds)
local volUpTooltip = formatBinds(volUpBinds)
local volTooltip = {
    -- ("Volume Down (%s) Up (%s)"):format(volDnTooltip, volUpTooltip),
    ("Volume Down %s"):format(volDnTooltip),
    ("Volume Up %s"):format(volUpTooltip),
    ("Mute %s"):format(muteTooltip)
}
local plPrevTooltip = ("Previous %s"):format(formatBinds(plPrevBinds))
local plNextTooltip = ("Next %s"):format(formatBinds(plNextBinds))
local chPrevTooltip = ("Prev Chapter %s"):format(formatBinds(chPrevBinds))
local chNextTooltip = ("Next Chapter %s"):format(formatBinds(chNextBinds))
local audioTooltip = ("Audio Track %s"):format(formatBinds(audioBinds))
local subTooltip = ("Subtitle Track %s"):format(formatBinds(subBinds))
local speedResetTooltip = formatBinds(speedResetBinds)
local speedDnTooltip = formatBinds(speedDnBinds)
local speedUpTooltip = formatBinds(speedUpBinds)
local speedTooltip = {
    -- ("Volume Down (%s) Up (%s)"):format(volDnTooltip, volUpTooltip),
    ("Slower %s"):format(speedDnTooltip),
    ("Faster %s"):format(speedUpTooltip),
    ("Reset %s"):format(speedResetTooltip)
}
local pipTooltip = "Picture In Picture"
local fullscreenTooltip = ("Fullscreen %s"):format(formatBinds(fullscreenBinds))
-- print("pauseTooltip", pauseTooltip)
-- print("seekBackTooltip", utils.format_json(seekBackTooltip))
-- print("seekFrwdTooltip", utils.format_json(seekFrwdTooltip))
-- print("muteTooltip", muteTooltip)
-- print("volDnTooltip", volDnTooltip)
-- print("volUpTooltip", volUpTooltip)
-- print("volTooltip", utils.format_json(volTooltip))
-- print("plPrevTooltip", plPrevTooltip)
-- print("plNextTooltip", plNextTooltip)
-- print("chPrevTooltip", chPrevTooltip)
-- print("chNextTooltip", chNextTooltip)
-- print("audioTooltip", audioTooltip)
-- print("subTooltip", subTooltip)
-- print("speedResetTooltip", speedResetTooltip)
-- print("speedDnTooltip", speedDnTooltip)
-- print("speedUpTooltip", speedUpTooltip)
-- print("speedTooltip", utils.format_json(speedTooltip))
-- print("pipTooltip", pipTooltip)
-- print("fullscreenTooltip", fullscreenTooltip)



















---- Playlist / Chapter Utils
function getDeltaListItem(listKey, curKey, delta, clamp)
    local pos = mp.get_property_number(curKey, 0) + 1
    local count, limlist = limited_list(listKey, pos)
    if count == 0 then
        return nil
    end

    local curIndex = -1
    for i, v in ipairs(limlist) do
        if v.current then
            curIndex = i
            break
        end
    end

    local deltaIndex = curIndex + delta
    if curIndex == -1 then
        return nil
    elseif deltaIndex < 1 then
        if clamp then
            deltaIndex = 1
        else
            return nil
        end
    elseif deltaIndex > count then
        if clamp then
            deltaIndex = count
        else
            return nil
        end
    end

    local deltaItem = limlist[deltaIndex]
    return deltaIndex, deltaItem
end

function getDeltaChapter(delta)
    local deltaIndex, deltaChapter = getDeltaListItem('chapter-list', 'chapter', delta, true)
    if deltaChapter == nil then -- Video Done
        return nil
    end
    deltaChapter = {
        index = deltaIndex,
        time = deltaChapter.time,
        title = deltaChapter.title,
        label = nil,
    }
    local label = deltaChapter.title
    if label == nil then
        label = string.format('Chapter %02d', deltaChapter.index)
    end
    -- local time = mp.format_time(deltaChapter.time)
    -- deltaChapter.label = string.format('[%s] %s', time, label)
    deltaChapter.label = label
    return deltaChapter
end

function getDeltaPlaylistItem(delta)
    local deltaIndex, deltaItem = getDeltaListItem('playlist', 'playlist-pos', delta, false)
    if deltaItem == nil then
        return nil
    end
    deltaItem = {
        index = deltaIndex,
        filename = deltaItem.filename,
        title = deltaItem.title,
        label = nil,
    }
    local label = deltaItem.title
    if label == nil then
        local _, filename = utils.split_path(deltaItem.filename)
        label = filename
    end
    deltaItem.label = label
    return deltaItem
end



















---- Thumbnailer (https://github.com/TheAMM/mpv_thumbnail_script)
-- mpv_thumbnail_script/lib/helpers.lua
-- (partial file) Only copied the needed functions
function clear_table(target)
  for key, value in pairs(target) do
    target[key] = nil
  end
end
ON_WINDOWS = (package.config:sub(1,1) ~= '/')
function is_absolute_path( path )
  local tmp, is_win  = path:gsub("^[A-Z]:\\", "")
  local tmp, is_unix = path:gsub("^/", "")
  return (is_win > 0) or (is_unix > 0)
end
function join_paths(...)
  local sep = ON_WINDOWS and "\\" or "/"
  local result = "";
  for i, p in pairs({...}) do
    if p ~= "" then
      if is_absolute_path(p) then
        result = p
      else
        result = (result ~= "") and (result:gsub("[\\"..sep.."]*$", "") .. sep .. p) or p
      end
    end
  end
  return result:gsub("[\\"..sep.."]*$", "")
end
function create_directories(path)
  local cmd
  if ON_WINDOWS then
    cmd = { args = {"cmd", "/c", "mkdir", path} }
  else
    cmd = { args = {"mkdir", "-p", path} }
  end
  utils.subprocess(cmd)
end
function file_exists(name)
  local f = io.open(name, "rb")
  if f ~= nil then
    local ok, err, code = f:read(1)
    io.close(f)
    return code == nil
  else
    return false
  end
end
-- Find an executable in PATH or CWD with the given name
function find_executable(name)
  local delim = ON_WINDOWS and ";" or ":"
  local pwd = os.getenv("PWD") or utils.getcwd()
  local path = os.getenv("PATH")
  local env_path = pwd .. delim .. path -- Check CWD first
  local result, filename
  for path_dir in env_path:gmatch("[^"..delim.."]+") do
    filename = join_paths(path_dir, name)
    if file_exists(filename) then
      result = filename
      break
    end
  end
  return result
end
-- Searches for an executable and caches the result if any
local ExecutableFinder = { path_cache = {} }
function ExecutableFinder:get_executable_path(name, raw_name)
  name = ON_WINDOWS and not raw_name and (name .. ".exe") or name
  if self.path_cache[name] == nil then
    self.path_cache[name] = find_executable(name) or false
  end
  return self.path_cache[name]
end



-- mpv_thumbnail_script/lib/sha1.lua
-- $Revision: 1.5 $
-- $Date: 2014-09-10 16:54:25 $

-- This module was originally taken from http://cube3d.de/uploads/Main/sha1.txt.

-------------------------------------------------------------------------------
-- SHA-1 secure hash computation, and HMAC-SHA1 signature computation,
-- in pure Lua (tested on Lua 5.1)
-- License: MIT
--
-- Usage:
-- local hashAsHex = sha1.hex(message) -- returns a hex string
-- local hashAsData = sha1.bin(message) -- returns raw bytes
--
-- local hmacAsHex = sha1.hmacHex(key, message) -- hex string
-- local hmacAsData = sha1.hmacBin(key, message) -- raw bytes
--
--
-- Pass sha1.hex() a string, and it returns a hash as a 40-character hex string.
-- For example, the call
--
-- local hash = sha1.hex("iNTERFACEWARE")
--
-- puts the 40-character string
--
-- "e76705ffb88a291a0d2f9710a5471936791b4819"
--
-- into the variable 'hash'
--
-- Pass sha1.hmacHex() a key and a message, and it returns the signature as a
-- 40-byte hex string.
--
--
-- The two "bin" versions do the same, but return the 20-byte string of raw
-- data that the 40-byte hex strings represent.
--
-------------------------------------------------------------------------------
--
-- Description
-- Due to the lack of bitwise operations in 5.1, this version uses numbers to
-- represents the 32bit words that we combine with binary operations. The basic
-- operations of byte based "xor", "or", "and" are all cached in a combination
-- table (several 64k large tables are built on startup, which
-- consumes some memory and time). The caching can be switched off through
-- setting the local cfg_caching variable to false.
-- For all binary operations, the 32 bit numbers are split into 8 bit values
-- that are combined and then merged again.
--
-- Algorithm: http://www.itl.nist.gov/fipspubs/fip180-1.htm
--
-------------------------------------------------------------------------------

local sha1 = (function()
local sha1 = {}

-- set this to false if you don't want to build several 64k sized tables when
-- loading this file (takes a while but grants a boost of factor 13)
local cfg_caching = false
-- local storing of global functions (minor speedup)
local floor,modf = math.floor,math.modf
local char,format,rep = string.char,string.format,string.rep

-- merge 4 bytes to an 32 bit word
local function bytes_to_w32 (a,b,c,d) return a*0x1000000+b*0x10000+c*0x100+d end
-- split a 32 bit word into four 8 bit numbers
local function w32_to_bytes (i)
   return floor(i/0x1000000)%0x100,floor(i/0x10000)%0x100,floor(i/0x100)%0x100,i%0x100
end

-- shift the bits of a 32 bit word. Don't use negative values for "bits"
local function w32_rot (bits,a)
   local b2 = 2^(32-bits)
   local a,b = modf(a/b2)
   return a+b*b2*(2^(bits))
end

-- caching function for functions that accept 2 arguments, both of values between
-- 0 and 255. The function to be cached is passed, all values are calculated
-- during loading and a function is returned that returns the cached values (only)
local function cache2arg (fn)
   if not cfg_caching then return fn end
   local lut = {}
   for i=0,0xffff do
      local a,b = floor(i/0x100),i%0x100
      lut[i] = fn(a,b)
   end
   return function (a,b)
      return lut[a*0x100+b]
   end
end

-- splits an 8-bit number into 8 bits, returning all 8 bits as booleans
local function byte_to_bits (b)
   local b = function (n)
      local b = floor(b/n)
      return b%2==1
   end
   return b(1),b(2),b(4),b(8),b(16),b(32),b(64),b(128)
end

-- builds an 8bit number from 8 booleans
local function bits_to_byte (a,b,c,d,e,f,g,h)
   local function n(b,x) return b and x or 0 end
   return n(a,1)+n(b,2)+n(c,4)+n(d,8)+n(e,16)+n(f,32)+n(g,64)+n(h,128)
end

-- debug function for visualizing bits in a string
local function bits_to_string (a,b,c,d,e,f,g,h)
   local function x(b) return b and "1" or "0" end
   return ("%s%s%s%s %s%s%s%s"):format(x(a),x(b),x(c),x(d),x(e),x(f),x(g),x(h))
end

-- debug function for converting a 8-bit number as bit string
local function byte_to_bit_string (b)
   return bits_to_string(byte_to_bits(b))
end

-- debug function for converting a 32 bit number as bit string
local function w32_to_bit_string(a)
   if type(a) == "string" then return a end
   local aa,ab,ac,ad = w32_to_bytes(a)
   local s = byte_to_bit_string
   return ("%s %s %s %s"):format(s(aa):reverse(),s(ab):reverse(),s(ac):reverse(),s(ad):reverse()):reverse()
end

-- bitwise "and" function for 2 8bit number
local band = cache2arg (function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A and a, B and b, C and c, D and d,
         E and e, F and f, G and g, H and h)
   end)

-- bitwise "or" function for 2 8bit numbers
local bor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A or a, B or b, C or c, D or d,
         E or e, F or f, G or g, H or h)
   end)

-- bitwise "xor" function for 2 8bit numbers
local bxor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
         A ~= a, B ~= b, C ~= c, D ~= d,
         E ~= e, F ~= f, G ~= g, H ~= h)
   end)

-- bitwise complement for one 8bit number
local function bnot (x)
   return 255-(x % 256)
end

-- creates a function to combine to 32bit numbers using an 8bit combination function
local function w32_comb(fn)
   return function (a,b)
      local aa,ab,ac,ad = w32_to_bytes(a)
      local ba,bb,bc,bd = w32_to_bytes(b)
      return bytes_to_w32(fn(aa,ba),fn(ab,bb),fn(ac,bc),fn(ad,bd))
   end
end

-- create functions for and, xor and or, all for 2 32bit numbers
local w32_and = w32_comb(band)
local w32_xor = w32_comb(bxor)
local w32_or = w32_comb(bor)

-- xor function that may receive a variable number of arguments
local function w32_xor_n (a,...)
   local aa,ab,ac,ad = w32_to_bytes(a)
   for i=1,select('#',...) do
      local ba,bb,bc,bd = w32_to_bytes(select(i,...))
      aa,ab,ac,ad = bxor(aa,ba),bxor(ab,bb),bxor(ac,bc),bxor(ad,bd)
   end
   return bytes_to_w32(aa,ab,ac,ad)
end

-- combining 3 32bit numbers through binary "or" operation
local function w32_or3 (a,b,c)
   local aa,ab,ac,ad = w32_to_bytes(a)
   local ba,bb,bc,bd = w32_to_bytes(b)
   local ca,cb,cc,cd = w32_to_bytes(c)
   return bytes_to_w32(
      bor(aa,bor(ba,ca)), bor(ab,bor(bb,cb)), bor(ac,bor(bc,cc)), bor(ad,bor(bd,cd))
   )
end

-- binary complement for 32bit numbers
local function w32_not (a)
   return 4294967295-(a % 4294967296)
end

-- adding 2 32bit numbers, cutting off the remainder on 33th bit
local function w32_add (a,b) return (a+b) % 4294967296 end

-- adding n 32bit numbers, cutting off the remainder (again)
local function w32_add_n (a,...)
   for i=1,select('#',...) do
      a = (a+select(i,...)) % 4294967296
   end
   return a
end
-- converting the number to a hexadecimal string
local function w32_to_hexstring (w) return format("%08x",w) end

-- calculating the SHA1 for some text
function sha1.hex(msg)
   local H0,H1,H2,H3,H4 = 0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
   local msg_len_in_bits = #msg * 8

   local first_append = char(0x80) -- append a '1' bit plus seven '0' bits

   local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
   local current_mod = non_zero_message_bytes % 64
   local second_append = current_mod>0 and rep(char(0), 64 - current_mod) or ""

   -- now to append the length as a 64-bit number.
   local B1, R1 = modf(msg_len_in_bits / 0x01000000)
   local B2, R2 = modf( 0x01000000 * R1 / 0x00010000)
   local B3, R3 = modf( 0x00010000 * R2 / 0x00000100)
   local B4 = 0x00000100 * R3

   local L64 = char( 0) .. char( 0) .. char( 0) .. char( 0) -- high 32 bits
   .. char(B1) .. char(B2) .. char(B3) .. char(B4) -- low 32 bits

   msg = msg .. first_append .. second_append .. L64

   assert(#msg % 64 == 0)

   local chunks = #msg / 64

   local W = { }
   local start, A, B, C, D, E, f, K, TEMP
   local chunk = 0

   while chunk < chunks do
      --
      -- break chunk up into W[0] through W[15]
      --
      start,chunk = chunk * 64 + 1,chunk + 1

      for t = 0, 15 do
         W[t] = bytes_to_w32(msg:byte(start, start + 3))
         start = start + 4
      end

      --
      -- build W[16] through W[79]
      --
      for t = 16, 79 do
         -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16).
         W[t] = w32_rot(1, w32_xor_n(W[t-3], W[t-8], W[t-14], W[t-16]))
      end

      A,B,C,D,E = H0,H1,H2,H3,H4

      for t = 0, 79 do
         if t <= 19 then
            -- (B AND C) OR ((NOT B) AND D)
            f = w32_or(w32_and(B, C), w32_and(w32_not(B), D))
            K = 0x5A827999
         elseif t <= 39 then
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0x6ED9EBA1
         elseif t <= 59 then
            -- (B AND C) OR (B AND D) OR (C AND D
            f = w32_or3(w32_and(B, C), w32_and(B, D), w32_and(C, D))
            K = 0x8F1BBCDC
         else
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0xCA62C1D6
         end

         -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt;
         A,B,C,D,E = w32_add_n(w32_rot(5, A), f, E, W[t], K),
         A, w32_rot(30, B), C, D
      end
      -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E.
      H0,H1,H2,H3,H4 = w32_add(H0, A),w32_add(H1, B),w32_add(H2, C),w32_add(H3, D),w32_add(H4, E)
   end
   local f = w32_to_hexstring
   return f(H0) .. f(H1) .. f(H2) .. f(H3) .. f(H4)
end

local function hex_to_binary(hex)
   return hex:gsub('..', function(hexval)
         return string.char(tonumber(hexval, 16))
      end)
end

function sha1.bin(msg)
   return hex_to_binary(sha1.hex(msg))
end

local xor_with_0x5c = {}
local xor_with_0x36 = {}
-- building the lookuptables ahead of time (instead of littering the source code
-- with precalculated values)
for i=0,0xff do
   xor_with_0x5c[char(i)] = char(bxor(i,0x5c))
   xor_with_0x36[char(i)] = char(bxor(i,0x36))
end

local blocksize = 64 -- 512 bits

function sha1.hmacHex(key, text)
   assert(type(key) == 'string', "key passed to hmacHex should be a string")
   assert(type(text) == 'string', "text passed to hmacHex should be a string")

   if #key > blocksize then
      key = sha1.bin(key)
   end

   local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
   local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)

   return sha1.hex(key_xord_with_0x5c .. sha1.bin(key_xord_with_0x36 .. text))
end

function sha1.hmacBin(key, text)
   return hex_to_binary(sha1.hmacHex(key, text))
end

return sha1
end)()



-- mpv_thumbnail_script/src/options.lua
local SCRIPT_NAME = "mpv_thumbnail_script"

local default_cache_base = ON_WINDOWS and os.getenv("TEMP") or "/tmp/"

local thumbnailer_options = {
    -- The thumbnail directory
    cache_directory = join_paths(default_cache_base, "mpv_thumbs_cache"),

    ------------------------
    -- Generation options --
    ------------------------

    -- Automatically generate the thumbnails on video load, without a keypress
    autogenerate = true,

    -- Only automatically thumbnail videos shorter than this (seconds)
    autogenerate_max_duration = 3600, -- 1 hour

    -- SHA1-sum filenames over this length
    -- It's nice to know what files the thumbnails are (hence directory names)
    -- but long URLs may approach filesystem limits.
    hash_filename_length = 128,

    -- Use mpv to generate thumbnail even if ffmpeg is found in PATH
    -- ffmpeg does not handle ordered chapters (MKVs which rely on other MKVs)!
    -- mpv is a bit slower, but has better support overall (eg. subtitles in the previews)
    prefer_mpv = true,

    -- Explicitly disable subtitles on the mpv sub-calls
    mpv_no_sub = false,
    -- Add a "--no-config" to the mpv sub-call arguments
    mpv_no_config = false,
    -- Add a "--profile=<mpv_profile>" to the mpv sub-call arguments
    -- Use "" to disable
    mpv_profile = "",
    -- Output debug logs to <thumbnail_path>.log, ala <cache_directory>/<video_filename>/000000.bgra.log
    -- The logs are removed after successful encodes, unless you set mpv_keep_logs below
    mpv_logs = true,
    -- Keep all mpv logs, even the succesfull ones
    mpv_keep_logs = false,

    -- Disable the built-in keybind ("T") to add your own
    disable_keybinds = false,

    ---------------------
    -- Display options --
    ---------------------

    -- Move the thumbnail up or down
    -- For example:
    --   topbar/bottombar: 24
    --   rest: 0
    vertical_offset = 24,

    -- Adjust background padding
    -- Examples:
    --   topbar:       0, 10, 10, 10
    --   bottombar:   10,  0, 10, 10
    --   slimbox/box: 10, 10, 10, 10
    pad_top   = 10,
    pad_bot   =  0,
    pad_left  = 10,
    pad_right = 10,

    -- If true, pad values are screen-pixels. If false, video-pixels.
    pad_in_screenspace = true,
    -- Calculate pad into the offset
    offset_by_pad = true,

    -- Background color in BBGGRR
    background_color = "000000",
    -- Alpha: 0 - fully opaque, 255 - transparent
    background_alpha = 80,

    -- Keep thumbnail on the screen near left or right side
    constrain_to_screen = true,

    -- Do not display the thumbnailing progress
    hide_progress = false,

    -----------------------
    -- Thumbnail options --
    -----------------------

    -- The maximum dimensions of the thumbnails (pixels)
    thumbnail_width = 200,
    thumbnail_height = 200,

    -- The thumbnail count target
    -- (This will result in a thumbnail every ~10 seconds for a 25 minute video)
    thumbnail_count = 150,

    -- The above target count will be adjusted by the minimum and
    -- maximum time difference between thumbnails.
    -- The thumbnail_count will be used to calculate a target separation,
    -- and min/max_delta will be used to constrict it.

    -- In other words, thumbnails will be:
    --   at least min_delta seconds apart (limiting the amount)
    --   at most max_delta seconds apart (raising the amount if needed)
    min_delta = 5,
    -- 120 seconds aka 2 minutes will add more thumbnails when the video is over 5 hours!
    max_delta = 90,


    -- Overrides for remote urls (you generally want less thumbnails!)
    -- Thumbnailing network paths will be done with mpv

    -- Allow thumbnailing network paths (naive check for "://")
    thumbnail_network = false,
    -- Override thumbnail count, min/max delta
    remote_thumbnail_count = 60,
    remote_min_delta = 15,
    remote_max_delta = 120,

    -- Try to grab the raw stream and disable ytdl for the mpv subcalls
    -- Much faster than passing the url to ytdl again, but may cause problems with some sites
    remote_direct_stream = true,
}

read_options(thumbnailer_options, SCRIPT_NAME)



-- mpv_thumbnail_script/src/thumbnailer_shared.lua
local Thumbnailer = {
    cache_directory = thumbnailer_options.cache_directory,

    state = {
        ready = false,
        available = false,
        enabled = false,

        thumbnail_template = nil,

        thumbnail_delta = nil,
        thumbnail_count = 0,

        thumbnail_size = nil,

        finished_thumbnails = 0,

        -- List of thumbnail states (from 1 to thumbnail_count)
        -- ready: 1
        -- in progress: 0
        -- not ready: -1
        thumbnails = {},

        worker_input_path = nil,
        -- Extra options for the workers
        worker_extra = {},
    },
    -- Set in register_client
    worker_register_timeout = nil,
    -- A timer used to wait for more workers in case we have none
    worker_wait_timer = nil,
    workers = {}
}

function Thumbnailer:clear_state()
    clear_table(self.state)
    self.state.ready = false
    self.state.available = false
    self.state.finished_thumbnails = 0
    self.state.thumbnails = {}
    self.state.worker_extra = {}
end


function Thumbnailer:on_file_loaded()
    self:clear_state()
end

function Thumbnailer:on_thumb_ready(index)
    self.state.thumbnails[index] = 1

    -- Full recount instead of a naive increment (let's be safe!)
    self.state.finished_thumbnails = 0
    for i, v in pairs(self.state.thumbnails) do
        if v > 0 then
            self.state.finished_thumbnails = self.state.finished_thumbnails + 1
        end
    end
end

function Thumbnailer:on_thumb_progress(index)
    if self.state.thumbnails[index] == nil then
        msg.warn("self.state.thumbnails[index] == nil", index, "count", #self.state.thumbnails)
        return
    end
    self.state.thumbnails[index] = math.max(self.state.thumbnails[index], 0)
end

function Thumbnailer:on_start_file()
    -- Clear state when a new file is being loaded
    self:clear_state()
end

function Thumbnailer:on_video_change(params)
    -- Gather a new state when we get proper video-dec-params and our state is empty
    if params ~= nil then
        if not self.state.ready then
            self:update_state()
        end
    end
end


function Thumbnailer:update_state()
    msg.debug("Gathering video/thumbnail state")

    self.state.thumbnail_delta = self:get_delta()
    self.state.thumbnail_count = self:get_thumbnail_count(self.state.thumbnail_delta)

    -- Prefill individual thumbnail states
    for i = 1, self.state.thumbnail_count do
        self.state.thumbnails[i] = -1
    end

    self.state.thumbnail_template, self.state.thumbnail_directory = self:get_thumbnail_template()
    self.state.thumbnail_size = self:get_thumbnail_size()

    self.state.ready = true

    local file_path = mp.get_property_native("path")
    self.state.is_remote = file_path:find("://") ~= nil

    self.state.available = false

    -- Make sure the file has video (and not just albumart)
    local track_list = mp.get_property_native("track-list")
    local has_video = false
    for i, track in pairs(track_list) do
        if track.type == "video" and not track.external and not track.albumart then
            has_video = true
            break
        end
    end

    if has_video and self.state.thumbnail_delta ~= nil and self.state.thumbnail_size ~= nil and self.state.thumbnail_count > 0 then
        self.state.available = true
    end

    msg.debug("Thumbnailer.state:", utils.to_string(self.state))

end


function Thumbnailer:get_thumbnail_template()
    local file_path = mp.get_property_native("path")
    local is_remote = file_path:find("://") ~= nil

    local filename = mp.get_property_native("filename/no-ext")
    local filesize = mp.get_property_native("file-size", 0)

    if is_remote then
        filesize = 0
    end

    filename = filename:gsub('[^a-zA-Z0-9_.%-\' ]', '')
    -- Hash overly long filenames (most likely URLs)
    if #filename > thumbnailer_options.hash_filename_length then
        filename = sha1.hex(filename)
    end

    local file_key = ("%s-%d"):format(filename, filesize)

    local thumbnail_directory = join_paths(self.cache_directory, file_key)
    local file_template = join_paths(thumbnail_directory, "%06d.bgra")
    return file_template, thumbnail_directory
end


function Thumbnailer:get_thumbnail_size()
    local video_dec_params = mp.get_property_native("video-dec-params")
    local video_width = video_dec_params.dw
    local video_height = video_dec_params.dh
    if not (video_width and video_height) then
        return nil
    end

    local w, h
    if video_width > video_height then
        w = thumbnailer_options.thumbnail_width
        h = math.floor(video_height * (w / video_width))
    else
        h = thumbnailer_options.thumbnail_height
        w = math.floor(video_width * (h / video_height))
    end
    return { w=w, h=h }
end


function Thumbnailer:get_delta()
    local file_path = mp.get_property_native("path")
    local file_duration = mp.get_property_native("duration")
    local is_seekable = mp.get_property_native("seekable")

    -- Naive url check
    local is_remote = file_path:find("://") ~= nil

    local remote_and_disallowed = is_remote
    if is_remote and thumbnailer_options.thumbnail_network then
        remote_and_disallowed = false
    end

    if remote_and_disallowed or not is_seekable or not file_duration then
        -- Not a local path (or remote thumbnails allowed), not seekable or lacks duration
        return nil
    end

    local thumbnail_count = thumbnailer_options.thumbnail_count
    local min_delta = thumbnailer_options.min_delta
    local max_delta = thumbnailer_options.max_delta

    if is_remote then
        thumbnail_count = thumbnailer_options.remote_thumbnail_count
        min_delta = thumbnailer_options.remote_min_delta
        max_delta = thumbnailer_options.remote_max_delta
    end

    local target_delta = (file_duration / thumbnail_count)
    local delta = math.max(min_delta, math.min(max_delta, target_delta))

    return delta
end


function Thumbnailer:get_thumbnail_count(delta)
    if delta == nil then
        return 0
    end
    local file_duration = mp.get_property_native("duration")

    return math.ceil(file_duration / delta)
end

function Thumbnailer:get_closest(thumbnail_index)
    -- Given a 1-based index, find the closest available thumbnail and return it's 1-based index

    -- Check the direct thumbnail index first
    if self.state.thumbnails[thumbnail_index] > 0 then
        return thumbnail_index
    end

    local min_distance = self.state.thumbnail_count + 1
    local closest = nil

    -- Naive, inefficient, lazy. But functional.
    for index, value in pairs(self.state.thumbnails) do
        local distance = math.abs(index - thumbnail_index)
        if distance < min_distance and value > 0 then
            min_distance = distance
            closest = index
        end
    end
    return closest
end

function Thumbnailer:get_thumbnail_index(time_position)
    -- Returns a 1-based thumbnail index for the given timestamp (between 1 and thumbnail_count, inclusive)
    if self.state.thumbnail_delta and (self.state.thumbnail_count and self.state.thumbnail_count > 0) then
        return math.min(math.floor(time_position / self.state.thumbnail_delta) + 1, self.state.thumbnail_count)
    else
        return nil
    end
end

function Thumbnailer:get_thumbnail_path(time_position)
    -- Given a timestamp, return:
    --   the closest available thumbnail path (if any)
    --   the 1-based thumbnail index calculated from the timestamp
    --   the 1-based thumbnail index of the closest available (and used) thumbnail
    -- OR nil if thumbnails are not available.

    local thumbnail_index = self:get_thumbnail_index(time_position)
    if not thumbnail_index then return nil end

    local closest = self:get_closest(thumbnail_index)

    if closest ~= nil then
        return self.state.thumbnail_template:format(closest-1), thumbnail_index, closest
    else
        return nil, thumbnail_index, nil
    end
end

function Thumbnailer:register_client()
    self.worker_register_timeout = mp.get_time() + 2

    mp.register_script_message("mpv_thumbnail_script-ready", function(index, path)
        self:on_thumb_ready(tonumber(index), path)
    end)
    mp.register_script_message("mpv_thumbnail_script-progress", function(index, path)
        self:on_thumb_progress(tonumber(index), path)
    end)

    mp.register_script_message("mpv_thumbnail_script-worker", function(worker_name)
        if not self.workers[worker_name] then
            msg.debug("Registered worker", worker_name)
            self.workers[worker_name] = true
            mp.commandv("script-message-to", worker_name, "mpv_thumbnail_script-slaved")
        end
    end)

    -- Notify workers to generate thumbnails when video loads/changes
    -- This will be executed after the on_video_change (because it's registered after it)
    mp.observe_property("video-dec-params", "native", function()
        local duration = mp.get_property_native("duration")
        local max_duration = thumbnailer_options.autogenerate_max_duration

        if duration ~= nil and self.state.available and thumbnailer_options.autogenerate then
            -- Notify if autogenerate is on and video is not too long
            if duration < max_duration or max_duration == 0 then
                self:start_worker_jobs()
            end
        end
    end)

    local thumb_script_key = not thumbnailer_options.disable_keybinds and "T" or nil
    mp.add_key_binding(thumb_script_key, "generate-thumbnails", function()
        if self.state.available then
            mp.osd_message("Started thumbnailer jobs")
            self:start_worker_jobs()
        else
            mp.osd_message("Thumbnailing unavailabe")
        end
    end)
end

function Thumbnailer:_create_thumbnail_job_order()
    -- Returns a list of 1-based thumbnail indices in a job order
    local used_frames = {}
    local work_frames = {}

    -- Pick frames in increasing frequency.
    -- This way we can do a quick few passes over the video and then fill in the gaps.
    for x = 6, 0, -1 do
        local nth = (2^x)

        for thi = 1, self.state.thumbnail_count, nth do
            if not used_frames[thi] then
                table.insert(work_frames, thi)
                used_frames[thi] = true
            end
        end
    end
    return work_frames
end

function Thumbnailer:prepare_source_path()
    local file_path = mp.get_property_native("path")

    if self.state.is_remote and thumbnailer_options.remote_direct_stream then
        -- Use the direct stream (possibly) provided by ytdl
        -- This skips ytdl on the sub-calls, making the thumbnailing faster
        -- Works well on YouTube, rest not really tested
        file_path = mp.get_property_native("stream-path")

        -- edl:// urls can get LONG. In which case, save the path (URL)
        -- to a temporary file and use that instead.
        local playlist_filename = join_paths(self.state.thumbnail_directory, "playlist.txt")

        if #file_path > 8000 then
            -- Path is too long for a playlist - just pass the original URL to
            -- workers and allow ytdl
            self.state.worker_extra.enable_ytdl = true
            file_path = mp.get_property_native("path")
            msg.warn("Falling back to original URL and ytdl due to LONG source path. This will be slow.")

        elseif #file_path > 1024 then
            local playlist_file = io.open(playlist_filename, "wb")
            if not playlist_file then
                msg.error(("Tried to write a playlist to %s but couldn't!"):format(playlist_file))
                return false
            end

            playlist_file:write(file_path .. "\n")
            playlist_file:close()

            file_path = "--playlist=" .. playlist_filename
            msg.warn("Using playlist workaround due to long source path")
        end
    end

    self.state.worker_input_path = file_path
    return true
end

function Thumbnailer:start_worker_jobs()
    -- Create directory for the thumbnails, if needed
    local l, err = utils.readdir(self.state.thumbnail_directory)
    if err then
        msg.debug("Creating thumbnail directory", self.state.thumbnail_directory)
        create_directories(self.state.thumbnail_directory)
    end

    -- Try to prepare the source path for workers, and bail if unable to do so
    if not self:prepare_source_path() then
        return
    end

    local worker_list = {}
    for worker_name in pairs(self.workers) do table.insert(worker_list, worker_name) end

    local worker_count = #worker_list

    -- In case we have a worker timer created already, clear it
    -- (For example, if the video-dec-params change in quick succession or the user pressed T, etc)
    if self.worker_wait_timer then
        self.worker_wait_timer:stop()
    end

    if worker_count == 0 then
        local now = mp.get_time()
        if mp.get_time() > self.worker_register_timeout then
            -- Workers have had their time to register but we have none!
            local err = "No thumbnail workers found. Make sure you are not missing a script!"
            msg.error(err)
            mp.osd_message(err, 3)

        else
            -- We may be too early. Delay the work start a bit to try again.
            msg.warn("No workers found. Waiting a bit more for them.")
            -- Wait at least half a second
            local wait_time = math.max(self.worker_register_timeout - now, 0.5)
            self.worker_wait_timer = mp.add_timeout(wait_time, function() self:start_worker_jobs() end)
        end

    else
        -- We have at least one worker. This may not be all of them, but they have had
        -- their time to register; we've done our best waiting for them.
        self.state.enabled = true

        msg.debug( ("Splitting %d thumbnails amongst %d worker(s)"):format(self.state.thumbnail_count, worker_count) )

        local frame_job_order = self:_create_thumbnail_job_order()
        local worker_jobs = {}
        for i = 1, worker_count do worker_jobs[worker_list[i]] = {} end

        -- Split frames amongst the workers
        for i, thumbnail_index in ipairs(frame_job_order) do
            local worker_id = worker_list[ ((i-1) % worker_count) + 1 ]
            table.insert(worker_jobs[worker_id], thumbnail_index)
        end

        local state_json_string = utils.format_json(self.state)
        msg.debug("Giving workers state:", state_json_string)

        for worker_name, worker_frames in pairs(worker_jobs) do
            if #worker_frames > 0 then
                local frames_json_string = utils.format_json(worker_frames)
                msg.debug("Assigning job to", worker_name, frames_json_string)
                mp.commandv("script-message-to", worker_name, "mpv_thumbnail_script-job", state_json_string, frames_json_string)
            end
        end
    end
end

mp.register_event("start-file", function() Thumbnailer:on_start_file() end)
mp.observe_property("video-dec-params", "native", function(name, params) Thumbnailer:on_video_change(params) end)


-- osc_tethys ExecutableFinder checks
ExecutableFinder.hasChecked = false
ExecutableFinder.hasFfmpeg = false
ExecutableFinder.hasMpv = false
ExecutableFinder.hasMpvNet = false
function ExecutableFinder:check()
    if ExecutableFinder.hasChecked then
        return
    end
    ExecutableFinder.hasFfmpeg = ExecutableFinder:get_executable_path("ffmpeg")
    ExecutableFinder.hasMpv = ExecutableFinder:get_executable_path("mpv")
    ExecutableFinder.hasMpvNet = ExecutableFinder:get_executable_path("mpvnet")
    ExecutableFinder.hasChecked = true
    -- msg.warn("hasFfmpeg", ExecutableFinder.hasFfmpeg)
    -- msg.warn("hasMpv", ExecutableFinder.hasMpv)
    -- msg.warn("hasMpvNet", ExecutableFinder.hasMpvNet)
end


-- osc_tethys mpv_thumbnail_script overrides
thumbnailer_options.thumbnail_width = tethys.thumbnailSize
thumbnailer_options.thumbnail_height = tethys.thumbnailSize
thumbnailer_options.mpv_no_config = true
thumbnailer_options.mpv_no_sub = true
thumbnailer_options.hide_progress = true -- Not implemented

Thumbnailer:register_client()


-- Thumbnail State
function ThumbState()
    return {
        overlayId = 1,
        visible = false,
        wasVisible = false,
        thumbPath = nil,
        globalWidth = nil,
        globalHeight = nil,
    }
end
local seekbarThumb = ThumbState()
seekbarThumb.overlayId = 1



















-- Render Funcs
function calcTrackButtonWidth(trackArr)
    -- "ICON -/0" or "ICON 1/1" or "ICON 1/10"
    local trackButtonSize = tethys.trackButtonSize
    local trackIconWidth = trackButtonSize * (32/23.273)
    local trackDigitWidth = trackButtonSize * (tethys.trackTextScale / 100) * 0.4
    local spaceDigitRatio = 0.4
    local slashDigitRatio = 0.7
    -- print("trackButtonSize", trackButtonSize)
    -- print("trackIconWidth", trackIconWidth)
    -- print("trackDigitWidth", trackDigitWidth)
    local numTrackDigits = 1
    if trackArr ~= nil and #trackArr > 0 then
        numTrackDigits = math.floor(math.log(#trackArr, 10)) + 1
    end
    local trackButtonWidth = math.ceil(trackIconWidth + trackDigitWidth * (spaceDigitRatio + numTrackDigits + slashDigitRatio + numTrackDigits))
    -- print("numTrackDigits", numTrackDigits)
    -- print("trackButtonWidth", trackButtonWidth)
    return trackButtonWidth
end

-- Thumbnail Funcs
function canShowThumb(videoPath)
    local isRemote = videoPath:find("://") ~= nil
    ExecutableFinder:check()
    if not (ExecutableFinder.hasMpv or ExecutableFinder.hasMpvNet or ExecutableFinder.hasFfmpeg) then
        return false
    end
    if isRemote then
        return false
    end
    return true
end

function showThumbnail(thumbState, globalX, globalY)
    -- https://mpv.io/manual/master/#command-interface-overlay-add
    -- msg.warn("showThumbnail", thumbState.overlayId)
    mp.command_native({
        "overlay-add", thumbState.overlayId,
        globalX, globalY,
        thumbState.thumbPath,
        0, -- byte offset
        "bgra", -- image format
        thumbState.globalWidth, thumbState.globalHeight,
        thumbState.globalWidth * 4, -- "stride"
    })
    thumbState.visible = true
end
function hideThumbnail(thumbState)
    -- https://mpv.io/manual/master/#command-interface-overlay-remove
    -- msg.warn("hideThumbnail", thumbState.overlayId)
    mp.command_native({
        "overlay-remove", thumbState.overlayId,
    })
end
function thumbPreRender(thumbState)
    thumbState.wasVisible = thumbState.visible
    thumbState.visible = false
end
function thumbPostRender(thumbState)
    if not thumbState.visible and thumbState.wasVisible then
        hideThumbnail(thumbState)
    end
end
function preRenderThumbnails()
    thumbPreRender(seekbarThumb)
end
function postRenderThumbnails()
    thumbPostRender(seekbarThumb)
end

-- From: Slider.tooltipF(pos)
function formatTimestamp(percent)
    local duration = mp.get_property_number("duration", nil)
    if not ((duration == nil) or (percent == nil)) then
        local sec = duration * (percent / 100)
        return mp.format_time(sec)
    else
        return ""
    end
end

-- Seekbar Tooltip
function renderThumbnailTooltip(pos, sliderPos, ass)
    local tooltipBgColor = "FFFFFF"
    local tooltipBgAlpha = 80
    local thumbOutline = 3

    local videoPath = mp.get_property_native("path", nil)
    local videoDuration = mp.get_property_number("duration", nil)
    -- msg.warn("sliderPos", sliderPos, "videoDuration", videoDuration, "videoPath", videoPath)
    if (videoPath == nil) or (videoDuration == nil) or (sliderPos == nil) then
        return
    end
    local thumbTime = videoDuration * (sliderPos / 100)
    local thumbTimestamp = mp.format_time(thumbTime) -- ffmpeg requires "HH:MM:SS.zzz" for seeking
    local timestampLabel = thumbTimestamp
    -- msg.warn("thumbTime", thumbTime, "timestampLabel", timestampLabel)

    ---- Geometry
    local scaleX, scaleY = get_virt_scale_factor()
    local videoDecParams = mp.get_property_native("video-dec-params")
    local videoWidth = videoDecParams.dw
    local videoHeight = videoDecParams.dh
    if not (videoWidth and videoHeight) then
        return
    end

    local thumb_size = Thumbnailer.state.thumbnail_size
    if thumb_size == nil then
        return
    end
    local thumbGlobalWidth = thumb_size.w
    local thumbGlobalHeight = thumb_size.h
    local thumbWidth =  math.floor(thumbGlobalWidth * scaleX)
    local thumbHeight =  math.floor(thumbGlobalHeight * scaleY)

    local chapter = get_chapter(thumbTime)
    local hasChapter = not (chapter == nil) and chapter.title and chapter.title ~= ""
    local showChapter = hasChapter and tethys.showChapterTooltip
    local chapterLabel = ""
    local chapterHeight = 0
    if showChapter then
        chapterHeight = tethys.seekbarTimestampSize
        chapterLabel = chapter.title
    end

    local timestampWidth = thumbWidth
    local timestampHeight = tethys.seekbarTimestampSize

    local bgHeight = thumbOutline + thumbHeight + thumbOutline

    local tooltipWidth = thumbOutline + thumbWidth + thumbOutline
    local tooltipHeight = bgHeight + chapterHeight + timestampHeight


    -- Note: pos x,y is an=2 (bottom-center)
    local windowWidth = osc_param.playresx
    local tooltipX = math.floor(pos.x - tooltipWidth/2)
    local tooltipY = math.floor(pos.y - tooltipHeight)
    local textAn = 5 -- x,y is center
    local isLongChapter
    if tooltipX < 0 then
        tooltipX = 0
        textAn = 4 -- x,y is left-center
    elseif windowWidth - tooltipWidth < tooltipX then
        tooltipX = windowWidth - tooltipWidth
        textAn = 6 -- x,y is right-center
    end

    local thumbX = tooltipX + thumbOutline
    local thumbY = tooltipY + thumbOutline
    local thumbGlobalX = math.floor(thumbX / scaleX)
    local thumbGlobalY = math.floor(thumbY / scaleY)
    -- msg.warn("thumbX", thumbX, "thumbY", thumbY, "thumbGlobalX", thumbGlobalX, "thumbGlobalY", thumbGlobalY)


    local longChapterTitle = chapterLabel:len() >= 30
    local chapterAn = longChapterTitle and textAn or 5 -- x,y is center
    local chapterX
    if chapterAn == 4 then -- Left-Center
        chapterX = thumbX
    elseif chapterAn == 6 then -- Right-Center
        chapterX = thumbX + thumbWidth
    else -- Center
        chapterX = thumbX + math.floor(thumbWidth/2)
    end
    local chapterY = thumbY + thumbHeight + math.floor(chapterHeight/2)

    local timestampAn = 5 -- x,y is center
    local timestampX = thumbX + math.floor(thumbWidth/2)
    local timestampY = thumbY + thumbHeight + chapterHeight + math.floor(timestampHeight/2)

    ---- Chapter
    if showChapter then
        ass:new_event()
        ass:pos(chapterX, chapterY)
        ass:an(chapterAn)
        ass:append(tethysStyle.seekbarTimestamp)
        ass:append(chapterLabel)
    end

    ---- Timestamp
    ass:new_event()
    ass:pos(timestampX, timestampY)
    ass:an(timestampAn)
    ass:append(tethysStyle.seekbarTimestamp)
    ass:append(timestampLabel)

    -- If thumbnails are not available, bail
    if not (Thumbnailer.state.enabled and Thumbnailer.state.available) then
        return
    end

    local thumbPath, thumbIndex, closestIndex = Thumbnailer:get_thumbnail_path(thumbTime)
    -- msg.warn("renderThumbnailTooltip", thumbIndex, closestIndex, thumbPath)

    if thumbPath then
        ---- Thumb BG/Outline
        ass:new_event()
        ass:pos(tooltipX, tooltipY)
        ass:append(("{\\bord0\\1c&H%s&\\1a&H%X&}"):format(tooltipBgColor, tooltipBgAlpha))
        ass:draw_start()
        ass:rect_cw(0, 0, tooltipWidth, bgHeight)
        ass:draw_stop()

        ---- Thumb BG
        if not (tooltipBgAlpha == 0) then
            -- Overlay Image must be drawn on top of a solid color or else it'll look
            -- like it was filtered.
            ass:new_event()
            ass:pos(thumbX, thumbY)
            ass:append(("{\\bord0\\1c&H%s&\\1a&H%X&}"):format(tooltipBgColor, 0))
            ass:draw_start()
            ass:rect_cw(0, 0, thumbWidth, thumbHeight)
            ass:draw_stop()
        end

        ---- Render Thumbnail
        seekbarThumb.thumbPath = thumbPath
        seekbarThumb.globalWidth = thumbGlobalWidth
        seekbarThumb.globalHeight = thumbGlobalHeight
        showThumbnail(seekbarThumb, thumbGlobalX, thumbGlobalY)
    end
end

-- Playlist Tooltip
function renderPlaylistTooltip(pos, playlistDelta, ass)
    local deltaItem = getDeltaPlaylistItem(playlistDelta)
    if deltaItem == nil then
        return nil
    end

    local videoPath = deltaItem.filename
    local thumbTimestamp = mp.format_time(0.5)
    local thumbGlobalWidth = 100
    local thumbGlobalHeight = 100
end



















-- internal states, do not touch
local state = {
    showtime,                               -- time of last invocation (last mouse move)
    osc_visible = false,
    anistart,                               -- time when the animation started
    anitype,                                -- current type of animation
    animation,                              -- current animation alpha
    mouse_down_counter = 0,                 -- used for softrepeat
    active_element = nil,                   -- nil = none, 0 = background, 1+ = see elements[]
    active_event_source = nil,              -- the "button" that issued the current event
    rightTC_trem = not user_opts.timetotal, -- if the right timecode should display total or remaining time
    tc_ms = user_opts.timems,               -- Should the timecodes display their time with milliseconds
    mp_screen_sizeX, mp_screen_sizeY,       -- last screen-resolution, to detect resolution changes to issue reINITs
    initREQ = false,                        -- is a re-init request pending?
    marginsREQ = false,                     -- is a margins update pending?
    last_mouseX, last_mouseY,               -- last mouse position, to detect significant mouse movement
    mouse_in_window = false,
    message_text,
    message_hide_timer,
    fullscreen = false,
    tick_timer = nil,
    tick_last_time = 0,                     -- when the last tick() was run
    hide_timer = nil,
    cache_state = nil,
    idle = false,
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    dmx_cache = 0,
    using_video_margins = false,
    border = true,
    maximized = false,
    osd = mp.create_osd_overlay("ass-events"),
    chapter_list = {},                      -- sorted by time
}

local window_control_box_width = 80
local tick_delay = 0.03

local is_december = os.date("*t").month == 12

--
-- Helperfunctions
--

function kill_animation()
    state.anistart = nil
    state.animation = nil
    state.anitype =  nil
end

function set_osd(res_x, res_y, text)
    if state.osd.res_x == res_x and
       state.osd.res_y == res_y and
       state.osd.data == text then
        return
    end
    state.osd.res_x = res_x
    state.osd.res_y = res_y
    state.osd.data = text
    state.osd.z = 1000
    state.osd:update()
end

local margins_opts = {
    {"l", "video-margin-ratio-left"},
    {"r", "video-margin-ratio-right"},
    {"t", "video-margin-ratio-top"},
    {"b", "video-margin-ratio-bottom"},
}

-- scale factor for translating between real and virtual ASS coordinates
function get_virt_scale_factor()
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        return 0, 0
    end
    return osc_param.playresx / w, osc_param.playresy / h
end

-- return mouse position in virtual ASS coordinates (playresx/y)
function get_virt_mouse_pos()
    if state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
end

function scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment
function get_hitbox_coords(x, y, an, w, h)

    local alignments = {
      [1] = function () return x, y-h, x+w, y end,
      [2] = function () return x-(w/2), y-h, x+(w/2), y end,
      [3] = function () return x-w, y-h, x, y end,

      [4] = function () return x, y-(h/2), x+w, y+(h/2) end,
      [5] = function () return x-(w/2), y-(h/2), x+(w/2), y+(h/2) end,
      [6] = function () return x-w, y-(h/2), x, y+(h/2) end,

      [7] = function () return x, y, x+w, y+h end,
      [8] = function () return x-(w/2), y, x+(w/2), y+h end,
      [9] = function () return x-w, y, x, y+h end,
    }

    return alignments[an]()
end

function get_hitbox_coords_geo(geometry)
    return get_hitbox_coords(geometry.x, geometry.y, geometry.an,
        geometry.w, geometry.h)
end

function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1,
        element.hitbox.x2, element.hitbox.y2
end

function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

function limit_range(min, max, val)
    if val > max then
        val = max
    elseif val < min then
        val = min
    end
    return val
end

-- translate value into element coordinates
function get_slider_ele_pos_for(element, val)

    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return limit_range(
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        ele_pos)
end

-- translates global (mouse) coordinates to value
function get_slider_value_at(element, glob_pos)

    local val = scale_value(
        element.slider.min.glob_pos, element.slider.max.glob_pos,
        element.slider.min.value, element.slider.max.value,
        glob_pos)

    return limit_range(
        element.slider.min.value, element.slider.max.value,
        val)
end

-- get value at current mouse position
function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

function countone(val)
    if not (user_opts.iamaprogrammer) then
        val = val + 1
    end
    return val
end

-- align:  -1 .. +1
-- frame:  size of the containing area
-- obj:    size of the object that should be positioned inside the area
-- margin: min. distance from object to frame (as long as -1 <= align <= +1)
function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

-- multiplies two alpha values, formular can probably be improved
function mult_alpha(alphaA, alphaB)
    return 255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255)
end

function add_area(name, x1, y1, x2, y2)
    -- create area if needed
    if (osc_param.areas[name] == nil) then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1=x1, y1=y1, x2=x2, y2=y2})
end

function ass_append_alpha(ass, alpha, modifier)
    local ar = {}

    for ai, av in pairs(alpha) do
        av = mult_alpha(av, modifier)
        if state.animation then
            av = mult_alpha(av, state.animation)
        end
        ar[ai] = av
    end

    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
               ar[1], ar[2], ar[3], ar[4]))
end

function ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

function ass_draw_rr_h_ccw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_ccw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_ccw(x0, y0, x1, y1, r1, r2)
    end
end


--
-- Picture In Picture
--

function togglePictureInPicture()
    local isPiP = tethys.isPictureInPicture
    if isPiP then -- Disable
        mp.commandv('set', 'on-all-workspaces', 'no')
        if not tethys.pipWasOnTop then
            mp.commandv('set', 'ontop', 'no')
        end
        if tethys.pipHadBorders then
            mp.commandv('set', 'border', 'yes')
        end
        local videoDecParams = mp.get_property_native("video-dec-params")
        local videoWidth = videoDecParams.dw
        local videoHeight = videoDecParams.dh
        mp.commandv('set', 'geometry', ''..videoWidth..'x'..videoHeight)
        if tethys.pipWasMaximized then
            mp.commandv('set', 'window-maximized', 'yes')
        end
        if tethys.pipWasFullscreen then
            mp.commandv('set', 'fullscreen', 'yes')
        end
    else -- Enable
        tethys.pipWasFullscreen = state.fullscreen
        tethys.pipWasMaximized = state.maximized
        tethys.pipWasOnTop = mp.get_property('ontop') == "yes"
        tethys.pipHadBorders = state.border
        mp.commandv('set', 'fullscreen', 'no')
        mp.commandv('set', 'window-maximized', 'no')
        mp.commandv('set', 'border', 'no')
        mp.commandv('set', 'geometry', tethys.pipGeometry)
        mp.commandv('set', 'ontop', 'yes')
        if tethys.pipAllWorkspaces then
            mp.commandv('set', 'on-all-workspaces', 'yes')
        end
    end
    tethys.isPictureInPicture = not isPiP
    utils.shared_script_property_set("pictureinpicture", tostring(tethys.isPictureInPicture))
end


--
-- Tracklist Management
--

local nicetypes = {video = "Video", audio = "Audio", sub = "Subtitle"}

-- updates the OSC internal playlists, should be run each time the track-layout changes
function update_tracklist()
    local tracktable = mp.get_property_native("track-list", {})

    -- by osc_id
    tracks_osc = {}
    tracks_osc.video, tracks_osc.audio, tracks_osc.sub = {}, {}, {}
    -- by mpv_id
    tracks_mpv = {}
    tracks_mpv.video, tracks_mpv.audio, tracks_mpv.sub = {}, {}, {}
    for n = 1, #tracktable do
        if not (tracktable[n].type == "unknown") then
            local type = tracktable[n].type
            local mpv_id = tonumber(tracktable[n].id)

            -- by osc_id
            table.insert(tracks_osc[type], tracktable[n])

            -- by mpv_id
            tracks_mpv[type][mpv_id] = tracktable[n]
            tracks_mpv[type][mpv_id].osc_id = #tracks_osc[type]
        end
    end
end

-- return a nice list of tracks of the given type (video, audio, sub)
function get_tracklist(type)
    local msg = "Available " .. nicetypes[type] .. " Tracks: "
    if #tracks_osc[type] == 0 then
        msg = msg .. "none"
    else
        for n = 1, #tracks_osc[type] do
            local track = tracks_osc[type][n]
            local lang, title, selected = "unknown", "", "○"
            if not(track.lang == nil) then lang = track.lang end
            if not(track.title == nil) then title = track.title end
            if (track.id == tonumber(mp.get_property(type))) then
                selected = "●"
            end
            msg = msg.."\n"..selected.." "..n..": ["..lang.."] "..title
        end
    end
    return msg
end

-- relatively change the track of given <type> by <next> tracks
    --(+1 -> next, -1 -> previous)
function set_track(type, next)
    local current_track_mpv, current_track_osc
    if (mp.get_property(type) == "no") then
        current_track_osc = 0
    else
        current_track_mpv = tonumber(mp.get_property(type))
        current_track_osc = tracks_mpv[type][current_track_mpv].osc_id
    end
    local new_track_osc = (current_track_osc + next) % (#tracks_osc[type] + 1)
    local new_track_mpv
    if new_track_osc == 0 then
        new_track_mpv = "no"
    else
        new_track_mpv = tracks_osc[type][new_track_osc].id
    end

    mp.commandv("set", type, new_track_mpv)

        if (new_track_osc == 0) then
        show_message(nicetypes[type] .. " Track: none")
    else
        show_message(nicetypes[type]  .. " Track: "
            .. new_track_osc .. "/" .. #tracks_osc[type]
            .. " [".. (tracks_osc[type][new_track_osc].lang or "unknown") .."] "
            .. (tracks_osc[type][new_track_osc].title or ""))
    end
end

-- get the currently selected track of <type>, OSC-style counted
function get_track(type)
    local track = mp.get_property(type)
    if track ~= "no" and track ~= nil then
        local tr = tracks_mpv[type][tonumber(track)]
        if tr then
            return tr.osc_id
        end
    end
    return 0
end

-- WindowControl helpers
function window_controls_enabled()
    val = user_opts.windowcontrols
    if val == "auto" then
        return not state.border
    else
        return val ~= "no"
    end
end

function window_controls_alignment()
    return user_opts.windowcontrols_alignment
end

--
-- Element Management
--

local elements = {}
local playlistElements = {}

function new_ass_node(elem_ass)
    elem_ass:append("{}") -- hack to troll new_event into inserting a \n
    elem_ass:new_event()
end
function reset_ass(elem_ass, element)
    new_ass_node(elem_ass)
    local elem_geo = element.layout.geometry
    elem_ass:pos(elem_geo.x, elem_geo.y)
    elem_ass:an(elem_geo.an)
    elem_ass:append(element.layout.style)
end

function prepare_elements()

    -- remove elements without layout or invisble
    local elements2 = {}
    for n, element in pairs(elements) do
        if not (element.layout == nil) and (element.visible) then
            table.insert(elements2, element)
        end
    end
    elements = elements2

    function elem_compare (a, b)
        return a.layout.layer < b.layout.layer
    end

    table.sort(elements, elem_compare)


    for _,element in pairs(elements) do

        local elem_geo = element.layout.geometry

        -- Calculate the hitbox
        local bX1, bY1, bX2, bY2 = get_hitbox_coords_geo(elem_geo)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        local style_ass = assdraw.ass_new()

        -- prepare static elements
        reset_ass(style_ass, element)
        -- style_ass:append("{}") -- hack to troll new_event into inserting a \n
        -- style_ass:new_event()
        -- style_ass:pos(elem_geo.x, elem_geo.y)
        -- style_ass:an(elem_geo.an)
        -- style_ass:append(element.layout.style)

        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()


        if (element.type == "box") then
            --draw box
            static_ass:draw_start()
            ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h,
                             element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()

        elseif (element.type == "slider") then
            --draw static slider parts

            local r1 = 0
            local r2 = 0
            local slider_lo = element.layout.slider
            -- offset between element outline and drag-area
            local foV = slider_lo.border + slider_lo.gap

            -- calculate positions of min and max points
            if (slider_lo.stype ~= "bar") then
                r1 = elem_geo.h / 2
                element.slider.min.ele_pos = elem_geo.h / 2
                element.slider.max.ele_pos = elem_geo.w - (elem_geo.h / 2)
                if (slider_lo.stype == "diamond") then
                    r2 = (elem_geo.h - 2 * slider_lo.border) / 2
                elseif (slider_lo.stype == "knob") then
                    r2 = r1
                end
            else
                element.slider.min.ele_pos =
                    slider_lo.border + slider_lo.gap
                element.slider.max.ele_pos =
                    elem_geo.w - (slider_lo.border + slider_lo.gap)
            end

            element.slider.min.glob_pos =
                element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos =
                element.hitbox.x1 + element.slider.max.ele_pos

            -- -- --

            ---- This is drawn over
            -- the box
            -- static_ass:draw_start()
            -- ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h, r1, slider_lo.stype == "diamond")
            -- the "hole"
            -- ass_draw_rr_h_ccw(static_ass, slider_lo.border, slider_lo.border,
            --                   elem_geo.w - slider_lo.border, elem_geo.h - slider_lo.border,
            --                   r2, slider_lo.stype == "diamond")
            -- static_ass:draw_stop()



            -- Chapter Markers / Ticks / Nibbles
            -- We store this ass as a property so we can draw them overtop the seekbar
            local nibbles_ass = assdraw.ass_new()
            nibbles_ass:append(tethysStyle.chapterTick)
            nibbles_ass:draw_start()
            if not (element.slider.markerF == nil) and (slider_lo.gap > 0) then
                local markers = element.slider.markerF()
                for _,marker in pairs(markers) do
                    if (marker > element.slider.min.value) and
                        (marker < element.slider.max.value) then

                        local s = get_slider_ele_pos_for(element, marker)
                        local a = tethys.chapterTickSize * 0.8
                        local sliderMid = elem_geo.h / 2
                        local tickY = sliderMid - tethys.chapterTickSize
                        nibbles_ass:move_to(s - (a/2), tickY)
                        nibbles_ass:line_to(s + (a/2), tickY)
                        nibbles_ass:line_to(s, sliderMid)
                    end
                end
            end
            nibbles_ass:draw_stop()
            slider_lo.nibbles_ass = nibbles_ass
        end

        element.static_ass = static_ass


        -- if the element is supposed to be disabled,
        -- style it accordingly and kill the eventresponders
        if not (element.enabled) then
            element.layout.alpha[1] = 136
            element.eventresponder = nil
        end
    end
end


--
-- Element Rendering
--

-- returns nil or a chapter element from the native property chapter-list
function get_chapter(possec)
    local cl = state.chapter_list  -- sorted, get latest before possec, if any

    for n=#cl,1,-1 do
        if possec >= cl[n].time then
            return cl[n]
        end
    end
end

function render_elements(master_ass)

    -- when the slider is dragged or hovered and we have a target chapter name
    -- then we use it instead of the normal title. we calculate it before the
    -- render iterations because the title may be rendered before the slider.
    state.forced_title = nil
    local se, ae = state.slider_element, elements[state.active_element]
    if user_opts.chapter_fmt ~= "no" and se and (ae == se or (not ae and mouse_hit(se))) then
        local dur = mp.get_property_number("duration", 0)
        if dur > 0 then
            local possec = get_slider_value(se) * dur / 100 -- of mouse pos
            local ch = get_chapter(possec)
            if ch and ch.title and ch.title ~= "" then
                state.forced_title = string.format(user_opts.chapter_fmt, ch.title)
            end
        end
    end

    --
    tethys.hideSeekbar = false

    for n=1, #elements do
        local element = elements[n]

        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_append_alpha(style_ass, element.layout.alpha, 0)

        if element.eventresponder and (state.active_element == n) then

            -- run render event functions
            if not (element.eventresponder.render == nil) then
                element.eventresponder.render(element)
            end

            if mouse_hit(element) then
                -- mouse down styling
                if (element.styledown) then
                    style_ass:append(osc_styles.elementDown)
                end

                if (element.softrepeat) and (state.mouse_down_counter >= 15
                    and state.mouse_down_counter % 5 == 0) then

                    element.eventresponder[state.active_event_source.."_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end

        end

        local elem_ass = assdraw.ass_new()

        elem_ass:merge(style_ass)

        if not (element.type == "button") then
            elem_ass:merge(element.static_ass)
        end

        if (element.type == "slider") and not tethys.hideSeekbar then

            local slider_lo = element.layout.slider
            local elem_geo = element.layout.geometry
            local s_min = element.slider.min.value
            local s_max = element.slider.max.value

            -- draw pos marker
            local foH, xp
            local pos = element.slider.posF()
            local foV = slider_lo.border + slider_lo.gap
            local innerH = elem_geo.h - (2 * foV)
            local seekRanges = element.slider.seekRangesF()
            local seekRangeLineHeight = innerH / 5

            if slider_lo.stype ~= "bar" then
                foH = elem_geo.h / 2
            else
                foH = slider_lo.border + slider_lo.gap
            end

            -- Reset everything as static_ass ended with draw_stop()
            reset_ass(elem_ass, element)

            if pos then
                xp = get_slider_ele_pos_for(element, pos)

                -- Thick Slider BG Before Handle
                local sliderFgRatio = 6 -- 1/6th Height
                elem_ass:append(tethysStyle.seekbarFg)
                elem_ass:draw_start()
                -- Note: round_rect_cw(x0, y0, x1, y1, r1, r2)
                elem_ass:round_rect_cw(
                    foH - innerH / sliderFgRatio,
                    foH - innerH / sliderFgRatio,
                    xp,
                    foH + innerH / sliderFgRatio,
                    innerH / sliderFgRatio,
                    0
                )
                elem_ass:draw_stop()
                reset_ass(elem_ass, element)

                -- Thin Slider BG After Handle
                -- local sliderBgRatio = 15 -- 1/15th Height
                local sliderBgRatio = 6
                elem_ass:append(tethysStyle.seekbarBg)
                elem_ass:draw_start()
                -- Note: round_rect_cw(x0, y0, x1, y1, r1, r2)
                elem_ass:round_rect_cw(
                    xp,
                    foH - innerH / sliderBgRatio,
                    elem_geo.w - foH + innerH / sliderBgRatio,
                    foH + innerH / sliderBgRatio,
                    0,
                    innerH / sliderBgRatio
                )
                elem_ass:draw_stop()
                reset_ass(elem_ass, element)

                -- Cache / Seek Ranges
                elem_ass:append(tethysStyle.seekbarCache)
                ass_append_alpha(elem_ass, tethys.seekbarCacheAlphaTable, 0)
                elem_ass:draw_start()
                -- local cacheBgRatio = 21 -- 1/21th Height
                local seekbarY1 = foH - innerH / sliderFgRatio
                local seekbarY2 = foH + innerH / sliderFgRatio
                local cachebarY1 = seekbarY1 + 1
                local cachebarY2 = seekbarY2 - 1
                for _,range in pairs(seekRanges or {}) do
                    local pstart = get_slider_ele_pos_for(element, range["start"])
                    local pend = get_slider_ele_pos_for(element, range["end"])
                    -- Note: round_rect_ccw(x0, y0, x1, y1, r1, r2)
                    -- elem_ass:round_rect_ccw(
                    --     pstart,
                    --     foH - innerH / cacheBgRatio,
                    --     pend,
                    --     foH + innerH / cacheBgRatio,
                    --     innerH / cacheBgRatio,
                    --     nil
                    -- )
                    elem_ass:round_rect_ccw(
                        pstart,
                        cachebarY1,
                        pend,
                        cachebarY2,
                        0,
                        nil
                    )
                end
                elem_ass:draw_stop()
                reset_ass(elem_ass, element)

                -- Chapter Ticks
                elem_ass:merge(slider_lo.nibbles_ass)
                reset_ass(elem_ass, element)

                -- Circle Knob/Handle
                elem_ass:append(tethysStyle.seekbarHandle)
                elem_ass:draw_start()
                local r = (user_opts.seekbarhandlesize * innerH) / 2
                -- Note: round_rect_cw(x0, y0, x1, y1, r1, r2)
                elem_ass:round_rect_cw(
                    xp - r,
                    foH - r,
                    xp + r,
                    foH + r,
                    r,
                    nil
                )
                elem_ass:draw_stop()
                reset_ass(elem_ass, element)
            end

            -- add tooltip
            if not (element.slider.tooltipF == nil) then

                if mouse_hit(element) then
                    local sliderPos = get_slider_value(element)
                    local tooltipLabel = element.slider.tooltipF(sliderPos)

                    local an = slider_lo.tooltip_an

                    local ty

                    if (an == 2) then
                        ty = element.hitbox.y1 - slider_lo.border
                    else
                        ty = element.hitbox.y1 + elem_geo.h/2
                    end

                    local tx = get_virt_mouse_pos()
                    if (slider_lo.adjust_tooltip) then
                        if (an == 2) then
                            if (sliderPos < (s_min + 3)) then
                                an = an - 1
                            elseif (sliderPos > (s_max - 3)) then
                                an = an + 1
                            end
                        elseif (sliderPos > (s_max-s_min)/2) then
                            an = an + 1
                            tx = tx - 5
                        else
                            an = an - 1
                            tx = tx + 10
                        end
                    end

                    -- Tooltip + Thumbnail
                    -- https://github.com/TheAMM/mpv_thumbnail_script
                    local thumbPos = {
                        x=get_virt_mouse_pos(),
                        y=ty,
                        an=2, -- x,y is bottom-center
                    }
                    renderThumbnailTooltip(thumbPos, sliderPos, elem_ass)

                end
            end

        elseif (element.type == "button") then
            local button_lo = element.layout.button

            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content() -- function objects
            elseif not (element.content == nil) then
                buttontext = element.content -- text objects
            end

            local maxchars = element.layout.button.maxchars
            if not (maxchars == nil) and (#buttontext > maxchars) then
                local max_ratio = 1.25  -- up to 25% more chars while shrinking
                local limit = math.max(0, math.floor(maxchars * max_ratio) - 3)
                if (#buttontext > limit) then
                    while (#buttontext > limit) do
                        buttontext = buttontext:gsub(".[\128-\191]*$", "")
                    end
                    buttontext = buttontext .. "..."
                end
                local _, nchars2 = buttontext:gsub(".[\128-\191]*", "")
                local stretch = (maxchars/#buttontext)*100
                buttontext = string.format("{\\fscx%f}",
                    (maxchars/#buttontext)*100) .. buttontext
            end

            local isButton = element.eventresponder and (
                not (element.eventresponder["mbtn_left_down"] == nil)
                or not (element.eventresponder["mbtn_left_up"] == nil)
            )
            local buttonHovered = mouse_hit(element)
            if button_lo.hideSeekbar and buttonHovered then
                tethys.hideSeekbar = true
            end
            if isButton and buttonHovered and element.enabled then
                buttontext = button_lo.hover_style .. buttontext

                -- Hover BG Rect
                if tethys.showButtonHoveredRect then
                    local elem_geo = element.layout.geometry
                    local bgrect_ass = assdraw.ass_new()
                    bgrect_ass:merge(style_ass)
                    bgrect_ass:append(tethysStyle.buttonHoveredRect)
                    bgrect_ass:draw_start()
                    bgrect_ass:round_rect_cw(
                        0, 0, elem_geo.w, elem_geo.h,
                        0, 0
                    )
                    bgrect_ass:draw_stop()
                    master_ass:merge(bgrect_ass)
                end

                -- Hover Glow/Shadow
                local shadow_ass = assdraw.ass_new()
                shadow_ass:merge(style_ass)
                shadow_ass:append("{\\blur5}" .. buttontext .. "{\\blur0}")
                master_ass:merge(shadow_ass)
            end

            elem_ass:append(buttontext)

            -- Tooltip
            if buttonHovered and (not (button_lo.tooltip == nil)) then
                local tx = button_lo.tooltip_geo.x
                local ty = button_lo.tooltip_geo.y
                local labelList = {}
                if type(button_lo.tooltip) == "function" then
                    labelList = button_lo.tooltip()
                else
                    labelList = button_lo.tooltip
                end
                if type(labelList) == "string" then
                    labelList = { labelList }
                end
                if not (type(labelList) == "table") then
                    labelList = {}
                end
                local rowY = ty
                for i, label in ipairs(labelList) do
                    rowY = ty - ((i-1) * tethys.buttonTooltipSize)
                    new_ass_node(elem_ass)
                    elem_ass:pos(tx, rowY)
                    elem_ass:an(button_lo.tooltip_an)
                    elem_ass:append(button_lo.tooltip_style)
                    ass_append_alpha(elem_ass, tethys.tooltipAlphaTable, 0)
                    elem_ass.scale = 1
                    elem_ass:append(label)
                    elem_ass.scale = 4
                end
                rowY = rowY - tethys.buttonTooltipSize

                if not (button_lo.playlist == nil) then
                    local thumbPos = {
                        x = tx,
                        y = rowY,
                        an = button_lo.tooltip_an,
                    }
                    renderPlaylistTooltip(thumbPos, button_lo.playlist, elem_ass)
                end
            end
        end

        master_ass:merge(elem_ass)
    end
end

--
-- Message display
--

-- pos is 1 based
function limited_list(prop, pos)
    local proplist = mp.get_property_native(prop, {})
    local count = #proplist
    if count == 0 then
        return count, proplist
    end

    local fs = tonumber(mp.get_property('options/osd-font-size'))
    local max = math.ceil(osc_param.unscaled_y*0.75 / fs)
    if max % 2 == 0 then
        max = max - 1
    end
    local delta = math.ceil(max / 2) - 1
    local begi = math.max(math.min(pos - delta, count - max + 1), 1)
    local endi = math.min(begi + max - 1, count)

    local reslist = {}
    for i=begi, endi do
        local item = proplist[i]
        item.index = i
        item.current = (i == pos) and true or nil
        table.insert(reslist, item)
    end
    return count, reslist
end

function get_playlist()
    local pos = mp.get_property_number('playlist-pos', 0) + 1
    local count, limlist = limited_list('playlist', pos)
    if count == 0 then
        return 'Empty playlist.'
    end

    local message = string.format('Playlist [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local title = v.title
        local _, filename = utils.split_path(v.filename)
        if title == nil then
            title = filename
        end
        message = string.format('%s %s %s\n', message,
            (v.current and '●' or '○'), title)
    end
    return message
end

function get_chapterlist()
    local pos = mp.get_property_number('chapter', 0) + 1
    local count, limlist = limited_list('chapter-list', pos)
    if count == 0 then
        return 'No chapters.'
    end

    local message = string.format('Chapters [%d/%d]:\n', pos, count)
    for i, v in ipairs(limlist) do
        local time = mp.format_time(v.time)
        local title = v.title
        if title == nil then
            title = string.format('Chapter %02d', i)
        end
        message = string.format('%s[%s] %s %s\n', message, time,
            (v.current and '●' or '○'), title)
    end
    return message
end

function show_message(text, duration)

    -- print("text: "..text.."   duration: " .. duration)
    if duration == nil then
        duration = tonumber(mp.get_property("options/osd-duration")) / 1000
    elseif not type(duration) == "number" then
        print("duration: " .. duration)
    end

    -- cut the text short, otherwise the following functions
    -- may slow down massively on huge input
    text = string.sub(text, 0, 4000)

    -- replace actual linebreaks with ASS linebreaks
    text = string.gsub(text, "\n", "\\N")

    state.message_text = text

    if not state.message_hide_timer then
        state.message_hide_timer = mp.add_timeout(0, request_tick)
    end
    state.message_hide_timer:kill()
    state.message_hide_timer.timeout = duration
    state.message_hide_timer:resume()
    request_tick()
end

function render_message(ass)
    if state.message_hide_timer and state.message_hide_timer:is_enabled() and
       state.message_text
    then
        local _, lines = string.gsub(state.message_text, "\\N", "")

        local fontsize = tonumber(mp.get_property("options/osd-font-size"))
        local outline = tonumber(mp.get_property("options/osd-border-size"))
        local maxlines = math.ceil(osc_param.unscaled_y*0.75 / fontsize)
        local counterscale = osc_param.playresy / osc_param.unscaled_y

        fontsize = fontsize * counterscale / math.max(0.65 + math.min(lines/maxlines, 1), 1)
        outline = outline * counterscale / math.max(0.75 + math.min(lines/maxlines, 1)/2, 1)

        local style = "{\\bord" .. outline .. "\\fs" .. fontsize .. "}"


        ass:new_event()
        ass:append(style .. state.message_text)
    else
        state.message_text = nil
    end
end

--
-- Initialisation and Layout
--

function new_element(name, type)
    elements[name] = {}
    elements[name].name = name
    elements[name].type = type

    -- add default stuff
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}

    if (type == "slider") then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
    end


    return elements[name]
end

function add_layout(name)
    if not (elements[name] == nil) then
        -- new layout
        elements[name].layout = {}

        -- set layout defaults
        elements[name].layout.layer = 50
        elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}

        if (elements[name].type == "button") then
            elements[name].layout.button = {
                maxchars = nil,
                hover_style = tethysStyle.buttonHovered,
                playlist = nil,
                hideSeekbar = false,
            }
        elseif (elements[name].type == "slider") then
            -- slider defaults
            elements[name].layout.slider = {
                border = 1,
                gap = 1,
                nibbles_top = true,
                nibbles_bottom = true,
                stype = "slider",
                adjust_tooltip = true,
                tooltip_style = "",
                tooltip_an = 2,
                alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
            }
        elseif (elements[name].type == "box") then
            elements[name].layout.box = {radius = 0, hexagon = false}
        end

        return elements[name].layout
    else
        msg.error("Can't add_layout to element \""..name.."\", doesn't exist.")
    end
end

-- Window Controls
function window_controls(topbar)
    local windowBarHeight = 30
    local windowButtonSize = tethys.windowButtonSize
    local windowBarSpacing = 5
    local wc_geo = {
        x = 0,
        y = tethys.windowBarHeight + user_opts.barmargin,
        an = 1, -- x,y is bottom left
        w = osc_param.playresx,
        h = tethys.windowBarHeight,
    }

    local alignment = window_controls_alignment()
    local controlbox_w = windowBarSpacing + tethys.windowControlsRect.w
    local titlebox_w = wc_geo.w - controlbox_w

    -- Default alignment is "right"
    local controlbox_left = wc_geo.w - controlbox_w
    local titlebox_left = wc_geo.x
    local titlebox_right = wc_geo.w - controlbox_w

    if alignment == "left" then
        controlbox_left = wc_geo.x
        titlebox_left = wc_geo.x + controlbox_w
        titlebox_right = wc_geo.w
    end

    add_area("window-controls",
             get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an,
                               controlbox_w, wc_geo.h))

    local lo

    -- Background Bar
    new_element("wcbar", "box")
    lo = add_layout("wcbar")
    lo.geometry = wc_geo
    lo.layer = 10
    lo.style = tethysStyle.windowBar
    lo.alpha = tethys.windowBarAlphaTable

    local winControlsX = controlbox_left + windowBarSpacing + tethys.windowButtonSize/2
    local winControlsY = wc_geo.y - (wc_geo.h / 2)
    local winControlsAlignment = 5 -- x,y is center
    local first_geo = {
        x = winControlsX + tethys.windowButtonSize*0,
        y = winControlsY,
        an = winControlsAlignment,
        w = tethys.windowButtonSize,
        h = tethys.windowButtonSize,
    }
    local second_geo = {
        x = winControlsX + tethys.windowButtonSize*1,
        y = winControlsY,
        an = winControlsAlignment,
        w = tethys.windowButtonSize,
        h = tethys.windowButtonSize,
    }
    local third_geo = {
        x = winControlsX + tethys.windowButtonSize*2,
        y = winControlsY,
        an = winControlsAlignment,
        w = tethys.windowButtonSize,
        h = tethys.windowButtonSize,
    }

    -- Window control buttons use symbols in the custom mpv osd font
    -- because the official unicode codepoints are sufficiently
    -- exotic that a system might lack an installed font with them,
    -- and libass will complain that they are not present in the
    -- default font, even if another font with them is available.

    -- Close: 🗙
    ne = new_element("close", "button")
    ne.content = mpvOsdIcon_close
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("quit") end
    lo = add_layout("close")
    lo.geometry = alignment == "left" and first_geo or third_geo
    lo.style = tethysStyle.windowButton
    lo.button.hover_style = tethysStyle.closeButtonHovered
    lo.alpha[3] = 0 -- show outline (aka border)

    -- Minimize: 🗕
    ne = new_element("minimize", "button")
    ne.content = mpvOsdIcon_minimize
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "window-minimized") end
    lo = add_layout("minimize")
    lo.geometry = alignment == "left" and second_geo or first_geo
    lo.style = tethysStyle.windowButton
    lo.alpha[3] = 0 -- show outline (aka border)

    -- Maximize: 🗖 /🗗
    ne = new_element("maximize", "button")
    if state.maximized or state.fullscreen then
        ne.content = mpvOsdIcon_restore
    else
        ne.content = mpvOsdIcon_maximize
    end
    ne.eventresponder["mbtn_left_up"] =
        function ()
            if state.fullscreen then
                mp.commandv("cycle", "fullscreen")
            else
                mp.commandv("cycle", "window-maximized")
            end
        end
    lo = add_layout("maximize")
    lo.geometry = alignment == "left" and third_geo or second_geo
    lo.style = tethysStyle.windowButton
    lo.alpha[3] = 0 -- show outline (aka border)

    -- deadzone below window controls
    local sh_area_y0, sh_area_y1
    sh_area_y0 = user_opts.barmargin
    sh_area_y1 = (wc_geo.y + (wc_geo.h / 2)) +
                 get_align(1 - (2 * user_opts.deadzonesize),
                 osc_param.playresy - (wc_geo.y + (wc_geo.h / 2)), 0, 0)
    add_area("showhide_wc", wc_geo.x, sh_area_y0, wc_geo.w, sh_area_y1)

    if topbar then
        -- The title is already there as part of the top bar
        return
    else
        -- Apply boxvideo margins to the control bar
        osc_param.video_margins.t = wc_geo.h / osc_param.playresy
    end

    -- Window Title
    ne = new_element("wctitle", "button")
    ne.content = function ()
        local title = mp.command_native({"expand-text", user_opts.title})
        -- escape ASS, and strip newlines and trailing slashes
        title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
        return not (title == "") and title or "mpv"
    end
    local vertPad = (wc_geo.h - tethys.windowTitleSize)/2
    local leftPad = vertPad
    local rightPad = vertPad * 2
    lo = add_layout("wctitle")
    lo.geometry = {
        x = titlebox_left + leftPad,
        y = wc_geo.y - wc_geo.h/2,
        an = 4, -- x,y is left-center
        w = titlebox_w,
        h = wc_geo.h,
    }
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}",
        tethysStyle.windowTitle,
        lo.geometry.x - tethys.windowTitleOutline,
        wc_geo.y - wc_geo.h - tethys.windowTitleOutline,
        titlebox_right - rightPad + tethys.windowTitleOutline,
        wc_geo.y + tethys.windowTitleOutline
    )
    lo.alpha[3] = 0 -- show text outline (aka border)

    add_area("window-controls-title",
             titlebox_left, 0, titlebox_right, wc_geo.h)
end

--
-- Layouts
--

local layouts = {}

-- Classic box layout
layouts["box"] = function ()

    local osc_geo = {
        w = 550,    -- width
        h = 138,    -- height
        r = 10,     -- corner-radius
        p = 15,     -- padding
    }

    -- make sure the OSC actually fits into the video
    if (osc_param.playresx < (osc_geo.w + (2 * osc_geo.p))) then
        osc_param.playresy = (osc_geo.w+(2*osc_geo.p))/osc_param.display_aspect
        osc_param.playresx = osc_param.playresy * osc_param.display_aspect
    end

    -- position of the controller according to video aspect and valignment
    local posX = math.floor(get_align(user_opts.halign, osc_param.playresx,
        osc_geo.w, 0))
    local posY = math.floor(get_align(user_opts.valign, osc_param.playresy,
        osc_geo.h, 0))

    -- position offset for contents aligned at the borders of the box
    local pos_offsetX = (osc_geo.w - (2*osc_geo.p)) / 2
    local pos_offsetY = (osc_geo.h - (2*osc_geo.p)) / 2

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 5, osc_geo.w, osc_geo.h))

    -- area for show/hide
    local sh_area_y0, sh_area_y1
    if user_opts.valign > 0 then
        -- deadzone above OSC
        sh_area_y0 = get_align(-1 + (2*user_opts.deadzonesize),
            posY - (osc_geo.h / 2), 0, 0)
        sh_area_y1 = osc_param.playresy
    else
        -- deadzone below OSC
        sh_area_y0 = 0
        sh_area_y1 = (posY + (osc_geo.h / 2)) +
            get_align(1 - (2*user_opts.deadzonesize),
            osc_param.playresy - (posY + (osc_geo.h / 2)), 0, 0)
    end
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, sh_area_y1)

    -- fetch values
    local osc_w, osc_h, osc_r, osc_p =
        osc_geo.w, osc_geo.h, osc_geo.r, osc_geo.p

    local lo

    --
    -- Background box
    --

    new_element("bgbox", "box")
    lo = add_layout("bgbox")

    lo.geometry = {x = posX, y = posY, an = 5, w = osc_w, h = osc_h}
    lo.layer = 10
    lo.style = osc_styles.box
    lo.alpha[1] = user_opts.boxalpha
    lo.alpha[3] = user_opts.boxalpha
    lo.box.radius = osc_r

    --
    -- Title row
    --

    local titlerowY = posY - pos_offsetY - 10

    lo = add_layout("title")
    lo.geometry = {x = posX, y = titlerowY, an = 8, w = 496, h = 12}
    lo.style = osc_styles.vidtitle
    lo.button.maxchars = user_opts.boxmaxchars

    lo = add_layout("pl_prev")
    lo.geometry =
        {x = (posX - pos_offsetX), y = titlerowY, an = 7, w = 12, h = 12}
    lo.style = osc_styles.topButtons

    lo = add_layout("pl_next")
    lo.geometry =
        {x = (posX + pos_offsetX), y = titlerowY, an = 9, w = 12, h = 12}
    lo.style = osc_styles.topButtons

    --
    -- Big buttons
    --

    local bigbtnrowY = posY - pos_offsetY + 35
    local bigbtndist = 60

    lo = add_layout("playpause")
    lo.geometry =
        {x = posX, y = bigbtnrowY, an = 5, w = 40, h = 40}
    lo.style = osc_styles.bigButtons

    lo = add_layout("skipback")
    lo.geometry =
        {x = posX - bigbtndist, y = bigbtnrowY, an = 5, w = 40, h = 40}
    lo.style = osc_styles.bigButtons

    lo = add_layout("skipfrwd")
    lo.geometry =
        {x = posX + bigbtndist, y = bigbtnrowY, an = 5, w = 40, h = 40}
    lo.style = osc_styles.bigButtons

    lo = add_layout("ch_prev")
    lo.geometry =
        {x = posX - (bigbtndist * 2), y = bigbtnrowY, an = 5, w = 40, h = 40}
    lo.style = osc_styles.bigButtons

    lo = add_layout("ch_next")
    lo.geometry =
        {x = posX + (bigbtndist * 2), y = bigbtnrowY, an = 5, w = 40, h = 40}
    lo.style = osc_styles.bigButtons

    lo = add_layout("cy_audio")
    lo.geometry =
        {x = posX - pos_offsetX, y = bigbtnrowY, an = 1, w = 70, h = 18}
    lo.style = osc_styles.smallButtonsL

    lo = add_layout("cy_sub")
    lo.geometry =
        {x = posX - pos_offsetX, y = bigbtnrowY, an = 7, w = 70, h = 18}
    lo.style = osc_styles.smallButtonsL

    lo = add_layout("tog_fs")
    lo.geometry =
        {x = posX+pos_offsetX - 25, y = bigbtnrowY, an = 4, w = 25, h = 25}
    lo.style = osc_styles.smallButtonsR

    lo = add_layout("volume")
    lo.geometry =
        {x = posX+pos_offsetX - (25 * 2) - osc_geo.p,
         y = bigbtnrowY, an = 4, w = 25, h = 25}
    lo.style = osc_styles.smallButtonsR

    --
    -- Seekbar
    --

    lo = add_layout("seekbar")
    lo.geometry =
        {x = posX, y = posY+pos_offsetY-22, an = 2, w = pos_offsetX*2, h = 15}
    lo.style = osc_styles.timecodes
    lo.slider.tooltip_style = osc_styles.vidtitle
    lo.slider.stype = user_opts["seekbarstyle"]
    lo.slider.rtype = user_opts["seekrangestyle"]

    --
    -- Timecodes + Cache
    --

    local bottomrowY = posY + pos_offsetY - 5

    lo = add_layout("tc_left")
    lo.geometry =
        {x = posX - pos_offsetX, y = bottomrowY, an = 4, w = 110, h = 18}
    lo.style = osc_styles.timecodes

    lo = add_layout("tc_right")
    lo.geometry =
        {x = posX + pos_offsetX, y = bottomrowY, an = 6, w = 110, h = 18}
    lo.style = osc_styles.timecodes

    lo = add_layout("cache")
    lo.geometry =
        {x = posX, y = bottomrowY, an = 5, w = 110, h = 18}
    lo.style = osc_styles.timecodes

end

-- slim box layout
layouts["slimbox"] = function ()

    local osc_geo = {
        w = 660,    -- width
        h = 70,     -- height
        r = 10,     -- corner-radius
    }

    -- make sure the OSC actually fits into the video
    if (osc_param.playresx < (osc_geo.w)) then
        osc_param.playresy = (osc_geo.w)/osc_param.display_aspect
        osc_param.playresx = osc_param.playresy * osc_param.display_aspect
    end

    -- position of the controller according to video aspect and valignment
    local posX = math.floor(get_align(user_opts.halign, osc_param.playresx,
        osc_geo.w, 0))
    local posY = math.floor(get_align(user_opts.valign, osc_param.playresy,
        osc_geo.h, 0))

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 5, osc_geo.w, osc_geo.h))

    -- area for show/hide
    local sh_area_y0, sh_area_y1
    if user_opts.valign > 0 then
        -- deadzone above OSC
        sh_area_y0 = get_align(-1 + (2*user_opts.deadzonesize),
            posY - (osc_geo.h / 2), 0, 0)
        sh_area_y1 = osc_param.playresy
    else
        -- deadzone below OSC
        sh_area_y0 = 0
        sh_area_y1 = (posY + (osc_geo.h / 2)) +
            get_align(1 - (2*user_opts.deadzonesize),
            osc_param.playresy - (posY + (osc_geo.h / 2)), 0, 0)
    end
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, sh_area_y1)

    local lo

    local tc_w, ele_h, inner_w = 100, 20, osc_geo.w - 100

    -- styles
    local styles = {
        box = "{\\rDefault\\blur0\\bord1\\1c&H000000\\3c&HFFFFFF}",
        timecodes = "{\\1c&HFFFFFF\\3c&H000000\\fs20\\bord2\\blur1}",
        tooltip = "{\\1c&HFFFFFF\\3c&H000000\\fs12\\bord1\\blur0.5}",
    }


    new_element("bgbox", "box")
    lo = add_layout("bgbox")

    lo.geometry = {x = posX, y = posY - 1, an = 2, w = inner_w, h = ele_h}
    lo.layer = 10
    lo.style = osc_styles.box
    lo.alpha[1] = user_opts.boxalpha
    lo.alpha[3] = 0
    if not (user_opts["seekbarstyle"] == "bar") then
        lo.box.radius = osc_geo.r
        lo.box.hexagon = user_opts["seekbarstyle"] == "diamond"
    end


    lo = add_layout("seekbar")
    lo.geometry =
        {x = posX, y = posY - 1, an = 2, w = inner_w, h = ele_h}
    lo.style = osc_styles.timecodes
    lo.slider.border = 0
    lo.slider.gap = 1.5
    lo.slider.tooltip_style = styles.tooltip
    lo.slider.stype = user_opts["seekbarstyle"]
    lo.slider.rtype = user_opts["seekrangestyle"]
    lo.slider.adjust_tooltip = false

    --
    -- Timecodes
    --

    lo = add_layout("tc_left")
    lo.geometry =
        {x = posX - (inner_w/2) + osc_geo.r, y = posY + 1,
        an = 7, w = tc_w, h = ele_h}
    lo.style = styles.timecodes
    lo.alpha[3] = user_opts.boxalpha

    lo = add_layout("tc_right")
    lo.geometry =
        {x = posX + (inner_w/2) - osc_geo.r, y = posY + 1,
        an = 9, w = tc_w, h = ele_h}
    lo.style = styles.timecodes
    lo.alpha[3] = user_opts.boxalpha

    -- Cache

    lo = add_layout("cache")
    lo.geometry =
        {x = posX, y = posY + 1,
        an = 8, w = tc_w, h = ele_h}
    lo.style = styles.timecodes
    lo.alpha[3] = user_opts.boxalpha


end

function bar_layout(direction)
    local osc_geo = {
        x = -2,
        y,
        an = (direction < 0) and 7 or 1,
        w,
        h = 56,
    }

    local padX = 9
    local padY = 3
    local buttonW = 27
    local tcW = (state.tc_ms) and 170 or 110
    local tsW = 90
    local minW = (buttonW + padX)*5 + (tcW + padX)*4 + (tsW + padX)*2

    -- Special topbar handling when window controls are present
    local padwc_l
    local padwc_r
    if direction < 0 or not window_controls_enabled() then
        padwc_l = 0
        padwc_r = 0
    elseif window_controls_alignment() == "left" then
        padwc_l = window_control_box_width
        padwc_r = 0
    else
        padwc_l = 0
        padwc_r = window_control_box_width
    end

    if ((osc_param.display_aspect > 0) and (osc_param.playresx < minW)) then
        osc_param.playresy = minW / osc_param.display_aspect
        osc_param.playresx = osc_param.playresy * osc_param.display_aspect
    end

    osc_geo.y = direction * (54 + user_opts.barmargin)
    osc_geo.w = osc_param.playresx + 4
    if direction < 0 then
        osc_geo.y = osc_geo.y + osc_param.playresy
    end

    local line1 = osc_geo.y - direction * (9 + padY)
    local line2 = osc_geo.y - direction * (36 + padY)

    osc_param.areas = {}

    add_area("input", get_hitbox_coords(osc_geo.x, osc_geo.y, osc_geo.an,
                                        osc_geo.w, osc_geo.h))

    local sh_area_y0, sh_area_y1
    if direction > 0 then
        -- deadzone below OSC
        sh_area_y0 = user_opts.barmargin
        sh_area_y1 = (osc_geo.y + (osc_geo.h / 2)) +
                     get_align(1 - (2*user_opts.deadzonesize),
                     osc_param.playresy - (osc_geo.y + (osc_geo.h / 2)), 0, 0)
    else
        -- deadzone above OSC
        sh_area_y0 = get_align(-1 + (2*user_opts.deadzonesize),
                               osc_geo.y - (osc_geo.h / 2), 0, 0)
        sh_area_y1 = osc_param.playresy - user_opts.barmargin
    end
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, sh_area_y1)

    local lo, geo

    -- Background bar
    new_element("bgbox", "box")
    lo = add_layout("bgbox")

    lo.geometry = osc_geo
    lo.layer = 10
    lo.style = osc_styles.box
    lo.alpha[1] = user_opts.boxalpha


    -- Playlist prev/next
    geo = { x = osc_geo.x + padX, y = line1,
            an = 4, w = 18, h = 18 - padY }
    lo = add_layout("pl_prev")
    lo.geometry = geo
    lo.style = osc_styles.topButtonsBar

    geo = { x = geo.x + geo.w + padX, y = geo.y, an = geo.an, w = geo.w, h = geo.h }
    lo = add_layout("pl_next")
    lo.geometry = geo
    lo.style = osc_styles.topButtonsBar

    local t_l = geo.x + geo.w + padX

    -- Cache
    geo = { x = osc_geo.x + osc_geo.w - padX, y = geo.y,
            an = 6, w = 150, h = geo.h }
    lo = add_layout("cache")
    lo.geometry = geo
    lo.style = osc_styles.vidtitleBar

    local t_r = geo.x - geo.w - padX*2

    -- Title
    geo = { x = t_l, y = geo.y, an = 4,
            w = t_r - t_l, h = geo.h }
    lo = add_layout("title")
    lo.geometry = geo
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}",
        osc_styles.vidtitleBar,
        geo.x, geo.y-geo.h, geo.w, geo.y+geo.h)


    -- Playback control buttons
    geo = { x = osc_geo.x + padX + padwc_l, y = line2, an = 4,
            w = buttonW, h = 36 - padY*2}
    lo = add_layout("playpause")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    geo = { x = geo.x + geo.w + padX, y = geo.y, an = geo.an, w = geo.w, h = geo.h }
    lo = add_layout("ch_prev")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    geo = { x = geo.x + geo.w + padX, y = geo.y, an = geo.an, w = geo.w, h = geo.h }
    lo = add_layout("ch_next")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    -- Left timecode
    geo = { x = geo.x + geo.w + padX + tcW, y = geo.y, an = 6,
            w = tcW, h = geo.h }
    lo = add_layout("tc_left")
    lo.geometry = geo
    lo.style = osc_styles.timecodesBar

    local sb_l = geo.x + padX

    -- Fullscreen button
    geo = { x = osc_geo.x + osc_geo.w - buttonW - padX - padwc_r, y = geo.y, an = 4,
            w = buttonW, h = geo.h }
    lo = add_layout("tog_fs")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    -- Volume
    geo = { x = geo.x - geo.w - padX, y = geo.y, an = geo.an, w = geo.w, h = geo.h }
    lo = add_layout("volume")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    -- Track selection buttons
    geo = { x = geo.x - tsW - padX, y = geo.y, an = geo.an, w = tsW, h = geo.h }
    lo = add_layout("cy_sub")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar

    geo = { x = geo.x - geo.w - padX, y = geo.y, an = geo.an, w = geo.w, h = geo.h }
    lo = add_layout("cy_audio")
    lo.geometry = geo
    lo.style = osc_styles.smallButtonsBar


    -- Right timecode
    geo = { x = geo.x - padX - tcW - 10, y = geo.y, an = geo.an,
            w = tcW, h = geo.h }
    lo = add_layout("tc_right")
    lo.geometry = geo
    lo.style = osc_styles.timecodesBar

    local sb_r = geo.x - padX


    -- Seekbar
    geo = { x = sb_l, y = geo.y, an = geo.an,
            w = math.max(0, sb_r - sb_l), h = geo.h }
    new_element("bgbar1", "box")
    lo = add_layout("bgbar1")

    lo.geometry = geo
    lo.layer = 15
    lo.style = osc_styles.timecodesBar
    lo.alpha[1] =
        math.min(255, user_opts.boxalpha + (255 - user_opts.boxalpha)*0.8)
    if not (user_opts["seekbarstyle"] == "bar") then
        lo.box.radius = geo.h / 2
        lo.box.hexagon = user_opts["seekbarstyle"] == "diamond"
    end

    lo = add_layout("seekbar")
    lo.geometry = geo
    lo.style = osc_styles.timecodesBar
    lo.slider.border = 0
    lo.slider.gap = 2
    lo.slider.tooltip_style = osc_styles.timePosBar
    lo.slider.tooltip_an = 5
    lo.slider.stype = user_opts["seekbarstyle"]
    lo.slider.rtype = user_opts["seekrangestyle"]

    if direction < 0 then
        osc_param.video_margins.b = osc_geo.h / osc_param.playresy
    else
        osc_param.video_margins.t = osc_geo.h / osc_param.playresy
    end
end

layouts["bottombar"] = function()
    bar_layout(-1)
end

layouts["topbar"] = function()
    bar_layout(1)
end

layouts["tethys"] = function()
    local direction = -1
    local osc_geo = {
        x = -2,
        y,
        an = (direction < 0) and 7 or 1,
        w,
        h = tethys.bottomBarHeight,
    }

    -- Alias
    local buttonW = tethys.buttonW
    local buttonH = tethys.buttonH
    local smallButtonSize = tethys.smallButtonSize

    -- Props
    local padX = 9
    local padY = 3
    local tcW = (state.tc_ms) and 170 or 110
    local tsW = 90
    local minW = (buttonW + padX)*5 + (tcW + padX)*4 + (tsW + padX)*2

    -- Special topbar handling when window controls are present
    if ((osc_param.display_aspect > 0) and (osc_param.playresx < minW)) then
        osc_param.playresy = minW / osc_param.display_aspect
        osc_param.playresx = osc_param.playresy * osc_param.display_aspect
    end

    -- osc_geo.y = direction * (54 + user_opts.barmargin)
    osc_geo.y = direction * (osc_geo.h)
    osc_geo.w = osc_param.playresx + 4
    if direction < 0 then
        osc_geo.y = osc_geo.y + osc_param.playresy
    end

    -- local line1 = osc_geo.y - direction * (9 + padY)
    -- local line2 = osc_geo.y - direction * (36 + padY)
    local line1Y = osc_geo.y - direction * tethys.seekbarHeight
    local line2Y = osc_geo.y - direction * tethys.controlsHeight
    local leftPad = padX
    local rightPad = padX
    local leftX = osc_geo.x + leftPad
    local rightX = osc_geo.w - rightPad
    local leftSectionWidth = leftPad
    local rightSectionWidth = rightPad

    osc_param.areas = {}

    add_area("input", get_hitbox_coords(osc_geo.x, osc_geo.y, osc_geo.an,
                                        osc_geo.w, osc_geo.h))

    local sh_area_y0, sh_area_y1
    if direction > 0 then
        -- deadzone below OSC
        sh_area_y0 = user_opts.barmargin
        sh_area_y1 = (osc_geo.y + (osc_geo.h / 2)) +
                     get_align(1 - (2*user_opts.deadzonesize),
                     osc_param.playresy - (osc_geo.y + (osc_geo.h / 2)), 0, 0)
    else
        -- deadzone above OSC
        sh_area_y0 = get_align(-1 + (2*user_opts.deadzonesize),
                               osc_geo.y - (osc_geo.h / 2), 0, 0)
        sh_area_y1 = osc_param.playresy - user_opts.barmargin
    end
    add_area("showhide", 0, sh_area_y0, osc_param.playresx, sh_area_y1)

    local lo, geo

    -- Background bar
    new_element("bgbox", "box")
    lo = add_layout("bgbox")

    local boxBlur = 20 -- 0 .. 20
    geo = {
        x = osc_geo.x - boxBlur,
        y = osc_geo.y - boxBlur,
        an = osc_geo.an,
        w = osc_geo.w + boxBlur*2,
        h = osc_geo.h + boxBlur*2,
    }
    lo.geometry = geo
    lo.layer = 10
    lo.style = ("{\\rDefault\\blur(%d)\\bord0\\1c&H000000\\3c&HFFFFFF}"):format(boxBlur)
    lo.alpha[1] = 80 --- 0 (opaque) to 255 (fully transparent)

    function setButtonTooltip(button_lo, text)
        button_lo.button.tooltip = text
        button_lo.button.tooltip_style = tethysStyle.buttonTooltip
        local hw = button_lo.geometry.w/2
        local ty = osc_geo.y + padY * direction
        local an
        local tx
        local edgeThreshold = 60
        if button_lo.geometry.x - edgeThreshold < osc_geo.x + padX then
            an = 1 -- x,y is bottom-left
            tx = math.max(osc_geo.x + padX, button_lo.geometry.x - hw)
        elseif osc_geo.x + osc_geo.w - padX < button_lo.geometry.x + edgeThreshold then
            an = 3 -- x,y is bottom-right
            tx = math.min(button_lo.geometry.x + hw, osc_geo.x + osc_geo.w - padX)
        else
            an = 2 -- x,y is bottom-center
            tx = button_lo.geometry.x
        end
        button_lo.button.tooltip_an = an
        button_lo.button.tooltip_geo = { x = tx , y = ty }
    end

    ---- Left Section (Added Left-to-Right)
    -- Playback control buttons
    geo = {
        x = leftX + leftSectionWidth + buttonW/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = buttonW,
        h = buttonH,
    }
    lo = add_layout("playpause")
    lo.geometry = geo
    lo.style = tethysStyle.button
    setButtonTooltip(lo, pauseTooltip)
    leftSectionWidth = leftSectionWidth + geo.w

    -- Skip Backwards
    geo = {
        x = leftX + leftSectionWidth + smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("skipback")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, seekBackTooltip)
    leftSectionWidth = leftSectionWidth + geo.w

    -- Skip Forwards
    geo = {
        x = leftX + leftSectionWidth + smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("skipfrwd")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, seekFrwdTooltip)
    leftSectionWidth = leftSectionWidth + geo.w

    -- Chapter Prev
    geo = {
        x = leftX + leftSectionWidth + smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("ch_prev")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, function()
        local shortcutLabel = chPrevTooltip
        local prevChapter = getDeltaChapter(-1)
        if prevChapter == nil then
            return { shortcutLabel }
        else
            return { tethysStyle.text..prevChapter.label, shortcutLabel }
        end
    end)
    if elements["ch_prev"].visible then
        leftSectionWidth = leftSectionWidth + geo.w
    end
    
    -- Chapter Next
    geo = {
        x = leftX + leftSectionWidth + smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("ch_next")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, function()
        local shortcutLabel = chNextTooltip
        local nextChapter = getDeltaChapter(1)
        if nextChapter == nil then
            return { shortcutLabel }
        else
            return { tethysStyle.text..nextChapter.label, shortcutLabel }
        end
    end)
    if elements["ch_next"].visible then
        leftSectionWidth = leftSectionWidth + geo.w
    end

    -- Pad between Skip/Chapter and Volume
    leftSectionWidth = leftSectionWidth + padX

    -- Volume
    geo = {
        x = leftX + leftSectionWidth + smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("volume")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, volTooltip)
    if elements["volume"].visible then
        leftSectionWidth = leftSectionWidth + geo.w
    end

    ---- Right Section (Added Right-to-Left)
    -- Fullscreen button
    geo = {
        x = rightX - rightSectionWidth - smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("tog_fs")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, fullscreenTooltip)
    if elements["tog_fs"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- PictureInPicture button
    geo = {
        x = rightX - rightSectionWidth - smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("tog_pip")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, pipTooltip)
    if elements["tog_pip"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Speed
    geo = {
        x = rightX - rightSectionWidth - smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("speed")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    setButtonTooltip(lo, speedTooltip)
    if elements["speed"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Subtitle track
    local trackButtonSize = tethys.trackButtonSize
    local trackButtonWidth = calcTrackButtonWidth(tracks_osc.sub)
    geo = {
        x = rightX - rightSectionWidth - trackButtonWidth/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = trackButtonWidth,
        h = buttonH,
    }
    lo = add_layout("cy_sub")
    lo.geometry = geo
    lo.style = tethysStyle.trackButton
    setButtonTooltip(lo, subTooltip)
    if elements["cy_sub"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Audio track
    trackButtonWidth = calcTrackButtonWidth(tracks_osc.audio)
    geo = {
        x = rightX - rightSectionWidth - trackButtonWidth/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = trackButtonWidth,
        h = buttonH,
    }
    lo = add_layout("cy_audio")
    lo.geometry = geo
    lo.style = tethysStyle.trackButton
    setButtonTooltip(lo, audioTooltip)
    if elements["cy_audio"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Pad between Fullscreen/Tracks and Playlist
    rightSectionWidth = rightSectionWidth + padX

    -- Playlist next
    geo = {
        x = rightX - rightSectionWidth - smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("pl_next")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    lo.button.playlist = 1
    lo.button.hideSeekbar = true
    setButtonTooltip(lo, function()
        local shortcutLabel = plNextTooltip
        local nextItem = getDeltaPlaylistItem(1)
        if nextItem == nil then
            return { shortcutLabel }
        else
            return { tethysStyle.text..nextItem.label, shortcutLabel }
        end
    end)
    if elements["pl_next"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Playlist prev
    geo = {
        x = rightX - rightSectionWidth - smallButtonSize/2,
        y = line1Y + buttonH/2,
        an = 5, -- x,y is center
        w = smallButtonSize,
        h = buttonH,
    }
    lo = add_layout("pl_prev")
    lo.geometry = geo
    lo.style = tethysStyle.smallButton
    lo.button.playlist = -1
    lo.button.hideSeekbar = true
    setButtonTooltip(lo, function()
        local shortcutLabel = plPrevTooltip
        local nextItem = getDeltaPlaylistItem(-1)
        if nextItem == nil then
            return { shortcutLabel }
        else
            return { tethysStyle.text..nextItem.label, shortcutLabel }
        end
    end)
    if elements["pl_prev"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    -- Playlist Entries
    if #playlistElements >= 1 then
        local plButtonGeo = geo
        local plEntryWidth = tethys.sidebarWidth
        local plEntryHeight = tethys.playlistEntryTextSize * tethys.playlistEntryNumLines
        local plBox = {
            x = osc_geo.x + osc_geo.w - plEntryWidth,
            y = osc_geo.y - (plEntryHeight * #playlistElements),
            an = 7, -- x,y is top-left
            w = plEntryWidth,
            h = plEntryHeight * #playlistElements
        }
        add_area("pl-entries", plBox.x, plBox.y, plBox.x+plBox.w, plBox.y+plBox.h)

        -- Playlist Container
        new_element("plbox", "box")
        lo = add_layout("plbox")
        geo = {
            x = plBox.x - boxBlur,
            y = plBox.y - boxBlur,
            an = plBox.an,
            w = plBox.w + boxBlur*2,
            h = plBox.h + boxBlur*2,
        }
        lo.geometry = geo
        lo.layer = 10
        lo.style = ("{\\rDefault\\blur(%d)\\bord0\\1c&H000000\\3c&HFFFFFF}"):format(boxBlur)
        lo.alpha[1] = 80 --- 0 (opaque) to 255 (fully transparent)

        -- Playlist Entries
        for i, plEl in ipairs(playlistElements) do
            geo = {
                x = plBox.x,
                y = plBox.y + plEntryHeight * (i-1),
                an = 7, -- x,y is top-left
                w = plEntryWidth,
                h = plEntryHeight,
            }
            lo = add_layout(plEl.name)
            lo.geometry = geo
            lo.style = ("{\\fs(%d)\\clip(%s, %s, %s, %s)\\q}"):format(
                tethys.playlistEntryTextSize,
                geo.x,
                geo.y,
                geo.x + geo.w,
                geo.y + geo.h,
                1 -- End-of-line wrapping
            )
        end
    end

    -- Pad between Playlist and Cache
    if elements["cache"].visible then
        rightSectionWidth = rightSectionWidth + padX
    end

    -- Cache
    geo = {
        x = rightX - rightSectionWidth,
        y = line1Y + buttonH/2,
        an = 6, -- x,y is right-center
        w = 110,
        h = buttonH,
    }
    lo = add_layout("cache")
    lo.geometry = geo
    lo.style = tethysStyle.cacheText
    if elements["cache"].visible then
        rightSectionWidth = rightSectionWidth + geo.w
    end

    ---- Center Section
    -- Pad Center
    leftSectionWidth = leftSectionWidth + padX
    rightSectionWidth = rightSectionWidth + padX

    -- Timecodes
    geo = {
        x = leftX + leftSectionWidth,
        y = line1Y + buttonH/2,
        an = 4, -- x,y is top-left
        w = osc_geo.w - leftSectionWidth - rightSectionWidth,
        h = buttonH,
    }
    lo = add_layout("tc_both")
    lo.geometry = geo
    lo.style = tethysStyle.timecode


    -- Seekbar
    -- geo = { x = sb_l, y = geo.y, an = geo.an,
    --         w = math.max(0, sb_r - sb_l), h = geo.h }
    geo = {
        x = osc_geo.x,
        y = osc_geo.y,
        an = 7,
        w = osc_geo.w,
        h = tethys.seekbarHeight,
    }

    lo = add_layout("seekbar")
    lo.geometry = geo
    lo.style = tethysStyle.seekbar
    lo.slider.border = 0
    lo.slider.gap = 2
    lo.slider.tooltip_style = tethysStyle.seekbarTimestamp
    lo.slider.tooltip_an = 2
    lo.slider.stype = "knob" -- user_opts["seekbarstyle"] -- bar diamond knob
    lo.slider.rtype = "slider" -- user_opts["seekrangestyle"] -- bar line slider inverted none

    if direction < 0 then
        osc_param.video_margins.b = osc_geo.h / osc_param.playresy
    else
        osc_param.video_margins.t = osc_geo.h / osc_param.playresy
    end
end

-- Validate string type user options
function validate_user_opts()
    if layouts[user_opts.layout] == nil then
        msg.warn("Invalid setting \""..user_opts.layout.."\" for layout")
        user_opts.layout = "bottombar"
    end

    if user_opts.seekbarstyle ~= "bar" and
       user_opts.seekbarstyle ~= "diamond" and
       user_opts.seekbarstyle ~= "knob" then
        msg.warn("Invalid setting \"" .. user_opts.seekbarstyle
            .. "\" for seekbarstyle")
        user_opts.seekbarstyle = "bar"
    end

    if user_opts.seekrangestyle ~= "bar" and
       user_opts.seekrangestyle ~= "line" and
       user_opts.seekrangestyle ~= "slider" and
       user_opts.seekrangestyle ~= "inverted" and
       user_opts.seekrangestyle ~= "none" then
        msg.warn("Invalid setting \"" .. user_opts.seekrangestyle
            .. "\" for seekrangestyle")
        user_opts.seekrangestyle = "inverted"
    end

    if user_opts.seekrangestyle == "slider" and
       user_opts.seekbarstyle == "bar" then
        msg.warn("Using \"slider\" seekrangestyle together with \"bar\" seekbarstyle is not supported")
        user_opts.seekrangestyle = "inverted"
    end

    if user_opts.windowcontrols ~= "auto" and
       user_opts.windowcontrols ~= "yes" and
       user_opts.windowcontrols ~= "no" then
        msg.warn("windowcontrols cannot be \"" ..
                user_opts.windowcontrols .. "\". Ignoring.")
        user_opts.windowcontrols = "auto"
    end
    if user_opts.windowcontrols_alignment ~= "right" and
       user_opts.windowcontrols_alignment ~= "left" then
        msg.warn("windowcontrols_alignment cannot be \"" ..
                user_opts.windowcontrols_alignment .. "\". Ignoring.")
        user_opts.windowcontrols_alignment = "right"
    end
end

function update_options(list)
    validate_user_opts()
    request_tick()
    visibility_mode(user_opts.visibility, true)
    update_duration_watch()
    request_init()
end

-- OSC INIT
function osc_init()
    msg.debug("osc_init")

    -- set canvas resolution according to display aspect and scaling setting
    local baseResY = 720
    local display_w, display_h, display_aspect = mp.get_osd_size()
    local scale = 1

    if (mp.get_property("video") == "no") then -- dummy/forced window
        scale = user_opts.scaleforcedwindow
    elseif state.fullscreen then
        scale = user_opts.scalefullscreen
    else
        scale = user_opts.scalewindowed
    end

    if user_opts.vidscale then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if (display_aspect > 0) then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- stop seeking with the slider to prevent skipping files
    state.active_element = nil

    osc_param.video_margins = {l = 0, r = 0, t = 0, b = 0}

    elements = {}
    playlistElements = {}


    -- some often needed stuff
    local pl_count = mp.get_property_number("playlist-count", 0)
    local have_pl = (pl_count > 1)
    local pl_pos = mp.get_property_number("playlist-pos", 0) + 1
    local have_ch = (mp.get_property_number("chapters", 0) > 0)
    local loop = mp.get_property("loop-playlist", "no")

    local ne

    -- title
    ne = new_element("title", "button")

    ne.content = function ()
        local title = state.forced_title or
                      mp.command_native({"expand-text", user_opts.title})
        -- escape ASS, and strip newlines and trailing slashes
        title = title:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
        return not (title == "") and title or "mpv"
    end

    ne.eventresponder["mbtn_left_up"] = function ()
        local title = mp.get_property_osd("media-title")
        if (have_pl) then
            title = string.format("[%d/%d] %s", countone(pl_pos - 1),
                                  pl_count, title)
        end
        show_message(title)
    end

    ne.eventresponder["mbtn_right_up"] =
        function () show_message(mp.get_property_osd("filename")) end

    -- playlist buttons

    -- prev
    ne = new_element("pl_prev", "button")

    ne.content = tethysIcon_pl_prev
    ne.enabled = (pl_pos > 1) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-prev", "weak")
            if user_opts.playlist_osd then
                show_message(get_playlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_playlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist(), 3) end

    --next
    ne = new_element("pl_next", "button")

    ne.content = tethysIcon_pl_next
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no")
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("playlist-next", "weak")
            if user_opts.playlist_osd then
                show_message(get_playlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_playlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_playlist(), 3) end


    -- playlist
    if have_pl then
        local count, limlist = limited_list('playlist', pl_pos)
        local maxChars = tethys.playlistEntryNumChars
        local numLines = tethys.playlistEntryNumLines
        local elidePattern = "^.+(" .. string.rep(".", maxChars) .. ")$"
        for i, v in ipairs(limlist) do
            local title = v.title
            local _, filename = utils.split_path(v.filename)
            if title == nil then
                title = filename
            end

            -- local entryLabel = string.format('%s %s', (v.current and '●' or '○'), title)

            -- Elide text longer than 20 characters
            local entryLines = {}
            local entryLabel = ""
            for l = 1, numLines do
                if #title > 0 then
                    local line
                    if l == numLines then
                        -- LeftElide last line so we can read end of filename
                        -- With 2 lines, we basically MiddleElide
                        line = string.gsub(title, elidePattern, "…%1")
                    else
                        line = string.sub(title, 1, maxChars)
                    end
                    local prefix
                    if l == 1 then
                        prefix = (v.current and '●' or '○')
                    else
                        prefix = string.char(160, 160, 160, 160) -- 3x NBSP is same width as ○
                    end
                    entryLabel = entryLabel .. string.format('%s %s\\N', prefix, line)
                    title = string.sub(title, maxChars+1)
                end
            end

            ne = new_element(("pl_entry_%s"):format(i), "button")
            ne.content = entryLabel
            ne.eventresponder["mbtn_left_up"] = function ()
                print("playlist-play-index", v.index-1)
                mp.commandv("playlist-play-index", v.index-1)
            end
            table.insert(playlistElements, ne)
        end
    end


    -- big buttons

    --playpause
    ne = new_element("playpause", "button")

    ne.content = function ()
        if mp.get_property("pause") == "yes" then
            return tethysIcon_play
        else
            return tethysIcon_pause
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "pause") end

    --skipback
    ne = new_element("skipback", "button")

    ne.softrepeat = true
    ne.content = tethysIcon_skipback
    ne.eventresponder["mbtn_left_down"] =
        function () mp.commandv("seek", -tethys.skipBy, tethys.skipMode) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () mp.commandv("frame-back-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () mp.commandv("seek", -tethys.skipByMore, tethys.skipMode) end

    --skipfrwd
    ne = new_element("skipfrwd", "button")

    ne.softrepeat = true
    ne.content = tethysIcon_skipfrwd
    ne.eventresponder["mbtn_left_down"] =
        function () mp.commandv("seek", tethys.skipBy, tethys.skipMode) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () mp.commandv("frame-step") end
    ne.eventresponder["mbtn_right_down"] =
        function () mp.commandv("seek", tethys.skipByMore, tethys.skipMode) end

    --ch_prev
    ne = new_element("ch_prev", "button")

    ne.visible = have_ch
    ne.enabled = have_ch
    ne.content = tethysIcon_ch_prev
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("add", "chapter", -1)
            if user_opts.chapters_osd then
                show_message(get_chapterlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_chapterlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_chapterlist(), 3) end

    --ch_next
    ne = new_element("ch_next", "button")

    ne.visible = have_ch
    ne.enabled = have_ch
    ne.content = tethysIcon_ch_next
    ne.eventresponder["mbtn_left_up"] =
        function ()
            mp.commandv("add", "chapter", 1)
            if user_opts.chapters_osd then
                show_message(get_chapterlist(), 3)
            end
        end
    ne.eventresponder["shift+mbtn_left_up"] =
        function () show_message(get_chapterlist(), 3) end
    ne.eventresponder["mbtn_right_up"] =
        function () show_message(get_chapterlist(), 3) end

    --
    update_tracklist()

    --cy_audio
    ne = new_element("cy_audio", "button")

    ne.visible = (#tracks_osc.audio > 1)
    ne.enabled = (#tracks_osc.audio > 0)
    ne.content = function ()
        local aid = "–"
        if not (get_track("audio") == 0) then
            aid = get_track("audio")
        end
        return ("\238\132\134" .. tethysStyle.trackText
            .. " " .. aid .. "/" .. #tracks_osc.audio)
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("audio", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("audio", -1) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () show_message(get_tracklist("audio"), 2) end

    --cy_sub
    ne = new_element("cy_sub", "button")

    ne.enabled = (#tracks_osc.sub > 0)
    ne.content = function ()
        local sid = "–"
        if not (get_track("sub") == 0) then
            sid = get_track("sub")
        end
        return ("\238\132\135" .. tethysStyle.trackText
            .. " " .. sid .. "/" .. #tracks_osc.sub)
    end
    ne.eventresponder["mbtn_left_up"] =
        function () set_track("sub", 1) end
    ne.eventresponder["mbtn_right_up"] =
        function () set_track("sub", -1) end
    ne.eventresponder["shift+mbtn_left_down"] =
        function () show_message(get_tracklist("sub"), 2) end

    --tog_pip
    ne = new_element("tog_pip", "button")
    ne.visible = tethys.showPictureInPictureButton
    ne.content = function ()
        if (tethys.isPictureInPicture) then
            return tethysIcon_pip_exit
        else
            return tethysIcon_pip_enter
        end
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        togglePictureInPicture()
    end

    --tog_fs
    ne = new_element("tog_fs", "button")
    ne.content = function ()
        if (state.fullscreen) then
            return mpvOsdIcon_fs_exit
        else
            return mpvOsdIcon_fs_enter
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "fullscreen") end

    --seekbar
    ne = new_element("seekbar", "slider")

    ne.enabled = not (mp.get_property("percent-pos") == nil)
    state.slider_element = ne.enabled and ne or nil  -- used for forced_title
    ne.slider.markerF = function ()
        local duration = mp.get_property_number("duration", nil)
        if not (duration == nil) then
            local chapters = mp.get_property_native("chapter-list", {})
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF =
        function () return mp.get_property_number("percent-pos", nil) end
    ne.slider.tooltipF = function (pos)
        local duration = mp.get_property_number("duration", nil)
        if not ((duration == nil) or (pos == nil)) then
            possec = duration * (pos / 100)
            return mp.format_time(possec)
        else
            return ""
        end
    end
    ne.slider.seekRangesF = function()
        if user_opts.seekrangestyle == "none" then
            return nil
        end
        local cache_state = state.cache_state
        if not cache_state then
            return nil
        end
        local duration = mp.get_property_number("duration", nil)
        if (duration == nil) or duration <= 0 then
            return nil
        end
        local ranges = cache_state["seekable-ranges"]
        if #ranges == 0 then
            return nil
        end
        local nranges = {}
        for _, range in pairs(ranges) do
            nranges[#nranges + 1] = {
                ["start"] = 100 * range["start"] / duration,
                ["end"] = 100 * range["end"] / duration,
            }
        end
        return nranges
    end
    ne.eventresponder["mouse_move"] = --keyframe seeking when mouse is dragged
        function (element)
            if not element.state.mbtnleft then
                return -- allow drag for mbtnleft only
            end
            -- mouse move events may pile up during seeking and may still get
            -- sent when the user is done seeking, so we need to throw away
            -- identical seeks
            local seekto = get_slider_value(element)
            if (element.state.lastseek == nil) or
                (not (element.state.lastseek == seekto)) then
                    local flags = "absolute-percent"
                    if not user_opts.seekbarkeyframes then
                        flags = flags .. "+exact"
                    end
                    mp.commandv("seek", seekto, flags)
                    element.state.lastseek = seekto
            end

        end
    ne.eventresponder["mbtn_left_down"] = --exact seeks on single clicks
        function (element)
            element.state.mbtnleft = true
            mp.commandv("seek", get_slider_value(element), "absolute-percent", "exact")
        end
    ne.eventresponder['mbtn_left_up'] =
        function (element)
            element.state.mbtnleft = false
        end
    ne.eventresponder['mbtn_right_down'] = --seeks to chapter start
        function (element)
            -- Source: https://github.com/maoiscat/mpv-osc-morden/blob/main/morden.lua#L1395-L1413
            local duration = mp.get_property_number("duration", nil)
            if not (duration == nil) then
                local chapters = mp.get_property_native("chapter-list", {})
                if #chapters > 0 then
                    local pos = get_slider_value(element)
                    local ch = #chapters
                    for n = 1, ch do
                        if chapters[n].time / duration * 100 >= pos then
                            ch = n - 1
                            break
                        end
                    end
                    mp.commandv("set", "chapter", ch - 1)
                    --if chapters[ch].title then show_message(chapters[ch].time) end
                end
            end
        end
    ne.eventresponder["reset"] =
        function (element) element.state.lastseek = nil end

    -- tc_both (current pos)
    ne = new_element("tc_both", "button")

    ne.content = function ()
        if (state.rightTC_trem) then
            if (state.tc_ms) then
                return (mp.get_property_osd("playback-time/full").." / ".."-"..mp.get_property_osd("playtime-remaining/full"))
            else
                return (mp.get_property_osd("playback-time").." / ".."-"..mp.get_property_osd("playtime-remaining"))
            end
        else
            if (state.tc_ms) then
                return (mp.get_property_osd("playback-time/full").." / "..mp.get_property_osd("duration/full"))
            else
                return (mp.get_property_osd("playback-time").." / "..mp.get_property_osd("duration"))
            end
        end
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        state.rightTC_trem = not state.rightTC_trem
    end

    -- tc_left (current pos)
    ne = new_element("tc_left", "button")

    ne.content = function ()
        if (state.tc_ms) then
            return (mp.get_property_osd("playback-time/full"))
        else
            return (mp.get_property_osd("playback-time"))
        end
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        state.tc_ms = not state.tc_ms
        request_init()
    end

    -- tc_right (total/remaining time)
    ne = new_element("tc_right", "button")

    ne.visible = (mp.get_property_number("duration", 0) > 0)
    ne.content = function ()
        if (state.rightTC_trem) then
            if state.tc_ms then
                return ("-"..mp.get_property_osd("playtime-remaining/full"))
            else
                return ("-"..mp.get_property_osd("playtime-remaining"))
            end
        else
            if state.tc_ms then
                return (mp.get_property_osd("duration/full"))
            else
                return (mp.get_property_osd("duration"))
            end
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () state.rightTC_trem = not state.rightTC_trem end

    -- cache
    ne = new_element("cache", "button")

    ne.content = function ()
        local cache_state = state.cache_state
        if not (cache_state and cache_state["seekable-ranges"] and
            #cache_state["seekable-ranges"] > 0) then
            -- probably not a network stream
            return ""
        end
        local dmx_cache = cache_state and cache_state["cache-duration"]
        local thresh = math.min(state.dmx_cache * 0.05, 5)  -- 5% or 5s
        if dmx_cache and math.abs(dmx_cache - state.dmx_cache) >= thresh then
            state.dmx_cache = dmx_cache
        else
            dmx_cache = state.dmx_cache
        end
        local min = math.floor(dmx_cache / 60)
        local sec = math.floor(dmx_cache % 60) -- don't round e.g. 59.9 to 60
        return "Cache: " .. (min > 0 and
            string.format("%sm%02.0fs", min, sec) or
            string.format("%3.0fs", sec))
    end

    -- volume
    ne = new_element("volume", "button")

    ne.content = function()
        local volume = mp.get_property_number("volume", 0)
        local mute = mp.get_property_native("mute")
        local volicon = {
            tethysIcon_vol_033,
            tethysIcon_vol_066,
            tethysIcon_vol_100,
            tethysIcon_vol_101,
        }
        if volume == 0 or mute then
            return tethysIcon_vol_mute
        else
            return volicon[math.min(4,math.ceil(volume / (100/3)))]
        end
    end
    ne.eventresponder["mbtn_left_up"] =
        function () mp.commandv("cycle", "mute") end

    ne.eventresponder["wheel_up_press"] =
        function () mp.commandv("osd-auto", "add", "volume", 5) end
    ne.eventresponder["wheel_down_press"] =
        function () mp.commandv("osd-auto", "add", "volume", -5) end

    -- speed
    ne = new_element("speed", "button")
    ne.visible = tethys.showSpeedButton
    ne.content = function()
        return tethysIcon_speed
    end
    ne.eventresponder["mbtn_left_up"] = function ()
        local speed = mp.get_property_number("speed", 1)
        local normalDiff = math.abs(speed - 1)
        if normalDiff >= 0.1 then
            mp.commandv("osd-auto", "set", "speed", 1)
        else
            mp.commandv("osd-auto", "set", "speed", 2)
        end
    end
    ne.eventresponder["wheel_up_press"] =
        function () mp.commandv("osd-auto", "add", "speed", 0.25) end
    ne.eventresponder["wheel_down_press"] =
        function () mp.commandv("osd-auto", "add", "speed", -0.25) end

    -- load layout
    layouts[user_opts.layout]()

    -- load window controls
    if window_controls_enabled() then
        window_controls(user_opts.layout == "topbar")
    end

    --do something with the elements
    prepare_elements()

    update_margins()
end

function reset_margins()
    if state.using_video_margins then
        for _, opt in ipairs(margins_opts) do
            mp.set_property_number(opt[2], 0.0)
        end
        state.using_video_margins = false
    end
end

function update_margins()
    local margins = osc_param.video_margins

    -- Don't use margins if it's visible only temporarily.
    if (not state.osc_visible) or
       (state.fullscreen and not user_opts.showfullscreen) or
       (not state.fullscreen and not user_opts.showwindowed)
    then
        margins = {l = 0, r = 0, t = 0, b = 0}
    end

    if user_opts.boxvideo then
        -- check whether any margin option has a non-default value
        local margins_used = false

        if not state.using_video_margins then
            for _, opt in ipairs(margins_opts) do
                if mp.get_property_number(opt[2], 0.0) ~= 0.0 then
                    margins_used = true
                end
            end
        end

        if not margins_used then
            for _, opt in ipairs(margins_opts) do
                local v = margins[opt[1]]
                if (v ~= 0) or state.using_video_margins then
                    mp.set_property_number(opt[2], v)
                    state.using_video_margins = true
                end
            end
        end
    else
        reset_margins()
    end

    utils.shared_script_property_set("osc-margins",
        string.format("%f,%f,%f,%f", margins.l, margins.r, margins.t, margins.b))
end

function shutdown()
    reset_margins()
    utils.shared_script_property_set("osc-margins", nil)
end

--
-- Other important stuff
--


function updateSubMarginY(oscVisible)
    local defMarginY = 22 -- https://mpv.io/manual/master/#options-sub-margin-y
    local subMarginY = oscVisible and (defMarginY+tethys.bottomBarHeight) or defMarginY
    mp.set_property_number("sub-margin-y", subMarginY)
end

function show_osc()
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end

    msg.trace("show_osc")
    --remember last time of invocation (mouse move)
    state.showtime = mp.get_time()

    osc_visible(true)

    if (user_opts.fadeduration > 0) then
        state.anitype = nil
    end
end

function hide_osc()
    msg.trace("hide_osc")
    if not state.enabled then
        -- typically hide happens at render() from tick(), but now tick() is
        -- no-op and won't render again to remove the osc, so do that manually.
        state.osc_visible = false
        render_wipe()
    elseif (user_opts.fadeduration > 0) then
        if not(state.osc_visible == false) then
            state.anitype = "out"
            request_tick()
        end
    else
        osc_visible(false)
    end
end

function osc_visible(visible)
    if state.osc_visible ~= visible then
        state.osc_visible = visible
        update_margins()
        updateSubMarginY(visible)
    end
    request_tick()
end

function pause_state(name, enabled)
    state.paused = enabled
    request_tick()
end

function cache_state(name, st)
    state.cache_state = st
    request_tick()
end

-- Request that tick() is called (which typically re-renders the OSC).
-- The tick is then either executed immediately, or rate-limited if it was
-- called a small time ago.
function request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

function mouse_leave()
    if get_hidetimeout() >= 0 then
        hide_osc()
    end
    -- reset mouse position
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

function request_init()
    state.initREQ = true
    request_tick()
end

-- Like request_init(), but also request an immediate update
function request_init_resize()
    request_init()
    -- ensure immediate update
    state.tick_timer:kill()
    state.tick_timer.timeout = 0
    state.tick_timer:resume()
end

function render_wipe()
    msg.trace("render_wipe()")
    state.osd.data = "" -- allows set_osd to immediately update on enable
    state.osd:remove()
end

function render()
    msg.trace("rendering")
    local current_screen_sizeX, current_screen_sizeY, aspect = mp.get_osd_size()
    local mouseX, mouseY = get_virt_mouse_pos()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if not (state.mp_screen_sizeX == current_screen_sizeX
        and state.mp_screen_sizeY == current_screen_sizeY) then

        request_init_resize()

        state.mp_screen_sizeX = current_screen_sizeX
        state.mp_screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.active_element then
        -- mouse is held down on some element - keep ticking and igore initReq
        -- till it's released, or else the mouse-up (click) will misbehave or
        -- get ignored. that's because osc_init() recreates the osc elements,
        -- but mouse handling depends on the elements staying unmodified
        -- between mouse-down and mouse-up (using the index active_element).
        request_tick()
    elseif state.initREQ then
        osc_init()
        state.initREQ = false

        -- store initial mouse position
        if (state.last_mouseX == nil or state.last_mouseY == nil)
            and not (mouseX == nil or mouseY == nil) then

            state.last_mouseX, state.last_mouseY = mouseX, mouseY
        end
    end


    -- fade animation
    if not(state.anitype == nil) then

        if (state.anistart == nil) then
            state.anistart = now
        end

        if (now < state.anistart + (user_opts.fadeduration/1000)) then

            if (state.anitype == "in") then --fade in
                osc_visible(true)
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    255, 0, now)
            elseif (state.anitype == "out") then --fade out
                state.animation = scale_value(state.anistart,
                    (state.anistart + (user_opts.fadeduration/1000)),
                    0, 255, now)
            end

        else
            if (state.anitype == "out") then
                osc_visible(false)
            end
            kill_animation()
        end
    else
        kill_animation()
    end

    --mouse show/hide area
    for k,cords in pairs(osc_param.areas["showhide"]) do
        set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for k,cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    do_enable_keybindings()

    --mouse input area
    local mouse_over_osc = false

    for _,cords in ipairs(osc_param.areas["input"]) do
        if state.osc_visible then -- activate only when OSC is actually visible
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "input")
        end
        if state.osc_visible ~= state.input_enabled then
            if state.osc_visible then
                mp.enable_key_bindings("input")
            else
                mp.disable_key_bindings("input")
            end
            state.input_enabled = state.osc_visible
        end

        if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
            mouse_over_osc = true
        end
    end

    if osc_param.areas["window-controls"] then
        for _,cords in ipairs(osc_param.areas["window-controls"]) do
            if state.osc_visible then -- activate only when OSC is actually visible
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "window-controls")
                mp.enable_key_bindings("window-controls")
            else
                mp.disable_key_bindings("window-controls")
            end

            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    if osc_param.areas["window-controls-title"] then
        for _,cords in ipairs(osc_param.areas["window-controls-title"]) do
            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    if osc_param.areas["pl-entries"] then
        for _,cords in ipairs(osc_param.areas["pl-entries"]) do
            if state.osc_visible then -- activate only when OSC is actually visible
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "pl-entries")
            end
            if state.osc_visible ~= state.input_enabled then
                if state.osc_visible then
                    mp.enable_key_bindings("pl-entries")
                else
                    mp.disable_key_bindings("pl-entries")
                end
                state.input_enabled = state.osc_visible
            end

            if (mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2)) then
                mouse_over_osc = true
            end
        end
    end

    -- autohide
    if not (state.showtime == nil) and (get_hidetimeout() >= 0) then
        local timeout = state.showtime + (get_hidetimeout()/1000) - now
        if timeout <= 0 then
            if (state.active_element == nil) and not (mouse_over_osc) then
                hide_osc()
            end
        else
            -- the timer is only used to recheck the state and to possibly run
            -- the code above again
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            state.hide_timer.timeout = timeout
            -- re-arm
            state.hide_timer:kill()
            state.hide_timer:resume()
        end
    end


    -- actual rendering
    local ass = assdraw.ass_new()

    -- Messages
    render_message(ass)

    -- PreRender
    preRenderThumbnails()

    -- actual OSC
    if state.osc_visible then
        render_elements(ass)
    end

    -- PostRender
    postRenderThumbnails()

    -- submit
    set_osd(osc_param.playresy * osc_param.display_aspect,
            osc_param.playresy, ass.text)
end

--
-- Eventhandling
--

local function element_has_action(element, action)
    return element and element.eventresponder and
        element.eventresponder[action]
end

function process_event(source, what)
    local action = string.format("%s%s", source,
        what and ("_" .. what) or "")

    if what == "down" or what == "press" then

        for n = 1, #elements do

            if mouse_hit(elements[n]) and
                elements[n].eventresponder and
                (elements[n].eventresponder[source .. "_up"] or
                    elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                end
                -- fire the down or press event if the element has one
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end

            end
        end

    elseif what == "up" then

        if elements[state.active_element] then
            local n = state.active_element

            if n == 0 then
                --click on background (does not work)
            elseif element_has_action(elements[n], action) and
                mouse_hit(elements[n]) then

                elements[n].eventresponder[action](elements[n])
            end

            --reset active element
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end

        end
        state.active_element = nil
        state.mouse_down_counter = 0

    elseif source == "mouse_move" then

        state.mouse_in_window = true

        local mouseX, mouseY = get_virt_mouse_pos()
        if (user_opts.minmousemove == 0) or
            (not ((state.last_mouseX == nil) or (state.last_mouseY == nil)) and
                ((math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove)
                    or (math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)
                )
            ) then
            show_osc()
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end
    end

    -- ensure rendering after any (mouse) event - icons could change etc
    request_tick()
end


local logo_lines = {
    -- White border
    "{\\c&HE5E5E5&\\p6}m 895 10 b 401 10 0 410 0 905 0 1399 401 1800 895 1800 1390 1800 1790 1399 1790 905 1790 410 1390 10 895 10 {\\p0}",
    -- Purple fill
    "{\\c&H682167&\\p6}m 925 42 b 463 42 87 418 87 880 87 1343 463 1718 925 1718 1388 1718 1763 1343 1763 880 1763 418 1388 42 925 42{\\p0}",
    -- Darker fill
    "{\\c&H430142&\\p6}m 1605 828 b 1605 1175 1324 1456 977 1456 631 1456 349 1175 349 828 349 482 631 200 977 200 1324 200 1605 482 1605 828{\\p0}",
    -- White fill
    "{\\c&HDDDBDD&\\p6}m 1296 910 b 1296 1131 1117 1310 897 1310 676 1310 497 1131 497 910 497 689 676 511 897 511 1117 511 1296 689 1296 910{\\p0}",
    -- Triangle
    "{\\c&H691F69&\\p6}m 762 1113 l 762 708 b 881 776 1000 843 1119 911 1000 978 881 1046 762 1113{\\p0}",
}

local santa_hat_lines = {
    -- Pompoms
    "{\\c&HC0C0C0&\\p6}m 500 -323 b 491 -322 481 -318 475 -311 465 -312 456 -319 446 -318 434 -314 427 -304 417 -297 410 -290 404 -282 395 -278 390 -274 387 -267 381 -265 377 -261 379 -254 384 -253 397 -244 409 -232 425 -228 437 -228 446 -218 457 -217 462 -216 466 -213 468 -209 471 -205 477 -203 482 -206 491 -211 499 -217 508 -222 532 -235 556 -249 576 -267 584 -272 584 -284 578 -290 569 -305 550 -312 533 -309 523 -310 515 -316 507 -321 505 -323 503 -323 500 -323{\\p0}",
    "{\\c&HE0E0E0&\\p6}m 315 -260 b 286 -258 259 -240 246 -215 235 -210 222 -215 211 -211 204 -188 177 -176 172 -151 170 -139 163 -128 154 -121 143 -103 141 -81 143 -60 139 -46 125 -34 129 -17 132 -1 134 16 142 30 145 56 161 80 181 96 196 114 210 133 231 144 266 153 303 138 328 115 373 79 401 28 423 -24 446 -73 465 -123 483 -174 487 -199 467 -225 442 -227 421 -232 402 -242 384 -254 364 -259 342 -250 322 -260 320 -260 317 -261 315 -260{\\p0}",
    -- Main cap
    "{\\c&H0000F0&\\p6}m 1151 -523 b 1016 -516 891 -458 769 -406 693 -369 624 -319 561 -262 526 -252 465 -235 479 -187 502 -147 551 -135 588 -111 1115 165 1379 232 1909 761 1926 800 1952 834 1987 858 2020 883 2053 912 2065 952 2088 1000 2146 962 2139 919 2162 836 2156 747 2143 662 2131 615 2116 567 2122 517 2120 410 2090 306 2089 199 2092 147 2071 99 2034 64 1987 5 1928 -41 1869 -86 1777 -157 1712 -256 1629 -337 1578 -389 1521 -436 1461 -476 1407 -509 1343 -507 1284 -515 1240 -519 1195 -521 1151 -523{\\p0}",
    -- Cap shadow
    "{\\c&H0000AA&\\p6}m 1657 248 b 1658 254 1659 261 1660 267 1669 276 1680 284 1689 293 1695 302 1700 311 1707 320 1716 325 1726 330 1735 335 1744 347 1752 360 1761 371 1753 352 1754 331 1753 311 1751 237 1751 163 1751 90 1752 64 1752 37 1767 14 1778 -3 1785 -24 1786 -45 1786 -60 1786 -77 1774 -87 1760 -96 1750 -78 1751 -65 1748 -37 1750 -8 1750 20 1734 78 1715 134 1699 192 1694 211 1689 231 1676 246 1671 251 1661 255 1657 248 m 1909 541 b 1914 542 1922 549 1917 539 1919 520 1921 502 1919 483 1918 458 1917 433 1915 407 1930 373 1942 338 1947 301 1952 270 1954 238 1951 207 1946 214 1947 229 1945 239 1939 278 1936 318 1924 356 1923 362 1913 382 1912 364 1906 301 1904 237 1891 175 1887 150 1892 126 1892 101 1892 68 1893 35 1888 2 1884 -9 1871 -20 1859 -14 1851 -6 1854 9 1854 20 1855 58 1864 95 1873 132 1883 179 1894 225 1899 273 1908 362 1910 451 1909 541{\\p0}",
    -- Brim and tip pompom
    "{\\c&HF8F8F8&\\p6}m 626 -191 b 565 -155 486 -196 428 -151 387 -115 327 -101 304 -47 273 2 267 59 249 113 219 157 217 213 215 265 217 309 260 302 285 283 373 264 465 264 555 257 608 252 655 292 709 287 759 294 816 276 863 298 903 340 972 324 1012 367 1061 394 1125 382 1167 424 1213 462 1268 482 1322 506 1385 546 1427 610 1479 662 1510 690 1534 725 1566 752 1611 796 1664 830 1703 880 1740 918 1747 986 1805 1005 1863 991 1897 932 1916 880 1914 823 1945 777 1961 725 1979 673 1957 622 1938 575 1912 534 1862 515 1836 473 1790 417 1755 351 1697 305 1658 266 1633 216 1593 176 1574 138 1539 116 1497 110 1448 101 1402 77 1371 37 1346 -16 1295 15 1254 6 1211 -27 1170 -62 1121 -86 1072 -104 1027 -128 976 -133 914 -130 851 -137 794 -162 740 -181 679 -168 626 -191 m 2051 917 b 1971 932 1929 1017 1919 1091 1912 1149 1923 1214 1970 1254 2000 1279 2027 1314 2066 1325 2139 1338 2212 1295 2254 1238 2281 1203 2287 1158 2282 1116 2292 1061 2273 1006 2229 970 2206 941 2167 938 2138 918{\\p0}",
}

-- called by mpv on every frame
function tick()
    if state.marginsREQ == true then
        update_margins()
        state.marginsREQ = false
    end

    if (not state.enabled) then return end

    if (state.idle) then

        -- render idle message
        msg.trace("idle message")
        local icon_x, icon_y = 320 - 26, 140
        local line_prefix = ("{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}"):format(icon_x, icon_y)

        local ass = assdraw.ass_new()
        -- mpv logo
        for i, line in ipairs(logo_lines) do
            ass:new_event()
            ass:append(line_prefix .. line)
        end

        -- Santa hat
        if is_december and not user_opts.greenandgrumpy then
            for i, line in ipairs(santa_hat_lines) do
                ass:new_event()
                ass:append(line_prefix .. line)
            end
        end

        ass:new_event()
        ass:pos(320, icon_y+65)
        ass:an(8)
        ass:append("Drop files or URLs to play here.")
        set_osd(640, 360, ass.text)

        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
            state.showhide_enabled = false
        end


    elseif (state.fullscreen and user_opts.showfullscreen)
        or (not state.fullscreen and user_opts.showwindowed) then

        -- render the OSC
        render()
    else
        -- Flush OSD
        render_wipe()
    end

    state.tick_last_time = mp.get_time()

    if state.anitype ~= nil then
        -- state.anistart can be nil - animation should now start, or it can
        -- be a timestamp when it started. state.idle has no animation.
        if not state.idle and
           (not state.anistart or
            mp.get_time() < 1 + state.anistart + user_opts.fadeduration/1000)
        then
            -- animating or starting, or still within 1s past the deadline
            request_tick()
        else
            kill_animation()
        end
    end
end

function do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc() -- acts immediately when state.enabled == false
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
        end
        state.showhide_enabled = false
    end
end

-- duration is observed for the sole purpose of updating chapter markers
-- positions. live streams with chapters are very rare, and the update is also
-- expensive (with request_init), so it's only observed when we have chapters
-- and the user didn't disable the livemarkers option (update_duration_watch).
function on_duration() request_init() end

local duration_watched = false
function update_duration_watch()
    local want_watch = user_opts.livemarkers and
                       (mp.get_property_number("chapters", 0) or 0) > 0 and
                       true or false  -- ensure it's a boolean

    if (want_watch ~= duration_watched) then
        if want_watch then
            mp.observe_property("duration", nil, on_duration)
        else
            mp.unobserve_property(on_duration)
        end
        duration_watched = want_watch
    end
end

validate_user_opts()
update_duration_watch()

mp.register_event("shutdown", shutdown)
mp.register_event("start-file", request_init)
mp.observe_property("track-list", nil, request_init)
mp.observe_property("playlist", nil, request_init)
mp.observe_property("chapter-list", "native", function(_, list)
    list = list or {}  -- safety, shouldn't return nil
    table.sort(list, function(a, b) return a.time < b.time end)
    state.chapter_list = list
    update_duration_watch()
    request_init()
end)

mp.register_script_message("osc-message", show_message)
mp.register_script_message("osc-chapterlist", function(dur)
    show_message(get_chapterlist(), dur)
end)
mp.register_script_message("osc-playlist", function(dur)
    show_message(get_playlist(), dur)
end)
mp.register_script_message("osc-tracklist", function(dur)
    local msg = {}
    for k,v in pairs(nicetypes) do
        table.insert(msg, get_tracklist(k))
    end
    show_message(table.concat(msg, '\n\n'), dur)
end)

mp.observe_property("fullscreen", "bool",
    function(name, val)
        state.fullscreen = val
        state.marginsREQ = true
        request_init_resize()
    end
)
mp.observe_property("border", "bool",
    function(name, val)
        state.border = val
        request_init_resize()
    end
)
mp.observe_property("window-maximized", "bool",
    function(name, val)
        state.maximized = val
        request_init_resize()
    end
)
mp.observe_property("idle-active", "bool",
    function(name, val)
        state.idle = val
        request_tick()
    end
)
mp.observe_property("pause", "bool", pause_state)
mp.observe_property("demuxer-cache-state", "native", cache_state)
mp.observe_property("vo-configured", "bool", function(name, val)
    request_tick()
end)
mp.observe_property("playback-time", "number", function(name, val)
    request_tick()
end)
mp.observe_property("osd-dimensions", "native", function(name, val)
    -- (we could use the value instead of re-querying it all the time, but then
    --  we might have to worry about property update ordering)
    request_init_resize()
end)

-- mouse show/hide bindings
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide", "force")
mp.set_key_bindings({
    {"mouse_move",              function(e) process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide_wc", "force")
do_enable_keybindings()

--mouse input bindings
mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
    {"shift+mbtn_left",     function(e) process_event("shift+mbtn_left", "up") end,
                            function(e) process_event("shift+mbtn_left", "down")  end},
    {"mbtn_right",          function(e) process_event("mbtn_right", "up") end,
                            function(e) process_event("mbtn_right", "down")  end},
    -- alias to shift_mbtn_left for single-handed mouse use
    {"mbtn_mid",            function(e) process_event("shift+mbtn_left", "up") end,
                            function(e) process_event("shift+mbtn_left", "down")  end},
    {"wheel_up",            function(e) process_event("wheel_up", "press") end},
    {"wheel_down",          function(e) process_event("wheel_down", "press") end},
    {"mbtn_left_dbl",       "ignore"},
    {"shift+mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")
mp.enable_key_bindings("input")

mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
}, "pl-entries", "force")
mp.enable_key_bindings("pl-entries")

mp.set_key_bindings({
    {"mbtn_left",           function(e) process_event("mbtn_left", "up") end,
                            function(e) process_event("mbtn_left", "down")  end},
}, "window-controls", "force")
mp.enable_key_bindings("window-controls")

function get_hidetimeout()
    if user_opts.visibility == "always" then
        return -1 -- disable autohide
    end
    return user_opts.hidetimeout
end

function always_on(val)
    if state.enabled then
        if val then
            show_osc()
        else
            hide_osc()
        end
    end
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
function visibility_mode(mode, no_osd)
    if mode == "cycle" then
        if not state.enabled then
            mode = "auto"
        elseif user_opts.visibility ~= "always" then
            mode = "always"
        else
            mode = "never"
        end
    end

    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end

    user_opts.visibility = mode
    utils.shared_script_property_set("osc-visibility", mode)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    -- Reset the input state on a mode change. The input state will be
    -- recalculated on the next render cycle, except in 'never' mode where it
    -- will just stay disabled.
    mp.disable_key_bindings("input")
    mp.disable_key_bindings("window-controls")
    state.input_enabled = false

    update_margins()
    request_tick()
end

visibility_mode(user_opts.visibility, true)
mp.register_script_message("osc-visibility", visibility_mode)
mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)

set_virt_mouse_area(0, 0, 0, 0, "input")
set_virt_mouse_area(0, 0, 0, 0, "pl-entries")
set_virt_mouse_area(0, 0, 0, 0, "window-controls")
