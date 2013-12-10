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
fun {tk:tkind}
get_actuator (&FGNetCtrls): double

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
  width: int, height: int, y: int, targets: &(container (double)), 
  sensors: &FGNetFDM, actuators: &FGNetCtrls
): void = "ext#"

val TB_DEFAULT = $extval(int, "TB_DEFAULT")

fun {tk:tkind} 
draw_row (
  p: plant(tk), y:int, targets: &(container (double)),  sensors: &FGNetFDM, actuators: &FGNetCtrls
): void = let
  var buf = @[char][128]('\0')
  val label = p.label
  val id = p.id
  val target = targets[id]
  val sensor = get_sensor<tk> (sensors)
  val error = target - sensor
  val output = get_actuator<tk> (actuators)
  val () = $extfcall (void, 
    "snprintf", buf, 128, "|%-8s|%8.2f|%8.2f|%8.2f|%8.2f|", label, target, sensor, error, output
  )
in
  draw_text_c (0, y, buf, TB_DEFAULT, TB_DEFAULT)
end

stacst roll  : tkind
stacst pitch : tkind
stacst yaw   : tkind

implement get_sensor<roll> (sensors) = sensors.phi
implement get_sensor<pitch> (sensors) = sensors.theta
implement get_sensor<yaw> (sensors) = sensors.psi


implement get_actuator<roll> (actuators) = actuators.aileron
implement get_actuator<pitch> (actuators) = actuators.elevator
implement get_actuator<yaw> (actuators) = actuators.rudder

implement draw_table (w, h, y, targets, sensors, actuators) = let
  val roll = @{
    id= 'r',
    label= "Roll"
  }
  val pitch = @{
    id= 'p',
    label= "Pitch"
  }
  val yaw = @{
    id= 'y',
    label= "Yaw"
  }
  var buf = @[char][128]('\0')
  val _ = $extfcall (void,
    "snprintf", buf, 128, "|%-8s|%8s|%8s|%8s|%8s|", "Plant", "Target", "Input", "Error", "Output"
  )
  
  fun draw_separator (y: int): void =
    draw_text_c_string (0, y, "|++++++++|++++++++|++++++++|++++++++|++++++++|", TB_DEFAULT, TB_DEFAULT)
in
  draw_text_c (0, y, buf, TB_DEFAULT, TB_DEFAULT); (* Heading *)
  draw_separator (y+1);
  draw_row<roll> (roll, y+2, targets, sensors, actuators);
  draw_separator (y+3);
  draw_row<pitch> (pitch, y+4, targets, sensors, actuators);
  draw_separator (y+5);
  draw_row<yaw> (yaw, y+6, targets, sensors, actuators);
  $extfcall (void,
    "snprintf", buf, 128, "|Air-Speed %8.2f", sensors.vcas
  );
  draw_text_c (0, y+8, buf, TB_DEFAULT, TB_DEFAULT);
  $extfcall (void,
    "snprintf", buf, 128, "|Elevation %8.2f", sensors.agl
  );
  draw_text_c (0, y+9, buf, TB_DEFAULT, TB_DEFAULT);
end