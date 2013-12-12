%{#
#include "net_ctrls.h"
#include "net_fdm.h"
%}

typedef FGNetFDM = $extype_struct "FGNetFDM" of {
  phi= double,
  theta= double,
  psi= double,
  vcas= double,
  agl= double
}

typedef FGNetCtrls = $extype_struct "FGNetCtrls" of {
  aileron= double,
  elevator= double,
  rudder= double,
  throttle= @[double][1]
}
