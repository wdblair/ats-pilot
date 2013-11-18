(*
  Rendering the control panel
*)

#define ATS_DYNLOADFLAG 0

#include "share/atspre_staload.hats"

staload "net.sats"
staload "container.sats"

staload _ = "container.dats"

%{^
#include <termbox.h>
%}

abst@ype plant (tk:tkind) = @{
  id= char,
  label= string
}

assume plant (tk:tkind) = @{
  id= [c:nat | c < 256] char c,
  label= string
}

extern
fun {tk:tkind}
get_sensor (&FGNetFDM): double


extern
fun draw_text_c {n:int} (
  x: int, y: int, text: &(@[char][n]), fg: int, bg: int
): void = "ext#"

extern
fun draw_text_c_string (
  x: int, y: int, text: string, fg: int, bg: int
): void = "mac#draw_text_c"

extern
fun tm_change_cell (x: int, y: int, ch: char, fg: int, bg: int): void = "ext#"

extern
fun draw_table (
  width: int, height: int, y: int, targets: &(container (double)), sensors: &FGNetFDM
): void = "ext#"

val TB_DEFAULT = $extval(int, "TB_DEFAULT")

fun {tk:tkind} 
draw_row (p: plant(tk), y:int, targets: &(container (double)), sensors: &FGNetFDM): void = let
  var buf = @[char][128]('\0')
  val label = p.label
  val id = p.id
  val target = targets[id]
  val sensor = get_sensor<tk> (sensors)
  val error = target - sensor
  val _ = $extfcall (int, 
    "snprintf", buf, 128, "|%-8s|%8.2f|%8.2f|%8.2f|", label, target, sensor, error
  )
in
  draw_text_c (0, y, buf, TB_DEFAULT, TB_DEFAULT)
end

stacst roll  : tkind
stacst pitch : tkind

implement get_sensor<roll> (sensors) = sensors.phi
implement get_sensor<pitch> (sensors) = sensors.theta

implement draw_table (w, h, y, targets, sensors) = let
  // TODO: Turn this into a list
  val roll = @{
    id= 'r',
    label= "Roll"
  }
  
  val pitch = @{
    id= 'p',
    label= "Pitch"
  }
  
  var buf = @[char][128]('\0')
  val _ = $extfcall (void,
    "snprintf", buf, 128, "|%-8s|%8s|%8s|%8s|", "Plant", "Target", "Current", "Error"
  );
  
  fun draw_separator (y: int, buffer: &(@[char][128])): void = let
  in
    draw_text_c_string (0, y, "|++++++++|++++++++|++++++++|++++++++|", TB_DEFAULT, TB_DEFAULT)
  end
  
in
  draw_text_c (0, y, buf, TB_DEFAULT, TB_DEFAULT); (* Heading *)
  draw_separator (y+1, buf);
  draw_row<roll> (roll, y+2, targets, sensors);
  draw_separator (y+3, buf);
  draw_row<pitch> (pitch, y+4, targets, sensors)
end