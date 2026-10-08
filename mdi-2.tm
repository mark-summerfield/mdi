# Copyright © 2026 Mark Summerfield. All rights reserved.

# Mouse bindings:
# - Click title or top frame to raise
# - Shift-Click title or top frame to lower
# - Click+Drag title or top frame to move
# - Click+Drag outer frame to resize
# - In Move Mode arrows move by 10 pixels
# - In Resize Mode arrows resize by 10 pixels
# - Double-click when Minimized to Restore

namespace eval mdi {
    variable Initialized 0
    variable TitleActiveTextColor black
    variable TitleInactiveTextColor grey
}

proc mdi::initialize {} {
    ttk::style configure Mdi.TFrame -background #F0F0F0 -relief sunken
    ttk::style configure MdiActive.TFrame -background #B0B0B0 -relief sunken
    ttk::style configure MdiInactive.TFrame -relief sunken \
            -background [ttk::style lookup TFrame -background]
    set ::mdi::Initialized 1
}

oo::class create mdi::Window {
    variable Frame      ;# e.g., .mainframe.mdiwindow
    variable Children   ;# list of mdi::child objects
    variable Menu
}

oo::define mdi::Window initialize {
    variable C 0
    variable Column 0
    variable X 0
    variable Y 0
}

oo::define mdi::Window constructor name {
    if {!$::mdi::Initialized} { mdi::initialize }
    set Frame [ttk::frame $name -style Mdi.TFrame]
    set Children [list]
    set Menu ""
}

oo::define mdi::Window destructor {
    foreach child $Children {
        if {[catch { $child on_close ; $child destroy }]} {
            my close_child $child
        }
    }
    destroy $Frame
}

oo::define mdi::Window method frame {} { return $Frame }

oo::define mdi::Window method children {} {
    set children [list]
    foreach child $Children {
        if {[$child is_visible]} { lappend children $child }
    }
    return $children
}

oo::define mdi::Window method hidden_children {} {
    set children [list]
    foreach child $Children {
        if {[$child is_hidden]} { lappend children $child }
    }
    return $children
}

oo::define mdi::Window method size {} {
    list [winfo width $Frame] [winfo height $Frame]
}

oo::define mdi::Window method set_background_color color {
    ttk::style configure Mdi.TFrame -background $color -relief sunken
}

oo::define mdi::Window method set_active_child_frame_color color {
    ttk::style configure MdiActive.TFrame -background $color -relief sunken
}

oo::define mdi::Window method set_inactive_child_frame_color color {
    ttk::style configure MdiInactive.TFrame -background $color \
            -relief sunken
}

oo::define mdi::Window method set_active_child_title_color color {
    set ::mdi::TitleActiveTextColor $color
}

oo::define mdi::Window method set_inactive_child_title_color color {
    set ::mdi::TitleInactiveTextColor $color
}

oo::define mdi::Window method cascade {} {
    set height [winfo height $Frame]
    set column 0
    set inc 0
    set x 0
    set y 0
    set active [my active_child]
    foreach child [my children] {
        if {[info object isa object $child]} {
            if {!$inc} {
                set inc [expr {int(round(11 * [tk scaling])) + \
                        [font metrics TkDefaultFont \
                        -displayof [$child frame].top -linespace]}]
            }
            $child on_restore
            set window [$child frame]
            if {$y + (2 * $inc) >= $height} {
                set x [expr {[incr column] * 4 * $inc}]
                set y 0
            }
            lassign [$child size] child_width child_height
            lassign [$child min_size] min_width min_height
            if {$child_width < $min_width || $child_height < $min_height} {
                lassign [$child restore_size] child_width child_height
                place configure $window -x $x -y $y -width $child_width \
                        -height $child_height
            } else {
                place configure $window -x $x -y $y
            }
            raise $window
            incr x $inc
            incr y $inc
        }
    }
    if {$active ne ""} { $active on_raise }
}

oo::define mdi::Window method tile {} {
    set children [my children] ;# filters out closed & hidden
    set size [llength $children]
    if {$size == 0} {
        ;# none to tile
    } elseif {$size == 1} {
        [lindex $children 0] on_maximize
    } elseif {$size < 37} {
        set active [my active_child]
        if {$active eq ""} { set active [lindex $children 0] }
        lassign [$active min_size] min_width min_height
        set width [winfo width $Frame]
        set height [winfo height $Frame]
        set wide [expr {$width > $height}]
        my tile_many $width $height $min_width $min_height $wide $children \
                $size
        $active on_raise
    } else {
        event generate $Frame <<MdiTileError>> \
                -data "too many child windows to tile"
    }
}

