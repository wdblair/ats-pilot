##
# An auto pilot system for the censa written in Nasal, the 
# scripting language inside Flightgear. This is basically an
# event driven script much like the one I wrote in ATS, but it
# utilizes FlightGear's internal PID implementation.
#

# Pitch
# /autopilot/locks/altitude
# on: pitch-hold
# input: /autopilot/internal/target-pitch-deg

# Level Flight 
# /autopilot/locks/wings-level on
# /autopilot/internal/target-roll-deg

# Heading
# /autopilot/locks/heading dg-heading-hold-(rudder|roll)
# Rudder: dg-heading-hold-rudder
# Roll: dg-heading-hold-roll
#/autopilot/settings/heading-bug-deg

# Vertical Speed
# /autopilot/locks/roc-lock (on|filter)
# /autopilot/internal/target-roc-fpm

# Altitude Hold
# /autopilot/locks/altitude-hold on

# Auto throttle 
# /autopilot/locks/speed speed-with-throttle
# /autopilot/settings/target-speed-kt

var ap = 'autopilot';
var lks = 'locks';
var stg = 'settings';
var intr = 'internal';

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
 heading = getprop ('/orientation/heading-magnetic-deg');

 print ("Selecting target heading: ", heading);

 setprop (ap, stg, 'heading-bug-deg', heading);
 #Clear the initial error
 setprop (ap, intr, 'heading-offset-deg', 0.0);
 setprop (ap, lks, 'heading', 'dg-heading-hold-rudder');

 setprop (ap, 'internal', 'target-roll-deg', 0);
 setprop (ap, lks, 'wings-level', 'on');

 setprop (ap, lks, 'speed', 'speed-with-throttle');
 setprop (ap, stg, 'target-speed-kt', 90);

 setprop (ap, 'internal', 'target-pitch-deg', 2.0);
 setprop (ap, lks, 'altitude', 'pitch-hold');
 
 return [ready_to_tip_nose, tip_nose];
};

#First, we tip the nose slightly up
var ready_to_tip_nose = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 40.0;
};

var tip_nose = func {
  setprop (ap, intr, 'target-pitch-deg', 4.5);
  
  return [ready_to_rise, rise];
};

var ready_to_rise = func {
  var speed = getprop ('/velocities/airspeed-kt');
  var elevation = getprop ('/position/altitude-ft');
  
  return (speed >= 70.0) and (elevation > 10.0);
};

var rise = func {
  setprop (ap, intr, 'target-roc-fpm', 720.0);
  setprop (ap, lks, 'roc-lock', 'on');

  return [ready_to_turn, turn];
};

var ready_to_turn = func {
  var height = getprop ('/position/altitude-ft');

  return abs(800.0 - height) < 25.0;
};

var turn = func {
    #Change our heading and adjust speed, use roll to adjust heading.
    setprop (ap, stg, 'target-altitude-ft', 800.0);
    setprop (ap, lks, 'altitude-hold', 'on');
    setprop (ap, lks, 'heading', 'dg-heading-hold-roll');
    setprop (ap, stg, 'target-speed-kt', 75);
    setprop (ap, stg, 'heading-bug-deg', 100.0);

    return [wait, 0];
};

var wait = func {
    return 0;
};

setprop ('/autopilot/locks/takeoff', 'off');

setlistener('/autopilot/locks/takeoff', setup);

var ready_to_takeoff = func {
   var start = getprop ('/autopilot/locks/takeoff');
   return start == 'on';
};

control_law (ready_to_takeoff, setup);