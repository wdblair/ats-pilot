#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <math.h>
#include <termbox.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#include "net_ctrls.h"
#include "net_fdm.h"

#include <iostream>

using namespace std;

void err_sys (const char *msg) {
  perror (msg);
  exit (1);
}

int
Socket (int family, int type, int protocol)
{
        int             n;

        if ( (n = socket(family, type, protocol)) < 0)
                err_sys("socket error");
        return(n);
}

void
Bind(int fd, const struct sockaddr *sa, socklen_t salen)
{
  if (bind(fd, sa, salen) < 0)
    err_sys("bind error");
}

size_t
Recvfrom(int fd, void *ptr, size_t nbytes, int flags,
                 struct sockaddr *sa, socklen_t *salenptr)
{
        ssize_t         n;

        if ( (n = recvfrom(fd, ptr, nbytes, flags, sa, salenptr)) < 0)
                err_sys("recvfrom error");
        return(n);
}

size_t
AsyncRecvfrom(int fd, void *ptr, size_t nbytes, int flags,
              struct sockaddr *sa, socklen_t *salenptr)
{
  ssize_t n;
  if ( (n = recvfrom(fd, ptr, nbytes, flags, sa, salenptr)) < 0) {
    /* Nothing new to report */
    if (errno == EAGAIN || errno == EWOULDBLOCK) { 
      return n;
    }
    err_sys("recvfrom error");
  }
  return(n);
}

void
Sendto(int fd, const void *ptr, size_t nbytes, int flags,
           const struct sockaddr *sa, socklen_t salen)
{
  if (sendto(fd, ptr, nbytes, flags, sa, salen) != (ssize_t)nbytes)
    err_sys("sendto error");
}

void net_parse (FGNetFDM *net, const char *data) {
  int i;

  sscanf (data, "%f %f %f %f %f %f %f %f %f\n",
          &(net->phi), &(net->theta), &(net->psi),
          &(net->phidot), &(net->thetadot), &(net->psidot), 
          &(net->A_X_pilot), &(net->A_Y_pilot), &(net->A_Z_pilot)
          );
  
  return ;
}

void net_serialize (FGNetCtrls *net, char *data, size_t datalen) {
  
  snprintf (data, datalen, "%f\t%f\n", net->aileron, net->elevator);
  
  /* cout << "Control: " <<  data << endl; */
  return ;
}

template <typename T>
struct channel_t {
  int sd;
  struct sockaddr_in addr;
  T msg;
};

template <typename T>
void async_server (channel_t<T> &ch, int port) {
  ch.sd = Socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);

  /* Make the receiver non-blocking. */
  int flags = fcntl (ch.sd, F_GETFL);
  flags = O_NONBLOCK;
  fcntl (ch.sd, F_SETFL, flags);

  memset(&ch.addr, 0, sizeof(ch.addr));          /* Clear struct */
  ch.addr.sin_family = AF_INET;                  /* Internet/IP */
  ch.addr.sin_addr.s_addr = htonl (INADDR_ANY);
  ch.addr.sin_port = htons (port);                /* server port */
  
  Bind (ch.sd, (struct sockaddr*)&ch.addr, sizeof(ch.addr));

}

template <typename T>
int receive (channel_t<T> &ch) {
  socklen_t addrlen = 0;
  static char buf[1024];
  int read;

  read = AsyncRecvfrom (ch.sd, buf, 1024, 0, (struct sockaddr*)&ch.addr, &addrlen);

  if (read == -1) {
    return read;
  }
  
  buf[read] = '\0';

  net_parse (&ch.msg, buf);
  
  return 0;
}

template <typename T>
void client (channel_t<T> &ch, const char *strptr, int port) {
  ch.sd = Socket(AF_INET, SOCK_DGRAM, 0);
        
  int n;
  
  memset(&ch.addr, 0, sizeof(ch.addr));
  ch.addr.sin_family = AF_INET;
  ch.addr.sin_port = htons(port);
  
  if ( (n = inet_pton(AF_INET, strptr, &ch.msg)) < 0)
    err_sys("inet_pton error");
  else if (n == 0)
    err_sys("inet_pton error");
}

template <typename T>
void send (channel_t<T> &ch) {
  socklen_t addrlen = sizeof(ch.addr);
  char buf[1024];

  net_serialize (&ch.msg, buf, 1024);
  
  Sendto (ch.sd, buf, strlen(buf), 0, (struct sockaddr*)&ch.addr, addrlen);
  
  return;
}

extern "C" 
void control_law (FGNetFDM *sensors, FGNetCtrls *actuators, double *targets);

struct config {
  unsigned int manual; /* Let the pilot fly the plane. */
};

void update_display (double targets[256], struct config *c) {
  int w = tb_width ();
  int h = tb_height ();
  struct tb_event ev;
  
  /* Look for an event */
  if (tb_peek_event (&ev, 10)) {
    switch (ev.type) {
    case TB_EVENT_KEY:
      if (ev.key == TB_KEY_ESC) {
        tb_shutdown ();
        exit(0);  
      }
      
      switch (ev.ch) {
      case 'm':
        c->manual ^= 1;
        break;
      }
    }
  }

  tb_clear ();

  /* Display a little toolbar */
  for (int i = 0; i < w; i++) {
    tb_change_cell (i, 0, ' ', TB_DEFAULT, TB_GREEN);
  }
  
  string title = "ATS Mission Control";
  int len = title.length();


  if (w > len) {
    for (int i = (w/2 - len/2), j = 0; j < len && i < w; i++, j++) {
      tb_change_cell (i, 0, title[j], TB_DEFAULT, TB_GREEN);
    }
  }

  /* Display Auto pilot status */
  string autopilot_on = (!c->manual) ? "On" : "Off";

  string autopilot_label = "Auto-Pilot: " + autopilot_on;

  for (int j = 0; j < autopilot_label.length (); j++) {
    tb_change_cell (j, 1, autopilot_label[j], TB_DEFAULT, TB_DEFAULT);
  }

  tb_present ();
  
  return;
}

int main () {
  static double targets[256];
  struct config conf = {.manual = 1};

  
  channel_t<FGNetCtrls> actuators;
  channel_t<FGNetFDM> sensors;

  async_server (sensors, 5000);
  client (actuators, "127.0.0.1", 5010);
  
  /*
    Start off keeping the aircraft steady
   */
  targets['r'] = 0.0;
  targets['p'] = 5.0;

  tb_init ();

  while (1) {
    int ready;
    update_display (targets, &conf);
    
    ready = receive (sensors);
    
    if( ready == 0 && !conf.manual) {
      control_law (&sensors.msg, &actuators.msg, targets);
      send (actuators);
    }
    
    usleep (1000);
  }
}