oo::define mdi::Window method tile_many {width height min_width min_height \
        wide children size} {
    lassign [my tile_get_rows_columns $wide $size] rows columns
    set cwidth [expr {int(floor($width / ($columns * 1.0)))}]
    set cheight [expr {int(floor($height / ($rows * 1.0)))}]
    if {$cwidth < $min_width || $cheight < $min_height} {
        event generate $Frame <<MdiTileError>> \
                -data "insufficient space to tile"
    } else {
        foreach row [lseq $rows] {
            foreach column [lseq $columns] {
                if {![llength $children]} return
                set child [lpop children]
                set x [expr {$column * $cwidth}]
                set y [expr {$row * $cheight}]
                $child set_geometry $x $y $cwidth $cheight
            }
        }
    }
}

oo::define mdi::Window method tile_get_rows_columns {wide size} {
    switch $size {
       4 - 7 - 8 - 9 - 13 - 14 - 15 - 16 - 21 - 22 - 23 - 24 - 25 - \
           31 - 32 - 33 - 34 - 35 - 36 {
            set rows [expr {int(ceil(sqrt($size)))}]
            set columns $rows
       }
       2 {
           if {$wide} {
               set rows 1
               set columns 2
           } else {
               set rows 2
               set columns 1
           }
       }
       3 {
           if {$wide} {
               set rows 1
               set columns 3
           } else {
               set rows 3
               set columns 1
           }
       }
       5 - 6 {
           if {$wide} {
               set rows 2
               set columns 3
           } else {
               set rows 3
               set columns 2
           }
       }
       10 - 11 - 12 {
           if {$wide} {
               set rows 3
               set columns 4
           } else {
               set rows 4
               set columns 3
           }
       }
       17 - 18 - 19 - 20 {
           if {$wide} {
               set rows 4
               set columns 5
           } else {
               set rows 5
               set columns 4
           }
       }
       26 - 27 - 28 - 29 - 30 {
           if {$wide} {
               set rows 5
               set columns 6
           } else {
               set rows 6
               set columns 5
           }
       }
    }
    list $rows $columns
}

oo::define mdi::Window method minimize_all {} {
    foreach child [my children] { $child on_minimize }
}

oo::define mdi::Window method active_child {} {
    if {[set area [focus -lastfor $Frame]] ne ""} {
        foreach child [my children] {
            if {[string match [$child frame]* $area]} {
                return $child
            }
        }
    }
}

oo::define mdi::Window method make_child_visible child {
    set move 0
    if {[$child is_minimized]} { $child on_restore }
    lassign [$child geometry] x y width height
    lassign [my size] win_width win_height
    if {$x + (0.75 * $width) > $win_width} { set move 1 }
    if {$y + (0.75 * $height) > $win_height} { set move 1 }
    if {$move} {
        set x [expr {int(round(($win_width / 2) - ($width / 2.0)))}]
        set y [expr {int(round(($win_height / 2) - ($height / 2.0)))}]
        place [$child frame] -x $x -y $y
    }
    $child on_raise
}

oo::define mdi::Window method new_child {{title ""} {userdata {}} \
        {geometry {}} {closable 1}} {
    classvariable C
    classvariable Column
    classvariable X
    classvariable Y
    set win_height [winfo height $Frame]
    set name $Frame.child[incr C]
    set child [mdi::child new [self] $name $userdata $closable]
    lappend Children $child
    if {$geometry eq {}} {
        set width [expr {140 * [tk scaling]}] 
        set height [expr {100 * [tk scaling]}]
        set inc [expr {int(round(11 * [tk scaling])) + \
                [font metrics TkDefaultFont -displayof [$child frame].top \
                -linespace]}]
        if {$Y + (0.5 * $height) > $win_height} {
            set X [expr {int(round([incr Column] * 0.5 * $width))}]
            set Y 0
        }
        set x [incr X $inc]
        set y [incr Y $inc]
    } else {
        lassign $geometry x y width height
    }
    $child set_geometry $x $y $width $height
    $child set_title [expr {$title ne "" ? $title : "Window #$C"}]
    my repopulate_window_menu
    return $child
}

