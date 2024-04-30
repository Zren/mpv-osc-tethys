# mpv-osc-tethys

This theme replaces [the built in `osc.lua`](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua) shipped with [mpv](https://github.com/mpv-player/mpv).

![](https://i.imgur.com/cYqWlw5.png)

Local files can show thumbnail previews (using [thumbfast](https://github.com/po5/thumbfast) or a patched version of [mpv_thumbnail_script](https://github.com/TheAMM/mpv_thumbnail_script)).

![](https://i.imgur.com/FegXl3W.png)

Picture-In-Picture button to position in the corner, on top of other windows, and on all virtual desktops.

![](https://i.imgur.com/Ynlog81.png)

## Install

(1) Copy `osc_tethys.lua`, `mpv_thumbnail_script_server.lua` and mpv's `autoload.lua` to

* Windows: `%APPDATA%\mpv\scripts\` (`C:\Users\USER\AppData\Roaming\mpv\scripts\`)
  1. Type `%APPDATA%` in the File Explorer address bar and hit enter.  
    You should be in `C:\Users\USER\AppData\Roaming\` where `USER` is your username.
  2. Create the `C:\Users\USER\AppData\Roaming\mpv\scripts\` folder if it doesn't exist.
  3. View the following scripts and Save Page As (`Ctrl+S`). Save the files in the `...\scripts\` directory.
      * https://raw.githubusercontent.com/Zren/mpv-osc-tethys/master/osc_tethys.lua
      * https://raw.githubusercontent.com/Zren/mpv-osc-tethys/master/mpv_thumbnail_script_server.lua
      * https://raw.githubusercontent.com/mpv-player/mpv/master/TOOLS/lua/autoload.lua
  4. You should now have `C:\Users\USER\AppData\Roaming\mpv\scripts\osc_tethys.lua`
* Linux: `~/.config/mpv/scripts/`

  ```sh
  mkdir -p ~/.config/mpv/scripts/
  cd ~/.config/mpv/scripts/
  wget https://raw.githubusercontent.com/Zren/mpv-osc-tethys/master/osc_tethys.lua
  wget https://raw.githubusercontent.com/Zren/mpv-osc-tethys/master/mpv_thumbnail_script_server.lua
  wget https://raw.githubusercontent.com/mpv-player/mpv/master/TOOLS/lua/autoload.lua
  ```

(2) Edit `~/.config/mpv/mpv.conf` (`%APPDATA%\mpv\mpv.conf` on Windows) to disable the default `osc.lua` and improve the window.

* `osc=no` will disable the default `osc.lua`
* `border=no` will remove the window titlebar and frame. You can still drag a window by dragging the video.
* `keep-open=yes` will keep the player open after the video has finished.
* `keepaspect-window=no` will allow black borders around the video when maximized or half screen.

```ini
osc=no
border=no
keep-open=yes
keepaspect-window=no
```

(3) Edit `~/.config/mpv/input.conf` (`%APPDATA%\mpv\input.conf` on Windows) to rebind LEFT/RIGHT arrows to exactly 5s skips.

```ini
# Defaults: https://github.com/mpv-player/mpv/blob/master/etc/input.conf

# Seek by exactly 5s instead of relative+keyframes 10s
RIGHT seek  5 exact            # forward
LEFT  seek -5 exact            # backward
WHEEL_UP      seek  5 exact    # forward
WHEEL_DOWN    seek -5 exact    # backward
# Seek by exactly 30s instead of relative+keyframes 60s
UP    seek  30 exact           # forward
DOWN  seek -30 exact           # backward
```

(4) Close and reopen MPV to view the new Tethys theme!

## Configuration

If you don't like any of the default colors/sizes, you can create a few text files to configure certain settings.

#### tethys.conf

A complete list of configuration keys can be found at the top of [`osc_tethys.lua`](osc_tethys.lua).

* Windows: `%APPDATA%\mpv\script-opts\tethys.conf`
* Linux: `~/.config/mpv/script-opts/tethys.conf`

```ini
### Config
showPictureInPictureButton=yes
showSpeedButton=yes
# Show name and shortcut of buttons on hover
showShortcutTooltip=yes
# Show chapter above timestamp in seekbar tooltip
showChapterTooltip=yes
# skipback/skipfrwd amount in seconds
skipBy=5
# RightClick skipback/skipfrwd amount in seconds
skipByMore=30
# "exact" (mordenx default) or "relative+keyframes" (mpv default)
skipMode=exact
# PictureInPicture 33% screen width, 10px from bottom right
pipGeometry=33%+-10+-10
# PictureInPicture will show video on all virtual desktops
pipAllWorkspaces=yes

### Sizes
# 16:9 video thumbnail = 256x144
thumbnailSize=256
seekbarHeight=20
controlsHeight=64
buttonTooltipSize=20
windowBarHeight=44
windowButtonSize=44
windowTitleSize=24
cacheTextSize=20
timecodeSize=27
seekbarTimestampSize=30
seekbarTimestampOutline=1
chapterTickSize=6
windowTitleOutline=1

### Colors (uses GGBBRR for some reason)
### Alpha ranges 0 (opaque) .. 255 (transparent)
textColor=FFFFFF
buttonColor=CCCCCC
buttonHoveredColor=FFFFFF
buttonHoveredRectColor=000000
# Easily debug button geometry by setting buttonHoveredRectAlpha to 80
buttonHoveredRectAlpha=255
tooltipColor=CCCCCC
windowBarColor=000000
# windowBarAlpha (80 is mpv default) (255 morden default)
windowBarAlpha=255
windowButtonColor=CCCCCC
closeButtonHoveredColor=1111DD
seekbarHandleColor=FFFFFF
seekbarFgColor=483DD7
seekbarBgColor=929292
seekbarCacheColor=000000
seekbarCacheAlpha=128
chapterTickColor=CCCCCC
```

#### osc.conf

A complete list of configuration keys inherited from `osc.lua` can [be found in the source code](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua) or [its documentation](https://mpv.io/manual/master/#configurable-options).

Note that tethys ignores a few options in `osc.conf` that are already covered by `tethys.conf`.

* Windows: `%APPDATA%\mpv\script-opts\osc.conf`
* Linux: `~/.config/mpv/script-opts/osc.conf`

```ini
# Timestamp
# Display total time instead of remaining time
timetotal=no
# Display timecodes with milliseconds
timems=no

# Whether to display the chapters/playlist at the OSD when left-clicking the next/previous OSC buttons, respectively.
playlist_osd=yes
chapters_osd=yes

# Duration of fade out in ms, 0 = no fade
fadeduration=200

# Minimum amount of pixels the mouse has to move between ticks to make the OSC show up. Default pre-0.21.0 was 3.
minmousemove=0

# auto=hide/show on mouse move
# Also supports never and always
visibility=auto

# Use a Unicode minus sign instead of an ASCII hyphen when displaying the remaining playback time.
unicodeminus=no
```

#### mpv_thumbnail_script.conf

A complete list of configuration keys for mpv_thumbnail_script can [be found in the source code](https://github.com/TheAMM/mpv_thumbnail_script/blob/master/src/options.lua) or [its documentation](https://github.com/TheAMM/mpv_thumbnail_script#configuration).

Note that `thumbnailSize` in `tethys.conf` overrides `thumbnail_width` and `thumbnail_height`. Tethys also forces `mpv_no_sub=yes` and `mpv_no_config=yes` to make thumbnails easier to read.

* Windows: `%APPDATA%\mpv\script-opts\mpv_thumbnail_script.conf`
* Linux: `~/.config/mpv/script-opts/mpv_thumbnail_script.conf`

```ini
# Automatically generate the thumbnails on video load, without a keypress
autogenerate=yes

# 1 hour, Only automatically thumbnail videos shorter than this (seconds)
autogenerate_max_duration=3600

# SHA1-sum filenames over this length
# It's nice to know what files the thumbnails are (hence directory names)
# but long URLs may approach filesystem limits.
hash_filename_length=128

# Use mpv to generate thumbnail even if ffmpeg is found in PATH
# ffmpeg does not handle ordered chapters (MKVs which rely on other MKVs)!
# mpv is a bit slower, but has better support overall (eg. subtitles in the previews)
prefer_mpv=yes

# Disable the built-in keybind ("T") to add your own
disable_keybinds=no

# The thumbnail count target
# (This will result in a thumbnail every ~10 seconds for a 25 minute video)
thumbnail_count=150

# The above target count will be adjusted by the minimum and
# maximum time difference between thumbnails.
# The thumbnail_count will be used to calculate a target separation,
# and min/max_delta will be used to constrict it.

# In other words, thumbnails will be:
#   at least min_delta seconds apart (limiting the amount)
#   at most max_delta seconds apart (raising the amount if needed)
min_delta=5
# 120 seconds aka 2 minutes will add more thumbnails when the video is over 5 hours!
max_delta=90


# Overrides for remote urls (you generally want less thumbnails!)
# Thumbnailing network paths will be done with mpv

# Allow thumbnailing network paths (naive check for "://")
thumbnail_network=no
# Override thumbnail count, min/max delta
remote_thumbnail_count=60
remote_min_delta=15
remote_max_delta=120

# Try to grab the raw stream and disable ytdl for the mpv subcalls
# Much faster than passing the url to ytdl again, but may cause problems with some sites
remote_direct_stream=yes
```

#### autoload.lua

* Windows: `%APPDATA%\mpv\script-opts\autoload.conf`
* Linux: `~/.config/mpv/script-opts/autoload.conf`

```ini
disabled=no
images=yes
videos=yes
audio=yes
ignore_hidden=yes
```

## Notes

* https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua
* https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua
* https://github.com/Zren/mpvz/issues/13 (`osc_tethys.lua` Development Notes)
* https://github.com/mpv-player/mpv/blob/master/player/lua/assdraw.lua
* https://github.com/mpv-player/mpv/blob/master/sub/osd.c
* https://github.com/libass/libass/wiki/ASSv5-Override-Tags
* https://github.com/libass/libass/wiki/Libass'-ASS-Extensions
* https://mpv.io/manual/master/
* https://bomi-player.github.io/gallery.html (Tethys icon set designed by Kotus Works)

## Other Themes

I haven't tried these, but have used them as reference.

* https://github.com/cyl0/MordenX
* https://github.com/maoiscat/mpv-osc-morden
* https://github.com/maoiscat/mpv-light-box
* https://github.com/TheAMM/mpv_thumbnail_script
* https://github.com/darsain/uosc
