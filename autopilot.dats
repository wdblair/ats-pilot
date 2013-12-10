(*
  autopilot
    
  A simple autopilot for flightgear. It uses lazy evaluation
  in order to provide the programmer with a framework to
  specify asynchronous events.
*)

#define ATS_DYNLOADFLAG 0

#include "share/atspre_staload.hats"

%{^
#include <math.h>
%}

staload UN = "prelude/SATS/unsafe.sats"

staload "./net.sats"
staload "./container.sats"

staload "./autopilot.sats"

staload _ = "container.dats"

extern fun fabs (double): double = "mac#"

abst@ype pid (tk:tkind) = @{
  target= double,
  k_p= double,
  k_i= double, 
  k_d= double,
  error_sum= double,
  max_sum= double,
  last_value= double
}

assume pid (tk:tkind) = @{
  target= double,
  k_p= double,
  k_i= double,
  k_d= double,
  error_sum= double,
  max_sum= double,
  last_value= double,
  active= bool
}

fun {plant:tkind}
make_pid (
  p: &pid(plant)? >> pid(plant), max_sum: double,
  k_p: double, k_i: double, k_d: double
): void = begin
  p.target := 0.0;
  p.k_p    := k_p;
  p.k_i    := k_i;
  p.k_d    := k_d;
  p.error_sum := 0.0;
  p.max_sum := max_sum;
  p.last_value := 0.0;
  p.active := true;
end

(*
  There may be rules each plant would like to enforce. Allow each plant to
  filter the result.
*)
extern
fun {plant:tkind}
control_apply$filter (
  p: &pid (plant), new: double
): double


fun {plant: tkind}
pid_apply (
  p: &pid(plant), process: double
): double = let
  val error = process - p.target
  
  val proportional = p.k_p * error
  
  val integral = ( let
    val next_sum = p.error_sum + error
  in
    if next_sum > p.max_sum then 
      p.k_i * p.max_sum where {
        val _ = p.error_sum := p.max_sum;
      }
    else if next_sum < ~p.max_sum then
      p.k_i * p.max_sum where {
        val _ = p.error_sum := ~p.max_sum;
      }
    else let
      val () = p.error_sum := next_sum
    in
      p.k_i * p.error_sum
    end
  end 
  ): double
  
  val derivative = let
    val diff = process - p.last_value
  in
    p.last_value := process;
    p.k_d * diff
  end
in
  control_apply$filter<plant> (p, (proportional + integral) + derivative)
end

fun {plant: tkind}
pid_disable (
  p: &pid(plant)
): void = p.active := false

fun {plant: tkind}
pid_enable (
  p: &pid(plant)
): void = p.active := true

(*
  The three "plants" we'll control in this example
*)
stacst roll  : tkind
stacst pitch : tkind
stacst yaw   : tkind

(*
  A cascading controller that uses pitch to control speed
*)
stacst speed : tkind

typedef controllers = @{
  roll= pid (roll),
  pitch= pid (pitch),
  yaw= pid (yaw),
  speed= pid (speed),
  (* Nothing fancy for the throttle *)
  throttle= double
}

local

  extern
  praxi{a:t@ype} static_initialized_lemma (&a? >> a): void

  var control : controllers
  
  prval () = static_initialized_lemma (control)
  
in
  val control = ref_make_viewptr {controllers} (
    view@(control) | addr@(control)
  )
end

(* ****** ***** *)

assume sensors = ref (FGNetFDM)
assume actuators = ref (controllers)
assume mission = ref( @(stream (bool), event) )
assume flow = stream (double)

implement trigger_takeoff (input) =  takeoff (input, control)

implement control_setup () = {
  val (vbox (pf) | ctrl) = ref_get_viewptr (control)
  val () = $effmask_ref (
    begin
      make_pid<roll> (ctrl->roll, 3.0, ~0.02, 0.015, 0.009);
      make_pid<pitch> (ctrl->pitch, 3.0, 0.03, 0.004, 0.01);
      (*
        There's an issue with adjusting yaw since we often
        go around in a circle. For example 359 is close to 0,
        but this controller flies to the left to go all the way
        back to zero instead of adjusting slightly to the right.
      *)
      make_pid<yaw> (ctrl->yaw, 3.0, ~0.09, 0.06, 0.008);
      
      make_pid<speed> (ctrl->speed, 10.0, 1.5, 0.75, 0.05);
  end
  )
  (* Start off with no controller on speed. *)
  val () = $effmask_ref (pid_disable (ctrl->speed))
  val () = ctrl->throttle := 0.0
}

fun cap (v: double, limit: double): double = let
  val absv = fabs (v)
in
  if absv > limit then
    (v / absv) * limit
  else
    v
end

implement control_apply$filter<roll> (r, roll) = cap (roll, 0.8)
implement control_apply$filter<pitch> (p, pitch) = cap (pitch, 1.0)
implement control_apply$filter<yaw> (y, yaw) = cap (yaw, 0.8)