oo::define mdi::Window method close_child child {
    if {[set i [lsearch -exact $Children $child]] != -1} {
        catch { $child on_close }
        set Children [lremove $Children $i]
    }
}

oo::define mdi::Window method new_window_menu {parent_menu \
        {options {cascade tile minimize_all maximize minimize restore \
                  move resize close windows}}} {
    if {$Menu ne ""} return
    set n 0
    set Menu $parent_menu._window
    menu $Menu
    $parent_menu add cascade -menu $Menu -label Window -underline 0
    if {"cascade" in $options} {
        $Menu add command -label "⧉ Cascade" -underline 2 \
                -command [callback cascade]
        incr n
    }
    if {"tile" in $options} {
        $Menu add command -label "⊞ Tile" -underline 2 \
                -command [callback tile]
        incr n
    }
    if {"minimize_all" in $options} {
        $Menu add command -label "\U0001F5D5 Minimize All" -underline 11 \
                -command [callback minimize_all]
        incr n
    }
    if {$n} {
        $Menu add separator
        set n 0
    }
    if {"maximize" in $options} {
        $Menu add command -label "\U0001F5D6 Maximize" -underline 4 \
                -command [callback on_maximize_child]
        incr n
    }
    if {"minimize" in $options} {
        $Menu add command -label "\U0001F5D5 Minimize" -underline 4 \
                -command [callback on_minimize_child]
        incr n
    }
    if {"restore" in $options} {
        $Menu add command -label "⮔ Restore" -underline 2 \
                -command [callback on_restore_child]
        incr n
    }
    if {$n} {
        $Menu add separator
        set n 0
    }
    if {"move" in $options} {
        $Menu add command -label "↔ Move" -underline 2 \
                -command [callback on_move_mode_child]
        incr n
    }
    if {"resize" in $options} {
        $Menu add command -label "⇲ Resize" -underline 6 \
                -command [callback on_resize_mode_child]
        incr n
    }
    if {"close" in $options} {
        if {$n} { $Menu add separator }
        $Menu add command -label "× Close" -underline 3 \
                -command [callback on_close_child]
        incr n
    }
    if {"windows" in $options} {
        if {$n} { $Menu add separator }
        menu $Menu.windows
        $Menu add cascade -menu $Menu.windows -label Windows -underline 0
        my repopulate_window_menu
    }
}

oo::define mdi::Window method repopulate_window_menu {} {
    if {$Menu eq ""} return
    $Menu.windows delete 0 end
    set accels [lreverse [split 123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ ""]]
    foreach child [my children] {
        set title [$child title]
        set ul {}
        if {[llength $accels]} {
            set ul 2
            set title "[lpop accels] $title"
        }
        $Menu.windows add command -label "❏ $title" -underline $ul \
                -command [callback make_child_visible $child]
    }
}

oo::define mdi::Window method on_maximize_child {} {
    if {[set child [my active_child]] ne ""} { $child on_maximize }
}

oo::define mdi::Window method on_minimize_child {} {
    if {[set child [my active_child]] ne ""} { $child on_minimize }
}

oo::define mdi::Window method on_restore_child {} {
    if {[set child [my active_child]] ne ""} { $child on_restore }
}

oo::define mdi::Window method on_move_mode_child {} {
    if {[set child [my active_child]] ne ""} { $child on_move_mode }
}

oo::define mdi::Window method on_resize_mode_child {} {
    if {[set child [my active_child]] ne ""} { $child on_resize_mode }
}

oo::define mdi::Window method on_close_child {} {
    if {[set child [my active_child]] ne ""} { $child on_close_if_closable }
}

# $Frame             ttk::frame for child window
# $Frame.top         ttk::frame for child window's title & buttons
# $Frame.top.label   ttk::label for child window's title label
# $Frame.body        ttk::frame for the user to populate
oo::class create mdi::child {
    variable Parent
    variable Frame
    variable X
    variable Y
    variable Closable
    variable Moving
    variable Resizing
    variable Mode ;# -2 → hidden|-1 → closed|0 → normal|1 → move|2 → resize
    variable Menu
    variable Minimized
    variable Geometry ;# list of x y width height
    variable UserData ;# e.g., to help with saving/loading window content
}

