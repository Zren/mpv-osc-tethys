# mpv-osc-tethys

This theme replaces [the built in `osc.lua`](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua) shipped with [mpv](https://github.com/mpv-player/mpv).

![](https://i.imgur.com/cYqWlw5.png)

Local files can show thumbnail previews (without [mpv_thumbnail_script](https://github.com/TheAMM/mpv_thumbnail_script)).

![](https://i.imgur.com/FegXl3W.png)

Picture-In-Picture button to position in the corner, on top of other windows, and on all virtual desktops.

![](https://i.imgur.com/Ynlog81.png)

### Install

(1) Copy `osc_tethys.lua` and mpv's `autoload.lua` to

* Linux: `~/.config/mpv/scripts/`
* Windows: `%APPDATA%\mpv\scripts\` (`C:\Users\USER\AppData\Roaming\mpv\scripts\`)

```sh
mkdir -p ~/.config/mpv/scripts/
cd ~/.config/mpv/scripts/
wget https://raw.githubusercontent.com/Zren/mpv-osc-tethys/master/osc_tethys.lua
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
```

### Notes

* https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua
* https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua
* https://github.com/Zren/mpvz/issues/13 (Theme Development Notes)
* https://github.com/mpv-player/mpv/blob/master/player/lua/assdraw.lua
* https://github.com/mpv-player/mpv/blob/master/sub/osd.c
* https://github.com/libass/libass/wiki/ASSv5-Override-Tags
* https://github.com/libass/libass/wiki/Libass'-ASS-Extensions
* https://mpv.io/manual/master/
* https://bomi-player.github.io/gallery.html (Tethys icon set designed by Kotus Works)

### Other Themes

I haven't tried these, but have used them as reference.

* https://github.com/cyl0/MordenX
* https://github.com/maoiscat/mpv-osc-morden
* https://github.com/maoiscat/mpv-light-box
* https://github.com/TheAMM/mpv_thumbnail_script
* https://github.com/darsain/uosc
