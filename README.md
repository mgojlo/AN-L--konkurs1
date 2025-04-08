Source code for NIFS3 (natural cubic splines) editor written in Zig + Raylib for the Numerical Analysis course @ II UWr

# Setup, dependencies

Easiest is using the provided [Nix](https://nixos.org/download/) shell in `shell.nix`. Just type [`nix-shell`](https://nix.dev/manual/nix/2.18/command-ref/nix-shell) in your prompt once you have Nix installed.

# Building

`zig build`

# Running

`zig build run` or `./zig-out/bin/konkurs1`

# Switching input image

The program loads the hardcoded path `pwo++.png`, but you can replace that image with another - the dimensions of the export area are determined dynamically based on the size of the input image.

# Usage
 - `left mouse button` : move NIFS3 control point
 - `right mouse button` : select NIFS3 control point without moving it
 - `right mouse button + m` : move the whole NIFS3 (must be moved using a control point, mouse scaling is a bit off)
 - `l` : load NIFS3 from save file
 - `s` : save NIFS3 to save file
 - `e` : export to competition format
 - `left`, `right`, `up`, `down`, `space+mouse move`, `middle mouse button+mouse move` : move view
 - `=` : increase line thickness
 - `-` : decrease line thickness
 - `escape` : deselect point
 - `r` : reset dt ("weight") of the segment after the selected point
 - `a` : add point
 - `d` : delete point
 - `g` : increase the number of `us` of the segment after the selected point
 - `shift+g` : decrease the number of `us` of the segment after the selected point
 - `n` : add new NIFS3
