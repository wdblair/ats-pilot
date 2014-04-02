#!/bin/bash

# The input is sampled more often than the output. FlightGear will
# just repeat control inputs in this case.

#fgfs --altitude=3000 --vc=75 --httpd=5500 \
fgfs --httpd=5500 \
    --generic=socket,out,10,localhost,5000,udp,sensor_protocol \
    --generic=socket,in,10,localhost,5010,udp,actuaotr_protocol
