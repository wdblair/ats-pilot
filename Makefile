CC=g++

CCFLAGS += 

LDFLAGS = -Wl 

all: control

control: control.cpp
	$(CC) $(CCFLAGS) -o $@ $<

clean: 
	rm control *~
