# ATS Pilot

A prototype for building a Flight Management System in ATS.

## Control Laws

What makes a control law?
  
- A target value
- A function update: (reference, params) ->  new_value;
- The parameters for each plant
  
The template system allows us to define a typekind which can
identify each plant that is controlled.

  abst@ype pcontrol (tk:tkind)

  fun{tk:tkind}
  make (target: double, p: double): pcontrol (tk)

  fun update: (pcontrol, reference: double): double
