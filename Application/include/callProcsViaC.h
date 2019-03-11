#ifndef CALL_PROCS_VIA_C_H
#define CALL_PROCS_VIA_C_H


/* file callProcsViaC.h
 * modified: 7/15/2007  2:00a
 */ 


#define     AGREEMENT_LEN         30500
#define     CASE_NAME_LEN         40
#define     CASE_STATUS_LEN       20
#define     CASE_TITLE_LEN        40
#define     DATE_LEN              40
#define     DOC_BODY_LEN          30000
#define     DOC_TITLE_LEN         40
#define     DOC_TYPE_LEN          20
#define     EMAIL_ADDR_LEN        100
#define     FIRST_NAME_LEN        30
#define     LAST_NAME_LEN         30
#define     LAST_NAME_PREFIX_LEN  5
#define     LOG_NAME_LEN          20
#define     MEET_STATUS_LEN       20
#define     MESSAGE_SUBJECT_LEN   80
#define     MESSAGE_BODY_LEN      2000
#define     PHONE_NUMBER_LEN      20
#define     ROLE_LEN              20
#define     SIGN_PLACE_LEN        40
#define     TARGET_LEN            40


/* Define constants for VARCHAR lengths. */
#define     PWD_LEN            40
#define     UNAME_LEN          20



typedef struct
{
  char lastnm[LAST_NAME_LEN];
  char firstnm[FIRST_NAME_LEN];
  char midinit;
  char homephn[PHONE_NUMBER_LEN];
  char workphn[PHONE_NUMBER_LEN];
  char cellphn[PHONE_NUMBER_LEN];
  char eml[EMAIL_ADDR_LEN];
  int success;
} ms_account_tuple;


typedef struct
{
  char lognam[LOG_NAME_LEN];
  int casID;
  char rol[ROLE_LEN];
  int success;
} ms_accountcaserole_tuple;


typedef struct
{
  int mID;
  char lognam[LOG_NAME_LEN];
  char presnt;
  int success;
} ms_attendance_tuple;


typedef struct
{
  int casID;
  char lognam[LOG_NAME_LEN];
  char avlStart[DATE_LEN];
  char avlEnd[DATE_LEN];
  int success;
} ms_caseavailablelist_tuple;


typedef struct
{
  int dID;
  char typ[DOC_TYPE_LEN];
  char titl[DOC_TITLE_LEN ];
  char dout;
  int vcount;
  int success;
} ms_casedoclist_tuple;


typedef struct
{
  char casStatus[CASE_STATUS_LEN];
  char statusDt[DATE_LEN];
  int success;
} ms_casestatus_tuple;


typedef struct
{
  char casTitl[CASE_TITLE_LEN];
  int success;
} ms_casetitle_tuple;


typedef struct
{
  int dID;
  char lognam[LOG_NAME_LEN];
  int success;
} ms_docaccess_tuple;


typedef struct
{
  int dID;
  int versn;
  char dtcreated[DATE_LEN];
  char titl[DOC_TITLE_LEN];
  char bod[DOC_BODY_LEN];
  char editble;
  int success;
} ms_docversion_tuple;


typedef struct
{
  char rol[ROLE_LEN];
  int success;
} ms_getrole_tuple;


typedef struct
{
  int cID;
  int initDID;
  int initVer;
  int finDID;
  int finVer;
  int success;
} ms_initialfinaldocid_tuple;


typedef struct
{
  int cNum;
  char initAgr[AGREEMENT_LEN];
  char finAgr[AGREEMENT_LEN];
  int success;
} ms_initialfinaldoc_tuple;


typedef struct
{
  char lognm[LOG_NAME_LEN];
  char lastnm[LAST_NAME_LEN];
  char firstnm[FIRST_NAME_LEN];
  char rol[ROLE_LEN];
  char emal[EMAIL_ADDR_LEN];
  int success;
} ms_involvedincase_tuple;


typedef struct
{
  char lognam[LOG_NAME_LEN];
  int success;
} ms_littleaccount_tuple;


typedef struct
{
  int mID;
  int cID;
  char meetStart[DATE_LEN];
  char meetEnd[DATE_LEN];
  char meetStatus[MEET_STATUS_LEN];
  int success;
} ms_meeting_tuple;


typedef struct
{
  int meetID;
  int dID;
  int success;
} ms_meetingdocpair_tuple;


typedef struct
{
  int messID;
  int cID;
  char recip[LOG_NAME_LEN];
  char sendr[LOG_NAME_LEN];
  char subj[MESSAGE_SUBJECT_LEN];
  char bod[MESSAGE_BODY_LEN];
  char timsent[DATE_LEN];
  char red;
  int success;
} ms_messagereceived_tuple;


typedef struct
{
  int messID;
  int cID;
  char recip[LOG_NAME_LEN];
  char sendr[LOG_NAME_LEN];
  char subj[MESSAGE_SUBJECT_LEN];
  char timsent[DATE_LEN];
  char red;
  int success;
} ms_messagereceivedlist_tuple;


typedef struct
{
  int messID;
  int cID;
  char sendr[LOG_NAME_LEN];
  char bod[MESSAGE_BODY_LEN];
  int success;
} ms_messagesent_tuple;


typedef struct
{
  int messID;
  int cID;
  char recip[LOG_NAME_LEN];
  char sendr[LOG_NAME_LEN];
  char timsent[DATE_LEN];
  char subj[MESSAGE_SUBJECT_LEN];
  char red;
  char timread[DATE_LEN];
  int success;
} ms_messagesentrecipient_tuple;
 

typedef struct
{
  int dID;
  int versn;
  char signr[LOG_NAME_LEN];
  char signdt[DATE_LEN];
  char signplc[SIGN_PLACE_LEN];
  int success;
} ms_signature_tuple;


#endif
