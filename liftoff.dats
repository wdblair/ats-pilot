(*
  A rough draft for a take off procedure
*)
staload "autopilot.sats"

extern
fun accelerate (sensors, actuators): thread

extern
fun tilt_up (sensors, actuators): thread

extern
fun lift_off (sensors, actuators): thread

extern
fun level_off (sensors, actuators): thread

fun stay_steady (
  sensors, actuators
): thread = make_thread ($delay (stream_nil{bool} ()), stay_steady)

(*
  The initial action taken by the autopilot to lift off.
*)
implement takeoff (input, controls) = let
  (* 
    Set the plane's initial state, and start to accelerate
  *)
   val () = set_roll (controls, 0.0)
   val () = set_pitch (controls, 3.0)
   val () = set_heading (controls, input.heading)
in
  accelerate (input, controls)
end

implement accelerate (input, controls) = let
  (* Set max throttle for take off *)
  val () = set_throttle (controls, 0.9)
in
  wait_until (input.speed >= 40, tilt_up)
end

implement tilt_up (input, controls) = let
  (* Tilt the nose slightly up until we rise off the ground. *)
  val () = set_pitch (controls, 7.0)
in
  wait_until (input.speed >= 70 andalso input.elevation >= 10, lift_off)
end

implement lift_off (input, controls) = let
  (* Start our climb, using the pitch of the plane to regulate our speed. *)
  val () = set_speed (controls, 70.0)
  val b = true && false
in
  wait_until (input.elevation >= 1000, level_off)
end

implement level_off (input, controls) = let
  (* Reduce speed and lower our angle of attack to start cruising. *)
  val () = set_pitch (controls, 1.0)
  val () = set_throttle (controls, 0.75)
in
  stay_steady (input, controls)
end