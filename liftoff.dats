(*
  A rough draft for a take off procedure
  
  These functions make up a "mission"
*)
staload "./autopilot.sats"

#define ATS_DYNLOADFLAG 0

extern
fun accelerate (sensors, actuators): mission

extern
fun tilt_up (sensors, actuators): mission

extern
fun lift_off (sensors, actuators): mission

extern
fun level_off (sensors, actuators): mission

fun stay_steady (
  input: sensors, output: actuators
): mission = let
  (* An unsatisifiable mission will never end. *)
  fun unsat ():<!laz> stream (bool) = 
    $delay ( stream_cons{bool} (false, unsat()))
in
  make_mission (unsat(), stay_steady)
end

(*
  The initial action taken by the autopilot to take off.
*)
implement takeoff (input, controls) = let
   (* Set the plane's initial state, and start to accelerate *)
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
  wait_until (input.speed >= 40.0, tilt_up)
end

implement tilt_up (input, controls) = let
  (* Tilt the nose slightly up until we rise off the ground. *)
  val () = set_pitch (controls, 7.0)
in
  wait_until (input.speed >= 70.0 andalso input.elevation >= 5.0, lift_off)
end

implement lift_off (input, controls) = let
  (* Start our climb, using the pitch of the plane to regulate our speed. *)
  val () = set_speed (controls, 70.0)
in
  wait_until (input.elevation >= 600.0, level_off)
end

implement level_off (input, controls) = let
  (* Reduce speed and lower our pitch to start cruising. *)
  val () = disable_speed (controls)
  val () = set_pitch (controls, 3.0)
  val () = set_throttle (controls, 0.75)
in
  stay_steady (input, controls)
end