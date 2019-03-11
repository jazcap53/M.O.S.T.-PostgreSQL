// File: AccessDb.cpp
// Modified: 1/17/2008  4:00a
// Andrew Jarcho
// Database access classes

#include "AccessDb.h"
#include "Coordinator.h"
#include <iostream>
#include <vector>
using namespace std;


// give us access to functions in the straight-C file
extern "C" {
  int add_available(const char *, int, const char *, const char *);
  int add_message(const char *, int, const char *, const char *);
  int add_message_recipient(int, const char *);
  int change_password(const char *, const char *, const char *);
  int delete_account(const char *);
  int delete_attendance(int, const char *);
  int delete_available(const char *, int, const char *, const char *);
  int delete_case(int);
  int delete_loginout(const char *);
  int do_login(const char *, const char *, int);
  int do_logout(const char *);
  int get_account_list(int, void(*)(ms_littleaccount_tuple));
  void get_attendance_list(int, void(*)(ms_attendance_tuple));
  void get_case_available_list_by_caseID(int, void(*)(ms_caseavailablelist_tuple));
  void get_case_available_list_by_logname(const char *, void(*)(ms_caseavailablelist_tuple));
  void get_case_document_list(int, void(*)(ms_casedoclist_tuple));
  void get_case_meeting_list(int, void(*)(ms_meeting_tuple));
  void get_case_role_list_by_logname(const char *, void(*)(ms_accountcaserole_tuple));
  ms_casestatus_tuple get_Case_Status_By_ID(int);
  ms_casetitle_tuple get_Case_Title_By_ID(int);
  void get_doc_access_list_by_doc_ID(int, void(*)(ms_docaccess_tuple));
  void get_doc_access_list_by_logname(const char *, void(*)(ms_docaccess_tuple));
  ms_meetingdocpair_tuple get_doc_ID_by_meeting_ID(int);
  ms_initialfinaldocid_tuple get_initial_and_final_doc_ID(int);
  void get_involved_in_case(int, void(*)(ms_involvedincase_tuple));
  ms_meeting_tuple get_meeting(int);
  void get_message_received_list(const char *, void(*)(ms_messagereceivedlist_tuple));
  void get_message_sent_recipient_list(const char *, void(*)(ms_messagesentrecipient_tuple));
  ms_getrole_tuple get_role(const char *, int);
  void get_signature_list_by_doc_ID_version(int, int, void(*)(ms_signature_tuple));
  void get_signed_version_list(const char *, int, void(*)(ms_signature_tuple));
  int is_logged_in(const char *);
  ms_littleaccount_tuple new_account(const char *, const char *, const char *);
  int new_account_case_role(const char *, int, const char *);
  int new_attendance(int, const char *);
  int new_case(const char *);
  int new_doc_access(int, const char *);
  int new_doc_signature(int, int, const char *, const char *);
  int new_document(const char *, const char *, const char *, int);
  int new_doc_version(int, const char *);
  int new_meeting(int, const char *, const char *);
  ms_messagereceived_tuple read_message_received(int, const char *);
  ms_messagesent_tuple read_message_sent(int, const char *);
  ms_account_tuple retrieve_account(const char *);
  ms_docversion_tuple retrieve_doc_for_edit(int);
  ms_docversion_tuple retrieve_doc_read_only(int, int);
  ms_initialfinaldoc_tuple retrieve_initial_and_final(int);
  int return_document(int);
  int store_initial_and_final(int, const char *, const char *);
  int store_meeting_document_pair(int, int);
  int update_account_info(const char *, const char *, const char *, char, const char *, const char *,
                                   const char *, const char *);
  int update_attendance_yn(int, const char *, char);
  int update_case_state(int, const char *);
  int update_meeting_status(int, const char *);
}

// static data member file scope declaration
// for Singleton pattern implementation

AccessDb *AccessDb::p_Access = 0;



//==========================================================================
//
// Member functions
// 
//==========================================================================

// add a meeting availability
// if availability added overlaps with an(y) existing availability,
//   merge them
// dates are accepted in just about any reasonable format
//   e.g. January 5, 2008 4:45pm <or> 6/5/2006 3:15am <or> 2008-3-06 12:45 PM
// returns:
//   2 for successful addition, overlapping tuple(s) removed
//   1 for successful addition
//   -1 for system error
//   -2 for end time <= start time
//   -3 for logname not associated with this case

