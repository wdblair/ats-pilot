# ATS Pilot

A prototype for building a Flight Management System in ATS. We wish to
make convincing use of the ATS2  template system and abstract types as
a method to write embedded software.

## Running 

1. Install the  [FlightGear Simulator](http://www.flightgear.org/) for
your platform. On Windows and Mac there are installers you can use but
on  Linux  you should  look  for  it  on your  distribution's  package
manager.

2.  FlightGear supports  controlling the  simulation through  external
programs  over  sockets.  The  state  of a  flight  at  any  point  is
controlled              through               a              [Property
Tree](http://wiki.flightgear.org/Property_Tree)   in  FlightGear.   In
order to receive these properties at  some rate, we outline a protocol
in an  XML file that  describes which properties  we want and  in what
format FlightGear  should send  them. Refer to  input_protocol.xml for
this example. We  can read this information as text  over a UDP socket
across  a network  or even  on the  same machine.  In this  system, we
receive sensor readings from the aircraft 40 times per second. To send
control data back  to FlightGear, we outline a protocol  as we did for
input  in an  XML  file. The  file,  output_protocol.xml, serves  this
purpose. In order for the simulator  to read these files, copy them to
your FlightGear protocol directory. This is located in

    /path/to/flightgear/data/Protocol/

3.  Compile the  control  program  with make.  Note,  a working  [ATS2
compiler](http://www.ats-lang.org) is required.

4. Run the simulator with

    ./fgfs.sh

and then when you want the control software to take over, run

    ./control

The shell script starts the aircraft at a few thousand feet so you don't
have to worry about lift off. Just start the engine by pressing "s" and
then adjusting the throttle with Page Up. You can press "Tab" to adjust
the controls so that your mouse will control the elevators, ailerons, and
rudders.

## Control Laws

What makes a control law?
  
- A target value
- A function update: (reference, params) ->  new_value;
- A model for each plant or process we wish to control
  
The template system allows us to define a typekind which can
identify each plant that is controlled.

  abst@ype pcontrol (tk:tkind)

  fun{tk:tkind}
  make_pcontrol (target: double, p: double): pcontrol (tk)

  fun{tk:tkind}
  update: (pcontrol(tk), reference: double): double

# Demo

As the project continues, we'll have some videos to post to 
demonstrate our system.

http://www.youtube.com/embed/1qbjSViBSco
