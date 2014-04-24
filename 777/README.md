777 Autopilot
=============

These are the configuration files needed for our 777 auto pilot
written using FlightGear's internal scripting environment.


Install these files into /usr/share/flightgear/data/Aircraft/777-200/
in their respective folders.

- 777-200-set.xml -> $FG_ROOT/Aircraft/777-200/
- 777-autopilot-bare.xml -> $FG_ROOT/Aircraft/777-200/Systems/
- uav.nas -> $FG_ROOT/Aircraft/777-200/Nasal/


Running
=======

Once the files are in place, you can try it out with

    fgfs --aircraft=777-200

Start the engine (S), release the brake (Shift B) and then turn on take off
by doing the following.

- Open Debug -> Browse Internal Properties
- Set /uav/locks/takeoff to "on"

