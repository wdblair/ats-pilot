(*
  autopilot
    
  A simple autopilot that aims to keep an aircraft steady.
*)

#define ATS_DYNLOADFLAG 0

#include "share/atspre_staload.hats"

%{^
#include <math.h>
%}

staload "net.sats"
staload "container.sats"

staload _ = "container.dats"

extern fun fabs (double): double = "mac#"

abst@ype pcontrol (tk:tkind) = @{target=double, k=double}

assume pcontrol (tk:tkind) = @{target=double, k=double}

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
  last_value= double
}

fun {plant:tkind}
make_pid (
  p: &pid(plant)? >> pid(plant), target: double,
  k_p: double, k_i: double, k_d: double
): void = begin
  p.target := target;
  p.k_p    := k_p;
  p.k_i    := k_i;
  p.k_d    := k_d;
  p.error_sum := 0.0;
  p.max_sum := 3.0;
  p.last_value := 0.0;
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

extern
fun control_setup (): void = "ext#"

extern
fun control_law (&FGNetFDM, &FGNetCtrls, &(container(double))): void = "ext#"

(*
  The three "plants" we'll control in this example
*)
stacst roll  : tkind
stacst pitch : tkind
stacst yaw   : tkind

typedef controllers = @{
  roll= pid (roll),
  pitch= pid (pitch),
  yaw= pid (yaw)
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

implement control_setup () = {
  val (vbox (pf) | ctrl) = ref_get_viewptr (control)
  val () = $effmask_ref (
    begin
      make_pid<roll> (ctrl->roll, 0.0, ~0.02, 0.01, 0.005);
      make_pid<pitch> (ctrl->pitch, 0.0, 0.03, 0.004, 0.01);
      (*
        There's an issue with adjusting yaw since we often
        go around in a circle. For example 359 is close to 0,
        but this controller flies to the left to go all the way
        back to zero instead of adjusting slightly to the right.
      *)
      make_pid<yaw> (ctrl->yaw, 0.0, ~0.1, 0.0, 0.0);
  end
  )
}

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
  
  fun cap (v: double, limit: double): double = let
    val absv = fabs (v)
  in
    if absv > limit then
      (v / absv) * limit
    else
      v
  end
  
  implement control_apply$filter<roll> (r, roll) = cap (roll, 0.5)
  implement control_apply$filter<pitch> (p, pitch) = cap (pitch, 0.5)
  implement control_apply$filter<yaw> (y, yaw) = cap (yaw, 0.4)

  val aileron = $effmask_ref (pid_apply<roll> (ctrl->roll, sensors.phi))
  val elevator = $effmask_ref (pid_apply<pitch> (ctrl->pitch, sensors.theta))
//  val rudder = $effmask_ref (pid_apply<yaw> (ctrl->yaw, sensors.psi))
in
  actuators.aileron := aileron;
  actuators.elevator := elevator;
  actuators.rudder := 0.0
end