(*
  autopilot
    
  A simple autopilot that just aims to 
  keep the aircraft steady using P controllers
*)

%{^
#include "net_ctrls.h"
#include "net_fdm.h"

#include <math.h>

typedef struct FGNetFDM FGNetFDM ;
typedef struct FGNetCtrls FGNetCtrls ;

%}

#define ATS_DYNLOADFLAG 0

#include "share/atspre_staload.hats"

extern fun fabs(double): double = "mac#"

typedef FGNetFDM = $extype_struct "FGNetFDM" of {
  phi= double,
  theta= double
}

typedef FGNetCtrls = $extype_struct "FGNetCtrls" of {
  aileron= double,
  elevator= double
}

abst@ype pcontrol (tk:tkind) = @{target=double, k=double}

assume pcontrol (tk:tkind) = @{target=double, k=double}

fun {plant:tkind}
make_pcontrol (
  p: &pcontrol(plant)? >> pcontrol(plant), target: double, k: double
): void = begin
  p.target := target;
  p.k := k
end

(*
  There may be rules each plant would like to enforce. Allow each plant to
  filter the result.
*)
extern
fun {plant:tkind}
control_apply$filter (
  p: &pcontrol (plant), new: double
): double

fun {plant:tkind}
control_apply (
  p: &pcontrol (plant), ref: double
): double = let
  val next = p.k * (ref - p.target)
in
  control_apply$filter<plant> (p, next)
end

extern
fun control_law (&FGNetFDM, &FGNetCtrls): void = "ext#"

(*
  The two "plants" we'll control in this example
*)
stacst roll  : tkind
stacst pitch : tkind

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
implement control_law (sensors, actuators) = let
  var r: pcontrol (roll)
  var p: pcontrol (pitch)
  
  val () = begin
    make_pcontrol<roll> (r, 0.0, ~0.05);
    make_pcontrol<pitch> (p, 5.0, 0.1);
  end
  
  fun cap (v: double, limit: double): double = let
    val absv = fabs (v)
  in
    if absv > limit then
      (v / absv) * 0.6
    else
      v
  end

  implement control_apply$filter<roll> (r, roll) = cap (roll, 0.6)
  implement control_apply$filter<pitch> (r, pitch) = cap (pitch, 0.6)

  val aileron = control_apply<roll> (r, sensors.phi)
  val elevator = control_apply<pitch> (p, sensors.theta)
in
  actuators.aileron := aileron;
  actuators.elevator := elevator
end
