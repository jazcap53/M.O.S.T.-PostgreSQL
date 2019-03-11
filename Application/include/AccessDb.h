#ifndef ACCESSDB_H
#define ACCESSDB_H

// File: AccessDb.h
// Modified 1/17/2009  4:30a
// Andrew Jarcho
// Database access class header file

// Provides: a Singleton class to retrieve data from the database
//           callbacks via friend functions retrieve >1 tuple
// For documentation see AccessDb.cpp


#include <string>
#include <vector>
#include "callProcsViaC.h"

class Coordinator;

class AccessDb 
{
public:
  static AccessDb *Instance();

  //  member functions
   int addAvailable(std::string, int, std::string, std::string);
   int addMessage(std::string, int, std::string, std::string);
   int addMessageRecipient(int, std::string);
   int changePassword(std::string, std::string, std::string);
   int deleteAccount(std::string);
   int deleteAttendance(int, std::string);
   int deleteAvailable(std::string, int, std::string, std::string);
   int deleteCase(int);
   void doGetAttendanceList(int);
   void doGetCaseAvailableListByCaseID(int);
   void doGetCaseAvailableListByLogname(std::string);
   void doGetCaseDocumentList(int);
   void doGetCaseMeetingList(int);
   void doGetCaseRoleListByLogname(std::string);
   void doGetDocAccessListByDocID(int);
   void doGetDocAccessListByLogname(std::string);
   void doGetInvolvedInCase(int);
   void doGetMessageReceivedList(std::string);
   void doGetMessageSentRecipientList(std::string);
   void doGetSignatureListByDocIDVersion(int, int);
   void doGetSignedVersionList(std::string, int);
   int doLogin(std::string, std::string, int);
   int doLogout(std::string);
   ms_casestatus_tuple getCaseStatusByID(int);
   ms_casetitle_tuple getCaseTitleByID(int);
   ms_meetingdocpair_tuple getDocIDByMeetingID(int);
   ms_initialfinaldocid_tuple getInitialAndFinalDocID(int);
   ms_meeting_tuple getMeeting(int);
   ms_getrole_tuple getRole(std::string, int);
   int isLoggedIn(std::string);
   ms_littleaccount_tuple newAccount(std::string, std::string, std::string);
   int newAccountCaseRole(std::string, int, std::string);
   int newAttendance(int, std::string);
   int newCase(std::string);
   int newDocAccess(int, std::string);
   int newDocSignature(int, int, std::string, std::string);
   int newDocument(std::string, std::string, std::string, int);
   int newDocVersion(int, std::string);
   int newMeeting(int, std::string, std::string);
   ms_messagereceived_tuple readMessageReceived(int, std::string);
   ms_messagesent_tuple readMessageSent(int, std::string);
   ms_account_tuple retrieveAccount(std::string);
   ms_docversion_tuple retrieveDocForEdit(int);
   ms_docversion_tuple retrieveDocReadOnly(int, int);
   ms_initialfinaldoc_tuple retrieveInitialAndFinal(int);
   int returnDocument(int);
   void setCoordinatorPointer(Coordinator *);
   int storeInitialAndFinal(int, std::string, std::string);
   void storeLogname(std::string);
   int storeMeetingDocumentPair(int, int);
   int updateAccountInfo(std::string, std::string, std::string, char, std::string, std::string, 
                               std::string, std::string);
   int updateAttendanceYN(int, std::string, char);
   int updateCaseState(int, std::string);
   int updateMeetingStatus(int, std::string);

  // friend functions
  friend void sendAccountCaseRoleTuple(ms_accountcaserole_tuple);
  friend void sendAttendanceTuple(ms_attendance_tuple);
  friend void sendCaseAvailableTupleCase(ms_caseavailablelist_tuple);
  friend void sendCaseAvailableTupleLogname(ms_caseavailablelist_tuple);
  friend void sendCaseDocTuple(ms_casedoclist_tuple);
  friend void sendDocAccessByDocIDTuple(ms_docaccess_tuple);
  friend void sendDocAccessByLognameTuple(ms_docaccess_tuple);
  friend void sendInvolvedTuple(ms_involvedincase_tuple);
  friend void sendMeetingTuple(ms_meeting_tuple);
  friend void sendMessageSentRecipientTuple(ms_messagesentrecipient_tuple);
  friend void sendMessageTupleReceived(ms_messagereceivedlist_tuple);
  friend void sendSignatureTuple(ms_signature_tuple);
  friend void sendSignedVersionTuple(ms_signature_tuple);
  friend void storeAccountListItem(ms_littleaccount_tuple);

private:
  AccessDb() {}

  static AccessDb *p_Access;

  //  data member
   Coordinator *Coord_p;  
   std::vector<std::string> accountNames;

   void printAccountCaseRoleTuple(ms_accountcaserole_tuple);
   void printAttendanceTuple(ms_attendance_tuple);
   void printCaseAvailableTupleCase(ms_caseavailablelist_tuple);
   void printCaseAvailableTupleLogname(ms_caseavailablelist_tuple);
   void printCaseDocTuple(ms_casedoclist_tuple);
   void printDocAccessByDocIDTuple(ms_docaccess_tuple);
   void printDocAccessByLognameTuple(ms_docaccess_tuple);
   void printInvolvedTuple(ms_involvedincase_tuple);
   void printMeetingTuple(ms_meeting_tuple);
   void printMessageSentRecipientTuple(ms_messagesentrecipient_tuple);
   void printMessageTupleReceived(ms_messagereceivedlist_tuple);
   void printSignatureTuple(ms_signature_tuple);
   void printSignedVersionTuple(ms_signature_tuple);
};

#endif
