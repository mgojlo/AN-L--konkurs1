Source code for NIFS3 (natural cubic splines) editor written in Zig + Raylib for the Numerical Analysis course @ II UWr

Usage:
 - `left mouse button` : move NIFS3 control point
 - `right mouse button` : select NIFS3 control point without moving it
 - `right mouse button + m` : move the whole NIFS3 (must be moved using a control point, mouse scaling is a bit off)
 - `l` : load NIFS3 from save file
 - `s` : save NIFS3 to save file
 - `e` : export to competition format
 - `left`, `right`, `up`, `down`, `space+mouse move`, `middle mouse button+mouse move` : move view
 - `=` : increase line thickness
 - `-` : decrease line thickness
 - escape : deselect point
 - `r` : reset dt ("weight") of the segment after the selected point
 - `a` : add point
 - `d` : delete point
 - `g` : increase the number of `us` of the segment after the selected point
 - `shift+g` : decrease the number of `us` of the segment after the selected point
 - `n` : add new NIFS3
