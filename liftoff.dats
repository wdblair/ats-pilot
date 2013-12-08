(*
  A rough draft for a lift off procedure
*)

extern
fun lift_off (input: sensors, controls: actuators): void

extern
fun level_off (input: sensors, controls: actuators): void

(*
  The initial action taken by the autopilot to lift off.
*)
fun takeoff (input: sensors, controls: actuators): promise = let
  (* 
    Set the plane's initial state
      - Set target heading to current heading
      - Turn on the engine
      - Adjust throttle to max
      - Queue the next event.
  *)
in
  wait_for ()
end

fun speed_up (
  input: sensors, controls: actuators
): promise = let
  val () = set (controls, "roll", 0.0)
  val () = set (controls, "pitch", 3.0)
in
  if input.roll >= 40 then
    lift_off (input, controls)
  else
    speed_up (input, controls)
end

implement lift_off (input, controls) = let
  val () = set (controls, "roll", 0.0)
  val () = pid (controls, "speed", 70.0)
in
  if input.elevation >= 500 then
    level_off (input, controls)
end

implement level_off (input, controls) = begin
  set (controls, "roll", 0.0);
  set (controls, "pitch", 1.0);
end