# parent: the mdi::Window to which this belongs
# name: the name of the window, e.g., .mainframe.mdiwindow
# closeable: whether there should be a close button or not
oo::define mdi::child constructor {parent name {userdata {}} {closable 1}} {
    set Parent $parent
    set Frame $name
    set X 0
    set Y 0
    set UserData $userdata
    set Closable $closable
    set Moving 0
    set Resizing 0
    set Mode 0
    set Minimized 0
    set Geometry {0 0 120 120}
    my MakeWidgets
    my MakeLayout
    my MakeMenu
    my MakeBindings
    my on_lost_focus
}

oo::define mdi::child method userdata {} { return $UserData }
oo::define mdi::child method set_userdata userdata {
    set UserData $userdata
}

oo::define mdi::child method MakeWidgets {} {
    ttk::frame $Frame -borderwidth 4 -relief raised
    ttk::frame $Frame.top
    ttk::button $Frame.top.menu -style Toolbutton -text ≣ \
            -command [callback on_menu]
    ttk::label $Frame.top.label
    ttk::button $Frame.top.maximize -style Toolbutton -text "\U0001F5D6" \
            -command [callback on_maximize]
    ttk::button $Frame.top.minimize -style Toolbutton -text "\U0001F5D5" \
            -command [callback on_minimize]
    if {$Closable} {
        ttk::button $Frame.top.close -style Toolbutton -text × \
                -command [callback on_close]
    }
    ttk::frame $Frame.body
}

oo::define mdi::child method MakeLayout {} {
    const opts "-padx 2 -pady 2"
    pack $Frame.top -fill x -side top {*}$opts
    set width [winfo reqwidth $Frame.top.menu]
    grid $Frame.top.menu -row 0 -column 0 -sticky w {*}$opts
    grid $Frame.top.label -row 0 -column 1 -sticky w {*}$opts
    grid $Frame.top.maximize -row 0 -column 2 -sticky e {*}$opts
    grid $Frame.top.minimize -row 0 -column 3 -sticky e {*}$opts
    set columns 3
    if {$Closable} {
        grid $Frame.top.close -row 0 -column 4 -sticky e {*}$opts
        incr columns
    }
    foreach column [lseq $columns] {
        if {$column != 1} {
            grid columnconfigure $Frame.top $column -minsize $width
        }
    }
    grid columnconfigure $Frame.top 1 -weight 1
    pack $Frame.body -fill both -expand 1 {*}$opts
    pack $Frame -fill both -expand 1 -side bottom
}

oo::define mdi::child method MakeMenu {} {
    set Menu [menu $Frame.menu]
    $Menu add command -command [callback on_maximize] \
            -label "\U0001F5D6 Maximize" -underline 4
    $Menu add command -command [callback on_minimize] \
            -label "\U0001F5D5 Minimize" -underline 4
    $Menu add command -command [callback on_restore] \
            -label "⮔ Restore" -underline 2
    $Menu add separator
    $Menu add command -command [callback on_move_mode] \
            -label "↔ Move" -underline 2
    $Menu add command -command [callback on_resize_mode] \
            -label "⇲ Resize" -underline 6
    if {$Closable} {
        $Menu add separator
        $Menu add command -command [callback on_close] -label "× Close" \
                -underline 2
    }
}

oo::define mdi::child method MakeBindings {} {
    foreach widget [list $Frame.top $Frame.top.label] {
        bind $widget <Double-Button-1> [callback on_label_dbl_click]
        bind $widget <Button-1> [callback on_start_move %X %Y]
        bind $widget <Shift-Button-1> [callback on_lower]
        bind $widget <Motion> [callback on_move %X %Y]
        bind $widget <ButtonRelease-1> [callback on_move_end]
    }
    bind $Frame <Button-1> [callback on_start_resize %X %Y]
    bind $Frame <Motion> [callback on_resize %X %Y]
    bind $Frame <ButtonRelease-1> [callback on_resize_end]
    bind $Frame <Escape> [callback on_clear_mode]
    bind $Frame <Left> [callback on_left_arrow]
    bind $Frame <Right> [callback on_right_arrow]
    bind $Frame <Up> [callback on_up_arrow]
    bind $Frame <Down> [callback on_down_arrow]
    bind $Frame <FocusIn> [callback on_got_focus]
    bind $Frame <FocusOut> [callback on_lost_focus]
}

oo::define mdi::child destructor {
    $Parent close_child [self]
    destroy $Frame
}

oo::define mdi::child method frame {} { return $Frame }
oo::define mdi::child method body {} { return $Frame.body }

oo::define mdi::child method title {} { $Frame.top.label cget -text }
oo::define mdi::child method set_title title {
    if {$title ne ""} { $Frame.top.label configure -text $title }
}

