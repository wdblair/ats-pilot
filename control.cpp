#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>

#include "net_fdm.hxx"
#include "net_ctrls.hxx"

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


static void htond (double &x)
{
  int    *Double_Overlay;
  int     Holding_Buffer;

  Double_Overlay = (int *) &x;
  Holding_Buffer = Double_Overlay [0];

  Double_Overlay [0] = htonl (Double_Overlay [1]);
  Double_Overlay [1] = htonl (Holding_Buffer);
}

static void htonf (float &x)
{
//      if ( sgIsLittleEndian() ) {
                int    *Float_Overlay;
                int     Holding_Buffer;

                Float_Overlay = (int *) &x;
                Holding_Buffer = Float_Overlay [0];

                Float_Overlay [0] = htonl (Holding_Buffer);
//      } else {
//              return;
//      }
}

void net_translate (FGNetCtrls *net) {
  printf("Translating controls\n");
  int i;

  // convert to network byte order
  net->version = htonl(net->version);
  htond(net->aileron);
  htond(net->elevator);
  htond(net->rudder);
  htond(net->aileron_trim);
  htond(net->elevator_trim);
  htond(net->rudder_trim);
  htond(net->flaps);
  net->flaps_power = htonl(net->flaps_power);
  net->flap_motor_ok = htonl(net->flap_motor_ok);

  net->num_engines = htonl(net->num_engines);
  for ( i = 0; i < FGNetCtrls::FG_MAX_ENGINES; ++i ) {
    net->master_bat[i] = htonl(net->master_bat[i]);
    net->master_alt[i] = htonl(net->master_alt[i]);
    net->magnetos[i] = htonl(net->magnetos[i]);
    net->starter_power[i] = htonl(net->starter_power[i]);
    htond(net->throttle[i]);
    htond(net->mixture[i]);
    net->fuel_pump_power[i] = htonl(net->fuel_pump_power[i]);
    htond(net->prop_advance[i]);
    htond(net->condition[i]);
    net->engine_ok[i] = htonl(net->engine_ok[i]);
    net->mag_left_ok[i] = htonl(net->mag_left_ok[i]);
    net->mag_right_ok[i] = htonl(net->mag_right_ok[i]);
    net->spark_plugs_ok[i] = htonl(net->spark_plugs_ok[i]);
    net->oil_press_status[i] = htonl(net->oil_press_status[i]);
    net->fuel_pump_ok[i] = htonl(net->fuel_pump_ok[i]);
  }

  net->num_tanks = htonl(net->num_tanks);
  for ( i = 0; i < FGNetCtrls::FG_MAX_TANKS; ++i ) {
    net->fuel_selector[i] = htonl(net->fuel_selector[i]);
  }

  net->cross_feed = htonl(net->cross_feed);
  htond(net->brake_left);
  htond(net->brake_right);
  htond(net->copilot_brake_left);
  htond(net->copilot_brake_right);
  htond(net->brake_parking);
  net->gear_handle = htonl(net->gear_handle);
  net->master_avionics = htonl(net->master_avionics);
  htond(net->wind_speed_kt);
  htond(net->wind_dir_deg);
  htond(net->turbulence_norm);
  htond(net->temp_c);
  htond(net->press_inhg);
  htond(net->hground);
  htond(net->magvar);
  net->icing = htonl(net->icing);
  net->speedup = htonl(net->speedup);
  net->freeze = htonl(net->freeze);
  return ;
}

