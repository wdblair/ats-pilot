#!/bin/bash

fgfs --native-fdm=socket,out,2,127.0.0.1,5600,udp --native-ctrls=socket,out,2,127.0.0.1,5601,udp --native-ctrls=socket,in,2,127.0.0.1,5602,udp

