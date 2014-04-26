###
#
# The decision core of the uav.
#
# An auto pilot system for the Boeing 777-200 written in Nasal, the
# scripting language inside Flightgear. This is basically an
# event driven script much like the one I wrote in ATS, but it
# utilizes FlightGear's internal PID implementation.
#
# Right now, if I consider a mission a tree, its branching factor
# is fixed at one in our current implementation.
#
###

# Pitch
# /uav/locks/altitude
# on: pitch-hold
# input: /uav/internal/target-pitch-deg

# Level Flight 
# /uav/locks/wings-level on
# /uav/internal/target-roll-deg

# Heading
# /uav/locks/heading dg-heading-hold-(rudder|roll)
# Rudder: dg-heading-hold-rudder
# Roll: dg-heading-hold-roll
#/uav/settings/heading-bug-deg

# Vertical Speed
# /uav/locks/roc-lock (on|filter)
# /uav/internal/target-roc-fpm

# Altitude Hold
# /uav/locks/altitude-hold on

# Auto throttle 
# /uav/locks/speed speed-with-throttle
# /uav/settings/target-speed-kt

# Flaps 
# /controls/flight/flaps
# off - 0
# 1 - 0.033
# 5 - 0.166
# 15 - 0.5

#Landing gear
#/controls/gear/gear-down

print ("Goliath, Online");

var uav = 'uav';
var lks = 'locks';
var stg = 'settings';
var intr = 'internal';
var pln = 'planner';


control_law = func (test, next) {
  print ("Running Control Law");

  #By default, keep waiting until the   
  callback = func {
     control_law (test, next);
  };

  if (test()) {
     res = next();
     callback = func {
        control_law (res[0], res[1]);
     };
  }
  
  print ("Checking for conditions.");
  settimer (callback, 1);
}

#Set up the aircraft for flight.
var setup = func {
 heading = getprop ('/orientation/heading-deg');

 print ("Selecting target heading: ", heading);

 setprop (uav, pln, 'heading', heading);
 setprop (uav, intr, 'heading-offset-deg', 0.0);
 setprop (uav, lks, 'heading', 'dg-heading-hold-rudder');

 setprop (uav, 'internal', 'target-roll-deg', 0);
 setprop (uav, lks, 'wings-level', 'on');

 setprop (uav, lks, 'speed', 'speed-with-throttle');
 setprop (uav, stg, 'target-speed-kt', 250.0);

 setprop (uav, 'internal', 'target-pitch-deg', 0.0);
 setprop (uav, lks, 'altitude', 'pitch-hold');

 #Set flaps to 15
 setprop ('/controls/flight/flaps', 0.5);
 
 return [ready_to_tip_nose, tip_nose];
};

#First, we tip the nose slightly up
var ready_to_tip_nose = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 130.0;
};

var tip_nose = func {
  setprop (uav, intr, 'target-pitch-deg', 5.0);
  
  return [ready_to_rise, rise];
};

var ready_to_rise = func {
  var speed = getprop ('/velocities/airspeed-kt');
  var elevation = getprop ('/position/altitude-ft');
  
  return (speed >= 140.0) and (elevation > 20.0);
};

var rise = func {
  setprop (uav, intr, 'target-roc-fpm', 3000);
  setprop (uav, lks, 'roc-lock', 'on');

  return [ready_withdraw_flaps, withdraw_flaps];
};

var ready_withdraw_flaps = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 200.0;
};

var withdraw_flaps = func {
 setprop ('/controls/flight/flaps', 0.166);
 setprop ('controls/gear/gear-down', 0);
 
 return [ready_withdraw_flaps1, withdraw_flaps1];
};

var ready_withdraw_flaps1 = func {
   var speed = getprop ('/velocities/airspeed-kt');
   return speed >= 220.0;
};

var withdraw_flaps1 = func {
  setprop ('/controls/flight/flaps', 0.033);

  return [ready_retract_flaps, retract_flaps];
};

var ready_retract_flaps = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 240.0;
};

var retract_flaps = func {
  setprop ('/controls/flight/flaps', 0);
  
  var desired_height = getprop (uav, pln, 'target-altitude-ft');
  if (desired_height == 0) {
     #go to 10,000 ft by default
     setprop (uav, pln, 'target-altitude-ft', 10000);
  }
  
  setprop (uav, lks, 'altitude-hold', 'on');
  
  return [ready_to_turn, turn];
};

var ready_to_turn = func {
  var height = getprop ('/position/altitude-ft');

  return height > 5000.0;
};

var turn = func {
    setprop (uav, lks, 'heading', 'dg-heading-hold-roll');
    setprop (uav, pln, 'status', 'ready');
    setprop (uav, stg, 'heading-bug-deg', 154.0);
    
    return [wait, 0];
};

var wait = func {
    return 0;
};

setprop ('/uav/planner/mode', 'off');

var ready_to_takeoff = func {
   var start = getprop ('/uav/planner/mode');
   return start == 'to/ga';
};

control_law (ready_to_takeoff, setup);
