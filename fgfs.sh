#!/bin/bash

# The input is sampled more often than the output. FlightGear will
# just repeat control inputs in this case.

fgfs --altitude=3000 --vc=75 --httpd=5500 \
    --generic=socket,out,40,localhost,5000,udp,output_protocol \
    --generic=socket,in,45,localhost,5010,udp,input_protocol