void net_translate (FGNetFDM *net) {
  printf("Translating fdm\n");
  int i;

  net->version = ntohl(net->version);

  htond(net->longitude);  // use
  htond(net->latitude);   // use 
  htond(net->altitude);   // use
  htonf(net->agl);
  htonf(net->phi);
  htonf(net->theta);
  htonf(net->psi);
  htonf(net->alpha);
  htonf(net->beta);
  
  htonf(net->phidot);     // use
  htonf(net->thetadot);   // use
  htonf(net->psidot);     // use
  htonf(net->vcas);
  htonf(net->climb_rate);
  htonf(net->v_north);
  htonf(net->v_east);
  htonf(net->v_down);
  htonf(net->v_wind_body_north);
  htonf(net->v_wind_body_east);
  htonf(net->v_wind_body_down);

  htonf(net->A_X_pilot);  // use
  htonf(net->A_Y_pilot);  // use
  htonf(net->A_Z_pilot);  // use
  
  htonf(net->stall_warning);
  htonf(net->slip_deg);

  net->num_engines = htonl(net->num_engines);
  for ( i = 0; i < net->num_engines; ++i ) {
    net->eng_state[i] = htonl(net->eng_state[i]);
    htonf(net->rpm[i]);
    htonf(net->fuel_flow[i]);
    htonf(net->fuel_px[i]);
    htonf(net->egt[i]);
    htonf(net->cht[i]);
    htonf(net->mp_osi[i]);
    htonf(net->tit[i]);
    htonf(net->oil_temp[i]);
    htonf(net->oil_px[i]);
  }

  // Environment
  net->cur_time = htonl(net->cur_time);  // current unix time
                                   // FIXME: make this uint64_t before 2038
  htonl(net->warp);                // offset in seconds to unix time
  htonf(net->visibility);     // visibility in meters (for env. effects)

  // Control surface positions (normalized values)
  htonf(net->elevator);
  htonf(net->elevator_trim_tab);
  htonf(net->left_flap);
  htonf(net->right_flap);
  htonf(net->left_aileron);
  htonf(net->right_aileron);
  htonf(net->rudder);
  htonf(net->nose_wheel);
  htonf(net->speedbrake);
  htonf(net->spoilers);
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

  /// the port where net fdm is received
  memset(&ch.addr, 0, sizeof(ch.addr));       /* Clear struct */
  ch.addr.sin_family = AF_INET;                  /* Internet/IP */
  ch.addr.sin_addr.s_addr = htonl(INADDR_ANY);
  ch.addr.sin_port = htons(port);       /* server port */
  
  Bind (ch.sd, (struct sockaddr*)&ch.addr, sizeof(ch.addr));
}

template <typename T>
void receive (channel_t<T> &ch) {
  socklen_t addrlen = 0;

  Recvfrom (ch.sd, (char*)&ch.msg, sizeof(ch.msg), 0, (struct sockaddr*)&ch.addr, &addrlen);
  
  net_translate (&ch.msg);
}

template <typename T>
void client (channel_t<T> &ch, const char *strptr, int port) {
  ch.sd = Socket(AF_INET, SOCK_DGRAM, 0);
        
  int n;
  
  memset(&ch.addr, 0, sizeof(ch.addr));       /* Clear struct */
  ch.addr.sin_family = AF_INET;
  ch.addr.sin_port = htons(port);
  
  if ( (n = inet_pton(AF_INET, strptr, &ch.msg)) < 0)
    err_sys("inet_pton error");      /* errno set */
  else if (n == 0)
    err_sys("inet_pton error");     /* errno not set */
}

template <typename T>
void send (channel_t<T> &ch) {
  socklen_t addrlen = sizeof(ch.addr);
  
  net_translate (&ch.msg);

  Sendto (ch.sd, (char*)&ch.msg, sizeof(ch.msg), 0, (struct sockaddr*)&ch.addr, addrlen);
  
  return;
}

int main () {
  channel_t<FGNetCtrls> control, actuators;
  channel_t<FGNetFDM> sensors;

  server (sensors, 5600);
  server (control, 5601);

  client (actuators, "10.0.2.2", 5602);

  while (1) {
    receive (sensors);
    //receive (control);
 
    printf("environmetn recvd");

    //printf("Control Received\n");
    //printf("engines:%d\n", actuators.msg.num_engines);
    // printf("throttle:%f\n", actuators.msg.throttle[0]);

    printf ("engines:%u\n", sensors.msg.num_engines);
    printf ("state:%u\n", sensors.msg.eng_state[0]);
    printf ("rpm:%f\n", sensors.msg.rpm[0]);

    actuators.msg = control.msg;
      
    // Turn it on
    actuators.msg.starter_power[0] = 1;
    
    //send (actuators);

    //printf("Control Sent\n");
  }
  
#if 0

  sd = Socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);


  
  FGNetFDM state;
  FGNetCtrls initial, ctrl;
  
  //Get the initial control


  while(1) {
    
    FGNetFDM2Props (&state);

    printf ("height: %f meters\n", state.altitude);
    printf ("velocity: (%f,%f)\n", state.v_north, state.v_east);
  }
#endif
}
