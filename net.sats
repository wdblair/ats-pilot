%{#
#include "net_ctrls.h"
#include "net_fdm.h"

typedef struct FGNetFDM FGNetFDM ;
typedef struct FGNetCtrls FGNetCtrls ;
%}

typedef FGNetFDM = $extype_struct "FGNetFDM" of {
  phi= double,
  theta= double
}

typedef FGNetCtrls = $extype_struct "FGNetCtrls" of {
  aileron= double,
  elevator= double
}

