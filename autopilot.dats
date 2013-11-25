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
  p.max_sum := 2.0;
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
fun control_law (&FGNetFDM, &FGNetCtrls, &(container(double))): void = "ext#"

(*
  The three "plants" we'll control in this example
*)
stacst roll  : tkind
stacst pitch : tkind
stacst yaw   : tkind

(*
    In this  simple set up,  our target  values never change.  This is
    very  unrealistic because  autonomous vehicles  have all  sorts of
    states  they may  be in  at  any point.  Our goal  here is  steady
    flight, but you  can imagine how our target values for each plant
    would change if our goal was to sustain a banked turn or decrease
    our altitude.
    
    A particular function or goal translates to target values for each
    control law.
*)
implement control_law (sensors, actuators, targets) = let
  var r: pid (roll)
  var p: pid (pitch)
  var y: pid (yaw)
  
  val troll  = targets['r']
  val tpitch = targets['p']
  val tyaw   = targets['y']
  
  val () = begin
    make_pid<roll> (r, troll, ~0.03, 0.005, 0.0004);
    make_pid<pitch> (p, tpitch, 0.05, 0.004, 0.006);
    (* 
      There's an issue with adjusting yaw since we often
      go around in a circle. For example 359 is close to 0,
      but this controller flies to the left to go all the way
      back to zero instead of adjusting slightly to the right.
    *)
    make_pid<yaw> (y, tyaw, ~0.06, 0.006, 0.0004);
  end
  
  fun cap (v: double, limit: double): double = let
    val absv = fabs (v)
  in
    if absv > limit then
      (v / absv) * limit
    else
      v
  end
  
  implement control_apply$filter<roll> (r, roll) = cap (roll, 0.6)
  implement control_apply$filter<pitch> (p, pitch) = cap (pitch, 0.8)
  implement control_apply$filter<yaw> (y, yaw) = cap (yaw, 0.8)


  val aileron = pid_apply<roll> (r, sensors.phi)
  val elevator = pid_apply<pitch> (p, sensors.theta)
  val rudder = pid_apply<yaw> (y, sensors.psi)
in
  actuators.aileron := aileron;
  actuators.elevator := elevator;
  actuators.rudder := rudder
end