oo::define mdi::child method is_closed {} { expr {$Mode == -1} }
oo::define mdi::child method is_closable {} { return $Closable }
oo::define mdi::child method is_hidden {} { expr {$Mode == -2} }
oo::define mdi::child method is_visible {} { expr {$Mode >= 0} }
oo::define mdi::child method is_minimized {} { return $Minimized }

oo::define mdi::child method set_geometry {x y width height} {
    place $Frame -x $x -y $y -width $width -height $height
    set Geometry [list $x $y $width $height]
}

oo::define mdi::child method on_menu {} {
    raise $Frame
    focus $Frame
    set x [expr {int(round(10 * [tk scaling]) + [winfo pointerx $Frame])}]
    set y [expr {int(round(10 * [tk scaling]) + [winfo pointery $Frame])}]
    tk_popup $Menu $x $y
}

oo::define mdi::child method on_maximize {} {
    set Geometry [list [winfo x $Frame] [winfo y $Frame] \
            [winfo width $Frame] [winfo height $Frame]]
    lassign [$Parent size] win_width win_height
    set has_minimized 0
    foreach child [$Parent children] {
        if {[$child is_minimized] && $child ne [self]} {
            set has_minimized 1
            break
        }
    }
    if {$has_minimized} {
        set win_height [expr {$win_height - \
                (2 * [font metrics TkDefaultFont -linespace])}]
    }
    place configure $Frame -x 0 -y 0 -width $win_width -height $win_height
    raise $Frame
    set Minimized 0
}

oo::define mdi::child method on_minimize {} {
    set Geometry [list [winfo x $Frame] [winfo y $Frame] \
            [winfo width $Frame] [winfo height $Frame]]
    lassign [$Parent size] win_width win_height
    set height [winfo reqheight $Frame.top.label]
    incr height [font metrics TkDefaultFont -linespace]
    set width [expr {7 * [winfo reqwidth $Frame.top.menu]}]
    set y [expr {$win_height - $height}]
    set x 0
    set children [$Parent children]
    foreach child $children i [lseq [llength $children]] {
        if {$child eq [self]} {
            set x [expr {($i % int(round(($win_width + ($width * 0.2)) / \
                    $width))) * $width}]
            break
        }
    }
    place configure $Frame -x $x -y $y -width $width -height $height
    set Minimized 1
    foreach child [$Parent children] {
        if {![$child is_minimized]} {
            focus [$child frame]
            raise [$child frame]
            break
        }
    }
}

oo::define mdi::child method on_restore {} {
    set Minimized 0
    my set_geometry {*}$Geometry
}

oo::define mdi::child method on_clear_mode {} {
    set Mode 0
    $Frame configure -cursor arrow
}

oo::define mdi::child method on_move_mode {} {
    my on_raise
    set Mode 1
    $Frame configure -cursor fleur
}

oo::define mdi::child method on_resize_mode {} {
    my on_raise
    set Mode 2
    $Frame configure -cursor sizing
}

oo::define mdi::child method on_left_arrow {} {
    if {$Mode >= 0} { set Minimized 0 }
    if {$Mode == 1} {
        set x [lindex [place configure $Frame -x] end]
        place configure $Frame -x [expr {max(0, $x - 5)}] 
    } elseif {$Mode == 2} {
        set width [lindex [place configure $Frame -width] end]
        set min_width [lindex [my min_size] 0]
        place configure $Frame -width [expr {max($min_width, $width - 5)}] 
    }
}

oo::define mdi::child method on_right_arrow {} {
    if {$Mode >= 0} { set Minimized 0 }
    if {$Mode == 1} {
        set x [lindex [place configure $Frame -x] end]
        place configure $Frame -x [expr {$x + 5}]
    } elseif {$Mode == 2} {
        set width [lindex [place configure $Frame -width] end]
        place configure $Frame -width [expr {$width + 5}] 
    }
}

oo::define mdi::child method on_up_arrow {} {
    if {$Mode >= 0} { set Minimized 0 }
    if {$Mode == 1} {
        set y [lindex [place configure $Frame -y] end]
        place configure $Frame -y [expr {max(0, $y - 5)}] 
    } elseif {$Mode == 2} {
        set height [lindex [place configure $Frame -height] end]
        set min_height [lindex [my min_size] 1]
        place configure $Frame \
            -height [expr {max($min_height, $height - 5)}] 
    }
}

