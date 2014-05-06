###
#
# The decision core of the uav.
#
# An auto pilot system for the Boeing 777-200 written in Nasal, the
# scripting language embedded in Flightgear. This is basically an
# event driven system that utilizes FlightGears internal PID 
# implementation.
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
#/uav/planning/heading

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

#Set up the aircraft for flight.
var setup = func {
 heading = getprop ('/orientation/heading-deg');

 print ("Selecting target heading: ", heading);

 #Turn off the parking brake
 setprop('/controls/gear/brake-parking', 0);

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
};

#First, we tip the nose slightly up
var ready_to_tip_nose = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 130.0;
};

var tip_nose = func {
  setprop (uav, intr, 'target-pitch-deg', 5.0);
};

var ready_to_rise = func {
  var speed = getprop ('/velocities/airspeed-kt');
  var elevation = getprop ('/position/altitude-ft');
  
  return (speed >= 140.0) and (elevation > 20.0);
};

var rise = func {
  setprop (uav, intr, 'target-roc-fpm', 3000);
  setprop (uav, lks, 'roc-lock', 'on');
};

var ready_withdraw_flaps = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 200.0;
};

var withdraw_flaps = func {
 setprop ('/controls/flight/flaps', 0.166);
 setprop ('controls/gear/gear-down', 0);
};

var ready_withdraw_flaps1 = func {
   var speed = getprop ('/velocities/airspeed-kt');
   return speed >= 220.0;
};

var withdraw_flaps1 = func {
  setprop ('/controls/flight/flaps', 0.033);

};

var ready_retract_flaps = func {
  var speed = getprop ('/velocities/airspeed-kt');

  return speed >= 240.0;
};

var retract_flaps = func {
  setprop ('/controls/flight/flaps', 0);
};

var ready_to_turn = func {
  var height = getprop ('/position/altitude-ft');

  return height > 5000.0;
};

var turn = func {
    setprop (uav, lks, 'heading', 'dg-heading-hold-roll');
    setprop (uav, pln, 'status', 'ready');
};

var ready_to_takeoff = func {
   var start = getprop ('/uav/planner/mode');
   return start == 'to/ga';
};

var never = func {
    return 0;
};

# Create a node in the tree.
var make_tree = func (activate, visit) {
    return {
        active: activate,
        expire: never,
        visit: visit,
        children: [],
        then: func (activate, visit) {
            var tr = make_tree(activate, visit);
            append(me.children, tr);
            return tr;
        },
        expires: func (expire) {
            me.expire = expire;
            
            return me;
        }
    };
};

# Start a mission at the top of a behavior tree
var start_mission = func (behavior) {
    frontier = [behavior];
    
    search(frontier);
};

# Search through the tree to fly the plane
var search = func (frontier) {

    if (size(frontier) == 0) {
        return;
    }
    
    var next_frontier = [];

    foreach (var node; frontier) {
        if (node.active ()) {
            node.visit ();
            foreach (var cnode; node.children) {
                append (next_frontier, cnode);
            }
        }
        else {
            append (next_frontier, node);
        }
    }

    settimer (func {
        search (next_frontier);
    }, 1);
};

# Check whether we are ready to begin take off
var begin_takeoff = func {
    var rdy = getprop('/uav/planner/mode');
    return rdy == 'to/ga';
};

#Build the root of our tree.
var setup = make_tree (begin_takeoff, setup);

#Describe the first two steps
var liftoff = setup.then (
    ready_to_tip_nose, 
    tip_nose
).then (
    ready_to_rise,
    rise
);

#Set the flaps to go down as we speed up.
liftoff.then (
    ready_withdraw_flaps,
    withdraw_flaps
).then (
    ready_withdraw_flaps1,
    withdraw_flaps1
).then (
    ready_retract_flaps,
    retract_flaps
);

#Set how to get to our cruising position
liftoff.then (func {
    var alt = getprop ('/position/altitude-ft');
    
    return alt > 10000.0;
}, func {
    # Once we climb to a standard height, we can climb at a variable
    # rate to reach a target altitude.
    var desired_height = getprop (uav, pln, 'altitude');
    
    if (desired_height == 0) {
        # go to 10,000 ft by default
        setprop (uav, pln, 'altitude', 10000);
    }
    
    setprop (uav, lks, 'altitude-hold', 'on');
}).then (func {
    var alt = getprop ('/position/altitude-ft');
    var tgt = getprop (uav, pln, 'altitude');

    var abs = func (a) {
        if (a < 0) {
            return a * -1;
        }
        return a;
    };

    #Check if within 500 ft of our target altitude
    return abs(alt - tgt) < 500.0;
}, func {
    #Speed up a bit for cruising
    setprop (uav, stg, 'target-speed-kt', 300.0);
});

#Set the landing gear down
liftoff.then (func {
    var speed = getprop ('/velocities/airspeed-kt');
    
    return speed >= 200.0;
}, func {
    #Turn off the landing gear
    setprop ('controls/gear/gear-down', 0);
});

#Move control from the rudder to the aileron's
#to move towards desired headings.
liftoff.then (func {
    var height = getprop ('/position/altitude-ft');
    
    return height > 1000.0;
}, func {
    #Switch to roll controlled heading
    setprop (uav, lks, 'heading', 'dg-heading-hold-roll');
    setprop (uav, pln, 'status', 'ready');
    # Straighten the rudder
    setprop (uav, intr, 'rudder-cmd', 0);
});

setprop ('/uav/planner/mode', 'off');

#Start the plane up...
settimer (func { 
  controls.autostart ();
}, 5);

#Begin the mission
start_mission (setup);
