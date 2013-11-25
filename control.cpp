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

extern "C" void draw_table (int ,int, int, double *, FGNetFDM *, FGNetCtrls *);

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
  
  snprintf (data, datalen, "%f\t%f\t%f\n", net->aileron, net->elevator, net->rudder);
  
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

#define CMD_LEN 32

struct command {
    char *c;
    char buf[CMD_LEN];
};

struct config {
  unsigned int manual; /* Let the pilot fly the plane. */
  unsigned int command_listen; /* Read characters as a command. */
  struct command command;
  unsigned int alert; /* The user should be alerted. */
  string msg; /* A message to be displayed to the user. */
};

void draw_text (int x, int y, string text, uint16_t fg, uint16_t bg) {
  int w = tb_width ();
  int h = tb_height ();
  
  if (y >= h) {
    return ;
  }

  for (int i = x, j = 0; j < text.length (); i++, j++) {
    if (i >= w || i < 0) {
      continue;
    }

    tb_change_cell (i, y, text[j], fg, bg);
  }
  
  return ;
}

extern "C" 
void draw_text_c (int x, int y, const char * text, uint16_t fg, uint16_t bg) {
  int w = tb_width ();
  int h = tb_height ();
  
  if (y >= h) {
    return ;
  }

  for (int i = x, j = 0; j < strlen(text); i++, j++) {
    if (i >= w || i < 0) {
      continue;
    }

    tb_change_cell (i, y, text[j], fg, bg);
  }
  
  return ;
}

void draw_horizontal_line (int x, int y, int len, uint16_t bg) {
  int w = tb_width ();
  int h = tb_height ();
  
  if (y >= h) {
    return ;
  }
  
  for (int i = x; i < len; i++ ) {
    if (i >= w) {
      break;
    }
    
    tb_change_cell (i, y, ' ', TB_DEFAULT, bg);
  }
  
  return ;
}

void append_char (struct command *cmd, char ch) {
  if (cmd->c == &cmd->buf[CMD_LEN]) {
    return;
  }
  *cmd->c++ = ch;
  
  return ;
}

void command_reset (struct command *cmd) {
  cmd->c = cmd->buf;
  memset (cmd->buf, 0, 32);
}

void command_back (struct command *cmd) {
  *cmd->c = '\0';
  cmd->c = max ((char*)cmd->buf, cmd->c - 1);
}

void publish_message (struct config *conf, string msg) {
  conf->msg = msg;
}

void update_display (double targets[256], struct config *c, 
                     FGNetFDM *sensors, FGNetCtrls *actuators) {
  int w = tb_width ();
  int h = tb_height ();
  struct tb_event ev;


  if (tb_peek_event (&ev, 10)) {
    /* Clear any alerts after input */
    c->alert = 0;

    switch (ev.type) {
    case TB_EVENT_KEY:
      switch (ev.key) {
      case TB_KEY_ESC:
        tb_shutdown ();
        exit (0);
        break;
      case TB_KEY_CTRL_A:
        c->manual ^= 1;
        break;
      case TB_KEY_CTRL_C:
        c->command_listen ^= 1;
        command_reset (&c->command);
        break;
      case TB_KEY_ENTER:
        if (c->command_listen) { /* Parse the command */
          char plant;
          double t;

          int match = sscanf (c->command.buf, "%c %lf", &plant, &t);
          
          if (match != 2) {
            c->command_listen = 0;
            command_reset (&c->command);
            publish_message (c, "Incorrect format, user [plant] [target]");
            c->alert = 1;
            break;
          }

          /* Update the target for the plant */
          targets[plant] = t;
          
          c->command_listen = 0;
        }
        break;
      case TB_KEY_SPACE:
        if (c->command_listen) {
          append_char (&c->command, ' ');
        }
        break;
      case TB_KEY_BACKSPACE:
        tb_shutdown ();
        exit (0);
        
        if (c->command_listen) {
          
          command_back (&c->command);
        }
        break;
      default:
        /* Add the character to the command */
        if (c->command_listen) {
          append_char (&c->command, ev.ch);
        }
        break;
      }
    }
  }
  
  tb_clear ();

  draw_horizontal_line (0, 0, w, TB_GREEN);

  string title = "ATS Mission Control";
  int len = title.length();

  /* Center the title */
  draw_text ((w/2) - (len/2), 0, title, TB_DEFAULT, TB_GREEN);
  
  /* Display Auto pilot status */
  string autopilot_status = (!c->manual) ? "On" : "Off";
  int bg = (!c->manual) ? TB_GREEN : TB_RED;

  string autopilot_label = "Auto-Pilot: ";

  int row = 2;
  
  draw_text (0, row, autopilot_label, TB_DEFAULT, TB_DEFAULT);
  draw_text (autopilot_label.length(), row, autopilot_status, TB_DEFAULT, bg);
  
  if (c->command_listen) {
    int bottom = h-1;
    string cmd_label = "Command: ";
    string cmd (c->command.buf);
    
    draw_horizontal_line (0, bottom, w, TB_GREEN);

    draw_text (0, bottom, cmd_label, TB_DEFAULT, TB_GREEN);
    draw_text (cmd_label.length(), bottom, cmd, TB_DEFAULT, TB_GREEN);
  }

  if (c->alert) {
    int bottom = h-1;
    string label = "Error: ";
    
    draw_horizontal_line (0, bottom, w, TB_RED);
    
    draw_text (0, bottom, label, TB_DEFAULT, TB_RED);
    draw_text (label.length(), bottom, c->msg, TB_DEFAULT, TB_RED);
  }

  draw_table (w, h, 5, targets, sensors, actuators);

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
    update_display (targets, &conf, &sensors.msg, &actuators.msg);
    
    ready = receive (sensors);
    
    if(ready == 0 && !conf.manual) {
      control_law (&sensors.msg, &actuators.msg, targets);
      send (actuators);
    }
    
    usleep (1000);
  }
}