oo::define mdi::child method on_down_arrow {} {
    if {$Mode >= 0} { set Minimized 0 }
    if {$Mode == 1} {
        set y [lindex [place configure $Frame -y] end]
        place configure $Frame -y [expr {$y + 5}] 
    } elseif {$Mode == 2} {
        set height [lindex [place configure $Frame -height] end]
        place configure $Frame -height [expr {$height + 5}] 
    }
}

oo::define mdi::child method on_close_if_closable {} {
    if {$Closable} { my on_close }
}

oo::define mdi::child method on_close {} {
    if {$Mode != -1} {
        set Mode -1
        place forget $Frame
        event generate $Frame <<MdiChildClose>> -data [self]
        $Parent repopulate_window_menu
    }
}

# This method is for programmatic use not for the UI per se.
oo::define mdi::child method on_hide {} {
    set Geometry [list [winfo x $Frame] [winfo y $Frame] \
            [winfo width $Frame] [winfo height $Frame]]
    set Mode -2
    place forget $Frame
    event generate $Frame <<MdiChildHide>> -data [self]
    $Parent repopulate_window_menu
}

# This method is for programmatic use not for the UI per se.
oo::define mdi::child method on_show {} {
    set Mode 0
    my on_restore
    my on_raise
    event generate $Frame <<MdiChildUnhide>> -data [self]
    $Parent repopulate_window_menu
}

oo::define mdi::child method on_lower {} { lower $Frame }

oo::define mdi::child method on_raise {} {
    raise $Frame
    focus $Frame
}

oo::define mdi::child method on_start_move {{x -1} {y -1}} {
    my on_raise
    if {$x > -1 && $y > -1} {
        set Mode 0
        set Moving 1
        set X $x
        set Y $y
        $Frame configure -cursor fleur
    }
}

oo::define mdi::child method on_move {{x -1} {y -1}} {
    if {$Moving && $x > -1 && $y > -1} {
        set old_x $X
        set old_y $Y
        set X $x
        set Y $y
        set dx [expr {$X - $old_x}]
        set dy [expr {$Y - $old_y}]
        place configure $Frame \
                -x [expr {[lindex [place configure $Frame -x] end] + $dx}] \
                -y [expr {[lindex [place configure $Frame -y] end] + $dy}]
    }
}

oo::define mdi::child method on_move_end {} {
    set Moving 0
    $Frame configure -cursor arrow
}

oo::define mdi::child method on_start_resize {{x -1} {y -1}} {
    my on_raise
    if {$x > -1 && $y > -1} {
        set Mode 0
        set Resizing 1
        set X $x
        set Y $y
        $Frame configure -cursor sizing
    }
}

oo::define mdi::child method on_resize {{x -1} {y -1}} {
    if {$Resizing && $x > -1 && $y > -1} {
        set width [lindex [place configure $Frame -width] end]
        set height [lindex [place configure $Frame -height] end]
        set dx [expr {$x - $X}]
        set dy [expr {$y - $Y}]
        set X $x
        set Y $y
        lassign [my min_size] min_width min_height
        set width [expr {max($min_width, $width + $dx)}]
        set height [expr {max($min_height, $height + $dy)}]
        place configure $Frame -width $width -height $height
    }
}

oo::define mdi::child method on_resize_end {} {
    set Resizing 0
    $Frame configure -cursor arrow
}

oo::define mdi::child method on_got_focus {} {
    $Frame configure -style MdiActive.TFrame
    $Frame.top.label configure -foreground $::mdi::TitleActiveTextColor
}

oo::define mdi::child method on_lost_focus {} {
    $Frame configure -style MdiInactive.TFrame
    $Frame.top.label configure -foreground $::mdi::TitleInactiveTextColor
}

oo::define mdi::child method on_label_dbl_click {} {
    if {$Minimized} { my on_restore }
}

oo::define mdi::child method min_size {} {
    list [expr {7 * [winfo reqwidth $Frame.top.menu]}] \
         [expr {5 * [font metrics TkDefaultFont -linespace]}]
}

oo::define mdi::child method size {} {
    list [winfo width $Frame] [winfo height $Frame]
}

oo::define mdi::child method restore_size {} { lrange $Geometry end-1 end }

oo::define mdi::child method geometry {} {
    list [winfo x $Frame] [winfo y $Frame] [winfo width $Frame] \
            [winfo height $Frame]
}
