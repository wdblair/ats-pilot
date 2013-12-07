(*
  How I picture the lift off logic for an airplane
*)

tkindef sensor = "atstype_sensor"

(* 
  Suppose sensors and actuators are flows of values that occur
  some point in time. A sensor is an infinite list
  of pairs (v, t) where the sensor has a value v
  at time t. Assume the flow is periodic. That is,
  any value t_i = t_{i-1} + \delta for some \delta >= 1
  
  Assume that all sensors and actuators have the same period.
*)
abstype sensors
abstype actuators

abstype flow

abstype continuation

symintr .roll
symintr .elevation

extern
fun sensors_get_roll (sensors): flow

overload .roll with sensors_get_roll

extern
fun sensors_get_height (sensors): flow

overload .elevation with sensors_get_height

extern
fun geq_sensor_int (flow, int): bool

overload >= with geq_sensor_int

extern
fun set (actuators, string, double): void

extern
fun lift_off (input: sensors, controls: actuators): void

extern
fun level_off (input: sensors, controls: actuators): void

fun speed_up (
  input: sensors, controls: actuators
): void = let
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
  // Add a PID controller to regulate speed
in 
  if input.elevation >= 500 then
    level_off (input, controls)
end

implement level_off (input, controls) = begin
  set (controls, "roll", 0.0);
  set (controls, "pitch", 1.0);
end