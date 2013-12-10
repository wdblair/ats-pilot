(*
  Suppose sensors and actuators are flows of values that occur at some
  point in time.  A sensor is an  infinite list of pairs  (v, t) where
  the sensor  has a value  v at time t.  Assume the flow  is periodic.
  That is, any value t_i = t_{i-1} + \delta for some \delta >= 1
  
  Assume that all sensors and actuators have the same period.
*)
abstype sensors = ptr
abstype actuators = ptr

abstype flow = ptr

fun geq_flow_double (flow, double):<!laz> stream (bool)

overload >= with geq_flow_double

symintr andalso

fun conj_stream_bool (stream (bool), stream (bool)): stream (bool)

overload andalso with conj_stream_bool

symintr .roll
symintr .pitch
symintr .heading
symintr .speed
symintr .elevation

fun sensors_get_roll (sensors):<!laz> flow

overload .roll with sensors_get_roll

fun sensors_get_pitch (sensors):<!laz> flow

overload .pitch with sensors_get_pitch

fun sensors_get_heading_flow (sensors):<!laz> flow

overload .heading with sensors_get_heading_flow of 10

fun sensors_get_heading_double (sensors): double

overload .heading with sensors_get_heading_double of 20

fun sensors_get_speed (sensors):<!laz> flow

overload .speed with sensors_get_speed

fun sensors_get_elevation (sensors):<!laz> flow

overload .elevation with sensors_get_elevation of 20
  
fun
set_roll (actuators, double): void

fun
set_pitch (actuators, double): void

fun
set_heading (actuators, double): void

fun
set_throttle (actuators, double): void

fun
set_speed (actuators, double): void

(* Stop controlling speed by using pitch *)
fun
disable_speed (actuators): void

abstype mission = ptr

typedef event = (sensors, actuators) -> mission

fun make_mission (stream(bool), event): mission

fun wait_until (stream (bool), event): mission

(* ****** ****** *)

fun takeoff (sensors, actuators): mission

(* ****** ****** *)

staload "./net.sats"
staload "./container.sats"

(* The following functions are meant to be called from C++ *)
fun trigger_takeoff (
  ref (FGNetFDM)
): mission = "ext#"

fun control_law (
  &FGNetFDM, &FGNetCtrls, &(container(double))
): void = "ext#"

fun control_law_mission (
  ref (FGNetFDM), &FGNetCtrls, &(container(double)), mission
): mission = "ext#"

fun control_setup (): void = "ext#"