int AccessDb::addAvailable(string logname, int caseID, string availStart,
			   string availEnd)
{
  return add_available(logname.c_str(), caseID, availStart.c_str(), 
		       availEnd.c_str());
}


// create a message
// returns:
//   new message ID for success
//   -1 for system error

int AccessDb::addMessage(string logname, int caseID, string subject, string body)
{
  return add_message(logname.c_str(), caseID, subject.c_str(), body.c_str());
}


// add a message recipient
// returns:
//   1 for success
//   -1 for system error
//   -2 for bad message ID
//   -3 for no such recipient
//   -4 for message already received

int AccessDb::addMessageRecipient(int messageID, string recipient)
{
  return add_message_recipient(messageID, recipient.c_str());
}


// change the password for a user
// returns: 1 for successful p/w change, 
//          0 if unsuccessful
//          -1 for error

int AccessDb::changePassword(string logname, string oldPassword, string newPassword)
{
  return change_password(logname.c_str(), oldPassword.c_str(), newPassword.c_str());
}


// delete an account (that has no other data associated with it)
// returns 1 for success
//        -1 for system error (e.g. other data depends on this account)
//        -5 for no such account

int AccessDb::deleteAccount(string logname)
{
  return delete_account(logname.c_str());
}


// delete an attendance (participant is *scheduled* to attend)
// returns 1 for success
//         0 for no such attendance found to delete
//         -1 for system error
//         -2 for no such meeting

int AccessDb::deleteAttendance(int meetingID, string logname)
{
  return delete_attendance(meetingID, logname.c_str());
}


// delete an availability
// if a fragment of time is left that is < 15 min, remove it
// returns:
//   1 for successful deletion
//   0 for nothing found to delete
//   -1 for system error
//   -2 for end time <= start time

int AccessDb::deleteAvailable(string logname, int caseID, string availStart,
			   string availEnd)
{
  return delete_available(logname.c_str(), caseID, availStart.c_str(), 
		       availEnd.c_str());
}


// remove a case from the database
// returns: 300 plus number of accounts deleted for successful removal of case
//            0 for case not found
//           -1 for system error
//           -2 for system or other error while getting account list
//           -3 for error deleting case: case not terminated or resolved
//           -4 for error deleting case: case resolved but no agreements on file
//           -5 for error deleting account: no such account (logname)
//           -6 for error deleting loginouts

int AccessDb::deleteCase(int caseID)
{
  int rv1, rv2, rv3, rv4;

  rv1 = rv2 = rv3 = rv4 = 0;

  rv1 = get_account_list(caseID, storeAccountListItem); 
  if (rv1 < 0)    
    return -2;                                                  // error

  rv2 = delete_case(caseID);                                    // delete everything but the (accounts) lognames from the db
  if (rv2 <= 0)                                                 // error
    return rv2;       

  for (vector<string>::const_iterator vsci = accountNames.begin(); vsci != accountNames.end() && rv3 > 0; ++vsci) {
    rv4 = delete_loginout(vsci->c_str());                       
  }
  if (rv4 < 0)
    return -6;


  for (vector<string>::const_iterator vsci = accountNames.begin(); vsci != accountNames.end() && rv3 > 0; ++vsci) {
    rv3 = delete_account(vsci->c_str());                       // delete the lognames from the db
  }
  accountNames.clear();       // empty the vector
  if (rv3 < 0)                // error
    return rv3;
  else
    return 300 + rv1;
}


// hands function sendAttendanceTuple to C code
// sendAttendanceTuple then sends us back a tuple

void AccessDb::doGetAttendanceList(int meetingID)
{
  get_attendance_list(meetingID, sendAttendanceTuple);
}


// hands function sendCaseAvailableTupleCase to C code
// sendCaseDAvailableTupleCase then sends us back a tuple

void AccessDb::doGetCaseAvailableListByCaseID(int caseID)
{
  get_case_available_list_by_caseID(caseID, sendCaseAvailableTupleCase);
}


// hands function sendCaseAvailableTupleLogname to C code
// sendCaseDAvailableTupleLogname then sends us back a tuple

void AccessDb::doGetCaseAvailableListByLogname(string logname)
{
  get_case_available_list_by_logname(logname.c_str(), sendCaseAvailableTupleLogname);
}


