CC=g++

CCFLAGS += -O2

LDFLAGS = -Wl 

all: control

control: control.o autopilot.o liftoff.o panel.o
	$(CC) $(CCFLAGS) -o $@ $^ -ltermbox


control.o: control.cpp
	$(CC) -c $(CCFLAGS) -o $@ $<

autopilot.o: autopilot.dats
	patscc -DATS_MEMALLOC_LIBC -c -O2 -o autopilot.o $<

liftoff.o: liftoff.dats
	patscc -DATS_MEMALLOC_LIBC -c -O2 -o liftoff.o $<

panel.o: panel.dats
	patscc -c -O2 -o panel.o $<

clean: 
	rm control *_dats.c *.o *~