implement control_apply$filter<speed> (s, pitch) = 
  (* Never try to go below 3 degrees *)
  if pitch < 3.0 then
    3.0
  (* Never try to go above 15 degrees *)
  else if pitch > 15.0 then
    15.0
  else
    pitch
    
implement control_law (sensors, actuators, targets) = let
  val (vbox (pf) | ctrl) = ref_get_viewptr (control)
    
  val troll  = $effmask_ref (targets['r'])
  val tpitch = $effmask_ref (targets['p'])
  val tyaw   = $effmask_ref (targets['y'])
  
  val () = $effmask_ref (begin
    ctrl->roll.target := troll;
    ctrl->pitch.target := tpitch;
    ctrl->yaw.target := tyaw
  end)
  
  val aileron = $effmask_ref (pid_apply<roll> (ctrl->roll, sensors.phi))
  val elevator = $effmask_ref (pid_apply<pitch> (ctrl->pitch, sensors.theta))
  val rudder = $effmask_ref (pid_apply<yaw> (ctrl->yaw, sensors.psi))
in
  actuators.aileron := aileron;
  actuators.elevator := elevator;
  actuators.rudder := rudder
end

(* ****** ****** *)

implement make_mission (samples, action) = let
  val mission = @(samples, action)
in
  ref<@(stream(bool), event)> (mission)
end

implement wait_until (samples, action) =
  make_mission (samples, action)
  
(* ****** ****** *)

implement sensors_get_roll (sensors) =
  $delay (stream_cons{double} (sensors->phi, sensors_get_roll (sensors)))

implement sensors_get_pitch (sensors) =
  $delay (stream_cons{double} (sensors->theta, sensors_get_pitch (sensors)))

implement sensors_get_heading_flow (sensors) =
  $delay (stream_cons{double} (sensors->psi, sensors_get_heading_flow (sensors)))

implement sensors_get_heading_double (sensors) = sensors->psi

implement sensors_get_speed (sensors) = 
  $delay (stream_cons{double} (sensors->vcas, sensors_get_speed (sensors)))
  
implement sensors_get_elevation (sensors) =
  $delay (stream_cons{double} (sensors->agl, sensors_get_elevation (sensors)))
  
(* ****** ****** *)

implement set_roll (actuators, r) = actuators->roll.target := r
implement set_pitch (actuators, p) = actuators->pitch.target := p
implement set_heading (actuators, h) = actuators->yaw.target := h
implement set_throttle (actuators, t) = actuators->throttle := t
implement set_speed (actuators, s) = begin
  actuators->speed.target := s;
  actuators->speed.active := true;
end

implement disable_speed (actuators) = {
  val (pf, fpf | p) = $UN.ref_vtake (actuators)
  val () = pid_disable (p->speed)
  prval () = fpf (pf)
}

(* ****** ****** *)

implement geq_flow_double (flow, i) = let
  fun merge (samples: stream (double), i: double): stream_con (bool) = 
    case+ !samples of 
      | stream_cons (sample, bs) => let
          val geq = sample >= i
        in
          stream_cons{bool} (geq, geq_flow_double (bs, i))
        end
      | stream_nil () => stream_nil ()
in
  $delay (merge (flow, i))
end

#define :: stream_cons

exception StreamLengthMismatch of ()

implement conj_stream_bool (lhs, rhs) = let
  fun merge (lhs: stream (bool), rhs: stream (bool)): stream_con (bool) = 
    case+ (!lhs, !rhs) of
      | (stream_cons (l, lhss), stream_cons (r, rhss)) =>
        (l && r) :: conj_stream_bool (lhss, rhss)
      | (stream_nil (), stream_nil ()) => 
        stream_nil ()
      (* TODO: Mix in the ATS2 runtime for this. *)
      | (_, _) =>> exit (1) where { 
        val () = prerrln! "Mismatch in stream lengths"
      }
in
  $delay (merge (lhs, rhs))
end

(* ****** ****** *)

implement control_law_mission (sensors, actuators, targets, mission) = let
  val (bs, finished) = !mission
  val next_task = (case+ !bs of
    | stream_cons (cond, bss) =>
      if cond then
        finished (sensors, control)
      else let
        val () = !mission := @(bss, finished)
      in mission end
    | stream_nil () =>
        finished (sensors, control)
  ): mission
  //
  val (pf, fpf | ctrl) = $UN.ref_vtake {controllers} (control)
  val () = 
    if ctrl->speed.active then let
      val pitch = pid_apply<speed> (ctrl->speed, sensors->vcas)
    in
      ctrl->pitch.target := pitch
    end
  //
  val aileron = pid_apply<roll> (ctrl->roll, sensors->phi)
  val elevator = pid_apply<pitch> (ctrl->pitch, sensors->theta)
  val rudder = pid_apply<yaw> (ctrl->yaw, sensors->psi)
  val throttle = ctrl->throttle;
  prval () = fpf (pf)
in
  actuators.aileron := aileron;
  actuators.elevator := elevator;
  actuators.rudder := rudder;
  actuators.throttle.[0] := throttle;
  next_task
end