// hands function sendCaseDocTuple to C code
// sendCaseDocTuple then sends us back a tuple

void AccessDb::doGetCaseDocumentList(int caseID)
{
  get_case_document_list(caseID, sendCaseDocTuple);
}


// hands function sendMeetingTuple to C code
// sendMeetingTuple then sends us back a tuple

void AccessDb::doGetCaseMeetingList(int caseID)
{
  get_case_meeting_list(caseID, sendMeetingTuple);
}


// hands function sendAccountCaseRoleTuple to C code
// sendAccountCaseRoleTuple then sends us back a tuple

void AccessDb::doGetCaseRoleListByLogname(string logname)
{
  get_case_role_list_by_logname(logname.c_str(), sendAccountCaseRoleTuple);
}


// hands function sendDocAccessByDocIDTuple to C code
// sendDocAccessByDocIDTuple then sends us back a tuple

void AccessDb::doGetDocAccessListByDocID(int docID)
{
  get_doc_access_list_by_doc_ID(docID, sendDocAccessByDocIDTuple);
}


// hands function sendDocAccessByLognameTuple to C code
// sendDocAccessByLognameTuple then sends us back a tuple

void AccessDb::doGetDocAccessListByLogname(string logname)
{
  get_doc_access_list_by_logname(logname.c_str(), sendDocAccessByLognameTuple);
}


// hands function sendInvolvedTuple to C code
// sendInvolvedTuple then sends us back a tuple

void AccessDb::doGetInvolvedInCase(int caseID)
{
  get_involved_in_case(caseID, sendInvolvedTuple);
}


// hands function sendMessageTupleReceived to C code
// sendMessageTupleReceived then sends us back a tuple

void AccessDb::doGetMessageReceivedList(string recipient)
{
  get_message_received_list(recipient.c_str(), sendMessageTupleReceived);
}


// hands function sendMessageSentRecipientTuple to C code
// sendMessageSentRecipientTuple then sends us back a tuple

void AccessDb::doGetMessageSentRecipientList(string sender)
{
  get_message_sent_recipient_list(sender.c_str(), sendMessageSentRecipientTuple);
}


// hands function sendSignatureTuple to C code
// sendSignatureTuple then sends us back a tuple

void AccessDb::doGetSignatureListByDocIDVersion(int docID, int version)
{
  get_signature_list_by_doc_ID_version(docID, version, sendSignatureTuple);
}


// hands function sendSignedVersionTuple to C code
// sendSignedVersionTuple then sends us back a tuple

void AccessDb::doGetSignedVersionList(string logname, int docID)
{
  get_signed_version_list(logname.c_str(), docID, sendSignedVersionTuple);
}


// check that input logname/password pair is valid
// check that user is not logged in
// record the login
// returns 3 for logged in but not to any case
//         2 for already logged in to this case
//         1 for good new log in
//        -1 for system error
//        -2 for bad logname / password pair
//        -XXXX for must log out; already logged in to case XXXX

int AccessDb::doLogin(string logname, string password, int caseID)
{
  return do_login(logname.c_str(), password.c_str(), caseID);
}
 

// record a logout
// returns: 1 for good logout
//          0 for not logged in
//         -1 for system error 

int AccessDb::doLogout(string logname)
{
  return do_logout(logname.c_str());
}
 

// given a case ID, returns the current status of that case,
//   as well as the date of last status change
// success field of returned struct will be
//   1 for success
//   0 for no such case
//   -1 for system error

ms_casestatus_tuple AccessDb::getCaseStatusByID(int caseID)
{
  return get_Case_Status_By_ID(caseID);
}
			  

// given a case ID, returns the title of that case
// success field of returned struct will be
//   1 for success
//   0 for no such case
//   -1 for system error

ms_casetitle_tuple AccessDb::getCaseTitleByID(int caseID)
{
  return get_Case_Title_By_ID(caseID);
}
			  

// given a meeting ID, returns the ID of doc associated with that meeting
// success field of returned struct will be
//   docID for success
//   -1 for system error
//   -2 for no such meeting ID

ms_meetingdocpair_tuple AccessDb::getDocIDByMeetingID(int meetingID)
{
  return get_doc_ID_by_meeting_ID(meetingID);
}


// given a case ID, return the doc IDs of Preliminary and Final Agreements
// success field of returned struct will be
//    1 for success
//   -1 for system error
//   -2 for no such case
//   -3 for Preliminary Agreement not on file
//   -4 for Final Agreement not on file

