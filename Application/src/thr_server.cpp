// file: thr_server.cpp
// modified: 6/22/2012  9:00p

// A simple server in the internet domain using TCP
// The port number is passed as an argument 

#include <boost/thread/thread.hpp>
#include <boost/thread/mutex.hpp>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <string.h>
#include <memory.h>
#include <sys/wait.h>
#include <pthread.h>
#include "Coordinator.h"


#define BUF_LEN 2048
#define NUMTHREADS 5
#define TIME_LEN_MAX 32
#define MY_LOGFILE "/home/andrew/data/website/website/logs/thr_server.log"


#define NDEBUG


class Coordinator;


typedef struct {
  //  pthread_t tid;
  int thr_num;
  int ns;              // new socket
  FILE *fp_mylogfile;
  Coordinator *C_p;
} thread_registry_t;


// calls AccessDb::doLogin()
void call_Coordinator_verifyLogin(Coordinator *, char *, char *); 
 
// reads and handles incoming messages
// all threads go to this routine when created 
void *dispatch_routine(thread_registry_t *);

// set up a bunch of threads; pass them a pointer to the log file
thread_registry_t *setup_thread_registry(FILE *, Coordinator *);

void cleanup_thread_registry(thread_registry_t *);

// get timestamp for logfile entries
char *get_time_string();

// prevent simultaneous logfile writes 
boost::mutex global_logfile_mutex;


void error(const char *msg)
{
    perror(msg);
    exit(1);
}


