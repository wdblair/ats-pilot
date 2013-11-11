#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <math.h>

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
  
  cout << "Control: " <<  data << endl;
  return ;
}

template <typename T>
struct channel_t {
  int sd;
  struct sockaddr_in addr;
  T msg;
};

template <typename T>
void server (channel_t<T> &ch, int port) {
  ch.sd = Socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);

  memset(&ch.addr, 0, sizeof(ch.addr));          /* Clear struct */
  ch.addr.sin_family = AF_INET;                  /* Internet/IP */
  ch.addr.sin_addr.s_addr = htonl(INADDR_ANY);
  ch.addr.sin_port = htons(port);                /* server port */
  
  Bind (ch.sd, (struct sockaddr*)&ch.addr, sizeof(ch.addr));
}

template <typename T>
void receive (channel_t<T> &ch) {
  socklen_t addrlen = 0;
  static char buf[1024];
  int read;

  read = Recvfrom (ch.sd, buf, 1024, 0, (struct sockaddr*)&ch.addr, &addrlen);
  
  buf[read] = '\0';

  net_parse (&ch.msg, buf);
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

extern "C" void control_law (FGNetFDM *sensors, FGNetCtrls *actuators);

int main () {
  channel_t<FGNetCtrls> actuators;
  channel_t<FGNetFDM> sensors;

  server (sensors, 5000);
  client (actuators, "127.0.0.1", 5010);
  
  printf("Goliath Online\n");
  
  while (1) {
    receive (sensors);
    
    control_law (&sensors.msg, &actuators.msg);

    send (actuators);
  }
}