ms_initialfinaldocid_tuple AccessDb::getInitialAndFinalDocID(int caseID)
{
  return get_initial_and_final_doc_ID(caseID);
}


// given a meeting ID, returns the data from that meeting
// (meetingID, caseID, start and end times, & status)
// success field of returned struct will be
//   1 for success
//   0 for no such meeting
//   -1 for system error

ms_meeting_tuple AccessDb::getMeeting(int meetingID)
{
  return get_meeting(meetingID);
}


// given a logname and a caseID, returns the role of that person in that case

ms_getrole_tuple AccessDb::getRole(string logname, int caseID)
{ 
  return get_role(logname.c_str(), caseID);
}


// given a logname, returns
//   caseID if user is logged in
//   0 for not logged in
//   -1 for error

int AccessDb::isLoggedIn(string logname)
{
  return is_logged_in(logname.c_str());
}


// set up a new account
// set logname to 1st initial, 1st 5 letters of last name,
//   and first available integer from 01 to 99, concatenated
// set password for new account to 'Default'
// newLogname is currently a dummy
// returns: 1 for successful addition of account
//          -99 for already have 99 people with that logname stem
//          -1 if other error

ms_littleaccount_tuple AccessDb::newAccount(string newLastName, string newFirstName, 
                            string newEmailAddress)
{
  return new_account(newLastName.c_str(), newFirstName.c_str(), newEmailAddress.c_str());
}


// associate an account, case, and role
// role must be 'Client', 'Mediator', 'Administrator'
// returns: 1 for success
//          -1 for failure

int AccessDb::newAccountCaseRole(string logname, int caseID, string role)
{
  return new_account_case_role(logname.c_str(), caseID, role.c_str());
}


// create new attendance
// returns: 1 for success, 
//          -2 for logname is not available during meeting time,
//          -3 for logname not associated with the case of the meeting

int AccessDb::newAttendance(int meetingID, string logname)
{
  return new_attendance(meetingID, logname.c_str());
}


// create a new case
// auto-create case number starting at 1000
// set case status to 'opened'
// returns: new case ID on success
//          -1 on failure 

int AccessDb::newCase(string newCaseTitle)
{
  return new_case(newCaseTitle.c_str());
}


// grant access to a particular doc to an individual
// docID: a valid docID
// returns: 1 for success
//          0 for failure

int AccessDb::newDocAccess(int docID, string logname)
{
  return new_doc_access(docID, logname.c_str());
}


// record the signing of a version of a document by a participant
// returns 1 for success
//         0 for doc version already signed by logname
//        -1 for sys error
//        -2 for no such document
//        -3 for no such version
//        -4 for logname does not have access to this document

int AccessDb::newDocSignature(int docID, int version, string logname, string sigPlace)
{
  return new_doc_signature(docID, version, logname.c_str(), sigPlace.c_str());
}


// create a new document
// auto-create doc number starting at 1
// type: up to 19 chars, should be a valid doc type (NOT YET enforced in db code)
// title: up to 39 chars, may be null (NOT YET enforced in db code)
// body: up to 29999 chars, may be null (NOT YET enforced in db code)
// returns: new doc ID if success, -1 if failure
// version number (1) supplied by db

int AccessDb::newDocument(string type, string title, string body, int caseID)
{
  return new_document(type.c_str(), title.c_str(), body.c_str(), caseID);
}


// create a new version of an existing document
// called by AccessDb::newDocument() as well as directly
// db creates new version number
// docID: the docID of an existing document
// title: up to 39 chars, may be null
// text: up to 29999 chars, may be null
// returns: new version number if success, -1 if failure
 
int AccessDb::newDocVersion(int docID, string text)
{
  return new_doc_version(docID, text.c_str());
}


// create a new meeting
// auto-create meeting number starting at 1
// set meeting status to 'open'
// returns: new meeting ID on success
//          -1 on failure 

int AccessDb::newMeeting(int caseID, string meetingStart, string meetingEnd)
{
  return new_meeting(caseID, meetingStart.c_str(), meetingEnd.c_str());
}


// send an ms_accountcaserole_tuple to Coordinator

void AccessDb::printAccountCaseRoleTuple(ms_accountcaserole_tuple toop)
{
  Coord_p->createCaseList(toop);
}