// sets up the threads and listening sockets
void socket_routine(Coordinator *C_p, int port_num)
{
  thread_registry_t *thread_bank;
  int i = NUMTHREADS - 1;
  pthread_attr_t attr;
  FILE *fp_mylogfile;
  int soc, new_soc, status;
  int portno, pid;
  socklen_t clilen;
  struct sockaddr_in serv_addr, cli_addr;

#ifndef NDEBUG
  int j = 0;
#endif

  if ((fp_mylogfile = fopen(MY_LOGFILE, "a+")) == NULL) {                // open logfile or die */
    fprintf(stderr, "failed to open logfile\n");
    exit(1);
  }

  setbuf(fp_mylogfile, NULL);                                            // turn off buffering for log output */

  if (freopen(MY_LOGFILE, "a+", stderr) == NULL)                         // redirect stderr to log file */
    fprintf(fp_mylogfile, "Unable to redirect stderr\n");

  setbuf(stderr, NULL);                                                  // MUST turn off buffering for redirected stderr now also

  fprintf(fp_mylogfile, "[%s] Starting program\n", get_time_string()); 
  
  soc = socket(AF_INET, SOCK_STREAM, 0);                               
  if (soc < 0) 
    error("ERROR opening socket");

  bzero((char *) &serv_addr, sizeof(serv_addr));                         // set up address to bind to
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = INADDR_ANY;
  serv_addr.sin_port = htons(port_num);
  if (bind(soc, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) 	  
    error("ERROR on binding");
  listen(soc, 5);                               
  
  fprintf(fp_mylogfile, "[%s] Listening...\n", get_time_string());     

  thread_bank = setup_thread_registry(fp_mylogfile, C_p);                // get the threads ready
  //  setup_thread_attr(&attr);

#ifndef NDEBUG
  while(j++ < 10) {
#else


  while(1) {                                                             // main loop

#endif

    if (i == NUMTHREADS - 1)                                             // thread identifier
      i = 0;
    else
      ++i;
    
    clilen = static_cast<socklen_t>(sizeof(cli_addr));
    new_soc = accept(soc, (struct sockaddr *) &cli_addr, &clilen); 
    
    /* CRITICAL REGION */
    {
      boost::mutex::scoped_lock lock(global_logfile_mutex);
      if (new_soc >= 0) {                                               
	fprintf(fp_mylogfile, "[%s] Accept successful on socket %d\n",
		get_time_string(), new_soc);
      }
      else {                                                            
	fprintf(fp_mylogfile, "[%s] Accept failed\n", get_time_string());
	close(soc);
      }
    }
    /* END CRITICAL REGION */

    thread_bank[i].ns = new_soc;                                         // associate this thread with the new socket

    boost::thread b_thread1(boost::bind(&dispatch_routine, &thread_bank[i]));
    boost::thread b_thread2;

    
    //    status = pthread_create(&thread_bank[i].tid, &attr, dispatch_routine, &thread_bank[i]);  
    
    /* CRITICAL REGION */
    {
      boost::mutex::scoped_lock lock(global_logfile_mutex);
      if (status) {                                                    
	fprintf(fp_mylogfile, "[s] pthread create failed\n", get_time_string());
	close(soc);
      }
    }    /* END CRITICAL REGION */  

  }                                                                      // end of main loop

  close(soc);                                                            // don't expect to ever get this far

  /* CRITICAL REGION */
  {
    boost::mutex::scoped_lock lock(global_logfile_mutex);
    fprintf(fp_mylogfile, "[%s] listening socket closed\n", get_time_string());
  }

  cleanup_thread_registry(thread_bank);                                 

  fprintf(fp_mylogfile, "[%s] thread registry deleted. stopping program.\n",
          get_time_string());

  fclose(fp_mylogfile);                                                 
}


/******** dispatch_routine() *********************
 *    reads from socket
 *    figures out what command was received
 *    sets thread to obeying that command
 *    logs success or failure of command
 *       called by: pthread_create() in socket_routine()
 *****************************************/

void *dispatch_routine(thread_registry_t *arg)
{
  int k;
  char buf[BUF_LEN];
  char response[BUF_LEN];
  thread_registry_t *this_thread = arg;

  void call_Coordinator_verify_login(Coordinator *, char *, char *);
  void call_Coordinator_change_password(Coordinator *, char *, char *);
  void call_Coordinator_create_account(Coordinator *, char *, char *); 
  void call_Coordinator_delete_account(Coordinator *, char *, char *); 
  void call_Coordinator_create_case(Coordinator *, char *, char *);
  void call_Coordinator_link_account_case(Coordinator *, char *, char *);
  void call_Coordinator_instantiate_role_account(Coordinator *, char *, char *);
  void call_Coordinator_logout(Coordinator *, char *, char *);
  void call_Coordinator_create_doc(Coordinator *, char *, char *);
  void call_Coordinator_create_accessor(Coordinator *, char *, char *);
  void call_Coordinator_create_signature(Coordinator *, char *, char *);
  void call_Coordinator_view_account(Coordinator *, char *, char *);
  void call_Coordinator_view_case(Coordinator *, char *, char *);
  void call_Coordinator_change_case_status(Coordinator *, char *, char *);
  void call_Coordinator_view_doc(Coordinator *, char *, char *);
  void call_Coordinator_edit_account(Coordinator *, char *, char *);
  void call_Coordinator_start_doc_edit(Coordinator *, char *, char *);
  void call_Coordinator_end_doc_edit(Coordinator *, char *, char *);
  void call_Coordinator_doc_access_sign_list(Coordinator *, char *, char *);
  void call_Coordinator_store_and_send_status_report(Coordinator *, char *, char *);
  void call_Coordinator_add_avail(Coordinator *, char *, char *);
  void call_Coordinator_delete_avail(Coordinator *, char *, char *);
  void call_Coordinator_view_avail(Coordinator *, char *, char *);
  void call_Coordinator_add_meeting(Coordinator *, char *, char *);
  void call_Coordinator_update_meeting_state(Coordinator *, char *, char *);
  void call_Coordinator_view_meeting(Coordinator *, char *, char *);
  void call_Coordinator_save_meeting_doc(Coordinator *, char *, char *);
  void call_Coordinator_add_attendance(Coordinator *, char *, char *);
  void call_Coordinator_update_attendance(Coordinator *, char *, char *);
  void call_Coordinator_delete_attendance(Coordinator *, char *, char *);
  void call_Coordinator_send_message(Coordinator *, char *, char *);
  void call_Coordinator_read_message_received(Coordinator *, char *, char *);
  void call_Coordinator_read_message_sent(Coordinator *, char *, char *);
  void call_Coordinator_get_message_received_list(Coordinator *, char *, char *);
  void call_Coordinator_get_message_sent_list(Coordinator *, char *, char *);
  void call_Coordinator_destroy_document(Coordinator *, char *, char *);
  void call_Coordinator_get_final_agreement(Coordinator *, char *, char *);
  void call_Coordinator_get_initial_agreement(Coordinator *, char *, char *);

  
  /* CRITICAL REGION */
  {
    boost::mutex::scoped_lock lock(global_logfile_mutex);

    if ((k = read(this_thread->ns, buf, sizeof(buf)-1)) == -1) {                  
    
      fprintf(this_thread->fp_mylogfile, "[%s] read error in dispatch_routine(): thread %d\n",
	      get_time_string(), this_thread->thr_num);                           
      buf[0] = '\0';                                                              
    } else if (k == 0) {                                                                
      fprintf(this_thread->fp_mylogfile, "[%s] 0 bytes read: thread %d\n",        
	      get_time_string(), this_thread->thr_num);
    } else {                                                                      
      buf[k] = '\0';                                                              
      fprintf(this_thread->fp_mylogfile, "[%s] Server received: %s thread %d\n",
	      get_time_string(), buf, this_thread->thr_num);
    }
  }
    /* END CRITICAL REGION */

  // check the first token of the request
  // call the appropriate 'call Coordinator' function

  if (!strncmp(buf, "LOGIN", 5))
    call_Coordinator_verify_login(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CHANGEPASSWORD", 14 ))
    call_Coordinator_change_password(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CREATEACCOUNT", 13))
    call_Coordinator_create_account(this_thread->C_p, buf, response); 
  else if (!strncmp(buf, "DELETEACCOUNT", 13))
    call_Coordinator_delete_account(this_thread->C_p, buf, response); 
  else if (!strncmp(buf, "CREATECASE", 10))
    call_Coordinator_create_case(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "LINKACCOUNTCASE", 15))
    call_Coordinator_link_account_case(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETROLE", 7))
    call_Coordinator_instantiate_role_account(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "LOGOUT", 6))
    call_Coordinator_logout(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CREATEDOC", 9))
    call_Coordinator_create_doc(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CREATEACCESSOR", 14))
    call_Coordinator_create_accessor(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CREATESIGNATORIES", 17))
    call_Coordinator_create_signature(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "VIEWACCOUNT", 11))
    call_Coordinator_view_account(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "VIEWCASE", 8))
    call_Coordinator_view_case(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "CHANGECASESTATUS", 16))
    call_Coordinator_change_case_status(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "VIEWDOC", 7))
    call_Coordinator_view_doc(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "EDITACCOUNT", 11))
    call_Coordinator_edit_account(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "STARTDOCEDIT", 12))
    call_Coordinator_start_doc_edit(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "ENDDOCEDIT", 10))
    call_Coordinator_end_doc_edit(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETDOCACCESSANDSIGNLIST", 23))
    call_Coordinator_doc_access_sign_list(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETSTATUSREPORT", 15))
    call_Coordinator_store_and_send_status_report(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "ADDAVAIL", 8))
    call_Coordinator_add_avail(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "DELETEAVAIL", 11))
    call_Coordinator_delete_avail(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "VIEWAVAIL", 9))
    call_Coordinator_view_avail(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "ADDMEETING", 10))
    call_Coordinator_add_meeting(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "UPDATEMEETINGSTATE", 18))
    call_Coordinator_update_meeting_state(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "VIEWMEETING", 11))
    call_Coordinator_view_meeting(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "SAVEMEETINGDETAIL", 17))
    call_Coordinator_save_meeting_doc(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "ADDATTENDANCE", 13))
    call_Coordinator_add_attendance(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "UPDATEATTENDANCE", 16))
    call_Coordinator_update_attendance(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "DELETEATTENDANCE", 16))
    call_Coordinator_delete_attendance(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "SENDMESSAGE", 11))
    call_Coordinator_send_message(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "READMESSAGERECEIVED", 19))
    call_Coordinator_read_message_received(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "READMESSAGESENT", 15))
    call_Coordinator_read_message_sent(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETMESSAGERECEIVEDLIST", 22))
    call_Coordinator_get_message_received_list(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETMESSAGESENTLIST", 18))
    call_Coordinator_get_message_sent_list(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "DESTROYDOCUMENT", 15))
    call_Coordinator_destroy_document(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETFINALAGR", 11))
    call_Coordinator_get_final_agreement(this_thread->C_p, buf, response);
  else if (!strncmp(buf, "GETINITAGR", 10))
    call_Coordinator_get_initial_agreement(this_thread->C_p, buf, response);

  write(this_thread->ns, response, strlen(response));

  /* CRITICAL REGION */
  {
    boost::mutex::scoped_lock lock(global_logfile_mutex);

    fprintf(this_thread->fp_mylogfile, "[%s] responded: %s thread %d\n",
	    get_time_string(), response, this_thread->thr_num);
  }
  /* END CRITICAL REGION */

  close(this_thread->ns);                                             
}


/*****************************************************************
 * setup_thread_registry():
 *    sets aside memory for an array of threads including args
 *       called by: main()
 *****************************************************************/

thread_registry_t *setup_thread_registry(FILE *fp_mylogfile, Coordinator *C_p)
{
  thread_registry_t *thread_bank;
  int i;

  thread_bank = (thread_registry_t *) malloc(NUMTHREADS * sizeof(thread_registry_t));

  for (i = 0; i < NUMTHREADS; ++i) {
    thread_bank[i].thr_num = i;
    thread_bank[i].fp_mylogfile = fp_mylogfile;
    thread_bank[i].C_p = C_p;
  }
  return thread_bank;
}


/*****************************************************************
 * cleanup_thread_registry():
 *    frees memory set aside by setup_thread_registry()
 *       called by: main()
 *****************************************************************/

void cleanup_thread_registry(thread_registry_t *thread_bank)
{
  free(thread_bank);
}


/*****************************************************************
 * get_time_string():
 *    returns current time as a formatted string
 *       called by: main(), thread_work(), write_status(),
 *                  complete_status_message(), does_file_exist()
 *****************************************************************/

char *get_time_string()
{
  static char time_string[TIME_LEN_MAX];
  time_t calendar_time;
  size_t len;

  time(&calendar_time);

  len = strftime(time_string, TIME_LEN_MAX -1, "%Y-%m-%d %H:%M:%S",
                 localtime(&calendar_time));

  time_string[len] = '\0'; 

  return time_string;
}