// send an ms_attendance_tuple to Coordinator 

void AccessDb::printAttendanceTuple(ms_attendance_tuple toop)
{
  Coord_p->createAttendanceList(toop);
}


// send an ms_caseavailablelist_tuple to Coordinator 

void AccessDb::printCaseAvailableTupleCase(ms_caseavailablelist_tuple toop)
{
  Coord_p->createAvailListbyCaseID(toop);
}


// send an ms_caseavailablelist_tuple to Coordinator 

void AccessDb::printCaseAvailableTupleLogname(ms_caseavailablelist_tuple toop)
{
  Coord_p->createAvailListbyLognam(toop);
}


// send an ms_casedoclist_tuple to Coordinator 

void AccessDb::printCaseDocTuple(ms_casedoclist_tuple toop)
{
  Coord_p->createDocList(toop);
}


// send an ms_docaccess_tuple to Coordinator

void AccessDb::printDocAccessByDocIDTuple(ms_docaccess_tuple toop)
{
  Coord_p->createDocAccessList(toop);
}


// send an ms_docaccess_tuple to Coordinator

void AccessDb::printDocAccessByLognameTuple(ms_docaccess_tuple toop)
{
  Coord_p->createDocAccessList(toop);
}


// send an ms_involvedincase_tuple to Coordinator 

void AccessDb::printInvolvedTuple(ms_involvedincase_tuple toop)
{
  Coord_p->createInvolvedList(toop);
}


// send an ms_meeting_tuple to Coordinator 

void AccessDb::printMeetingTuple(ms_meeting_tuple toop)
{
  Coord_p->createMeetingList(toop);
}


// send an ms_messagesentrecipient_tuple to Coordinator 

void AccessDb::printMessageSentRecipientTuple(ms_messagesentrecipient_tuple toop)
{
  Coord_p->createSentMsgList(toop);
}


// send an ms_message_tuple to Coordinator

void AccessDb::printMessageTupleReceived(ms_messagereceivedlist_tuple toop)
{
  Coord_p->createMessageList(toop);
}


// send an ms_signature_tuple to Coordinator

void AccessDb::printSignatureTuple(ms_signature_tuple toop)
{
  Coord_p->createDocSignatureList(toop);
}


// send an ms_signature_tuple to Coordinator

void AccessDb::printSignedVersionTuple(ms_signature_tuple toop)
{
  Coord_p->createDocSignatureList(toop);
}


// read a message received

ms_messagereceived_tuple AccessDb::readMessageReceived(int messageID, string reader)
{
  return read_message_received(messageID, reader.c_str());
}


// read a sent message

ms_messagesent_tuple AccessDb::readMessageSent(int messageID, string sender)
{
  return read_message_sent(messageID, sender.c_str());
}


// retrieve an account from database

ms_account_tuple AccessDb::retrieveAccount(string logname)
{
  return retrieve_account(logname.c_str());
}


// retrieve most recent version of a doc as editable
// docID: the doc ID of an existing document
// only the most recent version may be edited

ms_docversion_tuple AccessDb::retrieveDocForEdit(int docID)
{
  return retrieve_doc_for_edit(docID);
}


// retrieve a version of a document for read only
// if version is given as 0, retrieve most recent version
// otherwise retrieve specified version

ms_docversion_tuple AccessDb::retrieveDocReadOnly(int docID, int version)
{
  return retrieve_doc_read_only(docID, version);
}


// given a case number, retrieve the case number and Preliminary and Final Agreements
// r.v.: 1 for success, -1 for system error, -2 for not on file

ms_initialfinaldoc_tuple AccessDb::retrieveInitialAndFinal(int caseNum)
{
  return retrieve_initial_and_final(caseNum);
}


// return a document that was out for edit
// r.v.: 1 for success, 0 for doc not out, -1 for error
int AccessDb::returnDocument(int docID)
{
  return return_document(docID);
}


// set pointer to Coordinator object

void AccessDb::setCoordinatorPointer(Coordinator *C_p)
{
  Coord_p = C_p;
}


// store the initial and final agreements
// after successful resolution of dispute
// prior to destroying intermediate documents
// r.v: 1 for success
//     -1 for system error
//     -2 for docs already stored with that caseNum
//     -3 for no such case
//     -4 for case not resolved

int AccessDb::storeInitialAndFinal(int caseNumber, string initialAgreement, string finalAgreement)
{
  return store_initial_and_final(caseNumber, initialAgreement.c_str(), finalAgreement.c_str());
}


// stores a logname; preparatory to deleting a case from the database

void AccessDb::storeLogname(string logname)
{
  accountNames.push_back(logname);
}


// associate a meeting with a document

int AccessDb::storeMeetingDocumentPair(int meetingID, int documentID)
{
  return store_meeting_document_pair(meetingID, documentID);
}


// update account info
// returns 1 for success, -1 for error

int AccessDb::updateAccountInfo(string logname, string lastName, string firstName, char middleInitial,
                                string homePhone, string workPhone, string cellPhone, string email)
{
  return update_account_info(logname.c_str(), lastName.c_str(), firstName.c_str(), middleInitial,
                             homePhone.c_str(), workPhone.c_str(), cellPhone.c_str(), email.c_str());
}


// update whether a person scheduled to attend a meeting actually attended
// returns: 1 for success
//          0 for person was not scheduled to attend
//          -1 for system error
//          -2 for bad value for attendance (not y or n)
//          -3 for no such meeting

int AccessDb::updateAttendanceYN(int meetingID, string logname, char yesno)
{
  return update_attendance_yn(meetingID, logname.c_str(), yesno);
}


// enter a new case state
// returns 1 for success, -1 for error

int AccessDb::updateCaseState(int caseID, string newCaseState)
{
  return update_case_state(caseID, newCaseState.c_str());
}


// update the status of a meeting
// returns: 1 for success
//          0 for no such meeting or meeting cancelled
//          -1 for system error
//          -2 for bad value for status

int AccessDb::updateMeetingStatus(int meetingID, string meetingStatus)
{
  return update_meeting_status(meetingID, meetingStatus.c_str());
}


// implement the Singleton design pattern
// access point to the single instance of the class
AccessDb *AccessDb::Instance()
{
  if (p_Access == 0)
    p_Access = new AccessDb;

  return p_Access;
}




//==========================================================================
//
// Friend functions: each function sends a tuple back to the Coordinator
// 
//==========================================================================


void sendAccountCaseRoleTuple(ms_accountcaserole_tuple toop)
{
  AccessDb::Instance()->printAccountCaseRoleTuple(toop);
}


void sendAttendanceTuple(ms_attendance_tuple toop)
{
  AccessDb::Instance()->printAttendanceTuple(toop);
}


void sendCaseAvailableTupleCase(ms_caseavailablelist_tuple toop)
{
  AccessDb::Instance()->printCaseAvailableTupleCase(toop);
}


void sendCaseAvailableTupleLogname(ms_caseavailablelist_tuple toop)
{
  AccessDb::Instance()->printCaseAvailableTupleLogname(toop);
}


void sendCaseDocTuple(ms_casedoclist_tuple toop)
{
  AccessDb::Instance()->printCaseDocTuple(toop);
}


void sendDocAccessByDocIDTuple(ms_docaccess_tuple toop)
{
  AccessDb::Instance()->printDocAccessByDocIDTuple(toop);
}


void sendDocAccessByLognameTuple(ms_docaccess_tuple toop)
{
  AccessDb::Instance()->printDocAccessByLognameTuple(toop);
}


void sendInvolvedTuple(ms_involvedincase_tuple toop)
{
  AccessDb::Instance()->printInvolvedTuple(toop);
}


void sendMeetingTuple(ms_meeting_tuple toop)
{
  AccessDb::Instance()->printMeetingTuple(toop);
}


void sendMessageSentRecipientTuple(ms_messagesentrecipient_tuple toop)
{
  AccessDb::Instance()->printMessageSentRecipientTuple(toop);
}


void sendMessageTupleReceived(ms_messagereceivedlist_tuple toop)
{
  AccessDb::Instance()->printMessageTupleReceived(toop);
}


void sendSignatureTuple(ms_signature_tuple toop)
{
  AccessDb::Instance()->printSignatureTuple(toop);
}


void sendSignedVersionTuple(ms_signature_tuple toop)
{
  AccessDb::Instance()->printSignedVersionTuple(toop);
}


void storeAccountListItem(ms_littleaccount_tuple toop)
{
  string logname;

  if (toop.success == 1) {
    logname = toop.lognam;
    AccessDb::Instance()->storeLogname(logname);
  }
}
