-- file: createProcedures2.sql
-- modified: 9/5/07 10:30p 
 
-- ------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------

-- FUNCTIONS CREATED

-- ms_addAvailable(lognam VARCHAR, casID INTEGER, avlStart TIMESTAMP WITH TIME ZONE, avlEnd TIMESTAMP WITH TIME ZONE) RETURNS INTEGER
-- ms_deleteAvailable(lognam VARCHAR, casID INTEGER, notAvlStart TIMESTAMP WITH TIME ZONE, notAvlEnd TIMESTAMP WITH TIME ZONE) RETURNS INTEGER
-- ms_newMeeting(casID INTEGER, meetStart TIMESTAMP WITH TIME ZONE, meetEnd TIMESTAMP WITH TIME ZONE) RETURNS INTEGER
-- ms_newAttendance(meetID INTEGER, lognam VARCHAR) RETURNS INTEGER
-- ms_deleteAttendance(meetID INTEGER, lognam VARCHAR) RETURNS INTEGER
-- ms_updateMeetingStatus(meetID INTEGER, meetStatus VARCHAR) RETURNS INTEGER
-- ms_updateAttendanceYN(meetID INTEGER, lognam VARCHAR, yesno CHAR) RETURNS INTEGER
-- ms_addMessage(sender VARCHAR, caseID INTEGER, subject VARCHAR, body VARCHAR) RETURNS INTEGER
-- ms_addMessageRecipient(messID INTEGER, recipient VARCHAR) RETURNS INTEGER
-- ms_readMessageReceived(messID INTEGER, lognam VARCHAR) RETURNS MS_MESSAGERECEIVED_TUPLE
-- ms_readMessageSent(messID INTEGER, lognam VARCHAR) RETURNS MS_MESSAGESENT_TUPLE
-- ms_storeMeetingDocumentPair(meetID INTEGER, dID INTEGER) RETURNS INTEGER
-- ms_getDocIDByMeetingID(meetID INTEGER) RETURNS INTEGER
-- ms_lognameFree(lognam VARCHAR) RETURNS INTEGER
-- ms_storeInitialAndFinal(caseNum INTEGER, initialAgr VARCHAR, finalAgr VARCHAR) RETURNS INTEGER
-- ms getInitialAndFinalDocID(caseID INTEGER) RETURNS MS_INITIALFINALDOCID_TUPLE
-- ms_retrieveInitialAndFinal(caseNum INTEGER) RETURNS MS_INITIALFINALDOC_TUPLE
-- ms_deleteCase(cID INTEGER) RETURNS INTEGER
-- ms_deleteAccount(accountName VARCHAR) RETURNS INTEGER
-- ms_deleteLoginout(lognam VARCHAR) RETURNS INTEGER

-- ------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------

-- add an availability to the ms_available table
-- if the availability to be added overlaps any that already exist, merge them

-- returns -3 if logname is not associated with this case
--         -2 if availability ends before start
--         -1 for system error
--         1 for successful insert
--         2 for successful insert, with extension of existing tuple(s)

-- FIX: make sure calling function rolls back incomplete transactions

CREATE OR REPLACE FUNCTION ms_addAvailable(lognam VARCHAR, casID INTEGER,
  avlStart TIMESTAMP WITH TIME ZONE, avlEnd TIMESTAMP WITH TIME ZONE) RETURNS INTEGER AS $$

DECLARE
  result INTEGER;
  overlp INTEGER;
  oneline RECORD;
  avlMin TIMESTAMP WITH TIME ZONE;
  avlMax TIMESTAMP WITH TIME ZONE;
  rightCase INTEGER;

BEGIN
  IF avlEnd <= avlStart THEN
    RETURN -2;
  END IF;

  -- don't allow system to schedule someone for a case they're not involved in
  SELECT COUNT (*) INTO rightCase
  FROM ms_accountcaserole
  WHERE logname = lognam AND
        caseid = casID;

  IF rightCase = 0 THEN           -- logname not involved in this case
    RETURN -3;
  ELSIF rightCase > 1 THEN        -- sys error
    RETURN -1;
  END IF;

  avlMin = 'infinity';
  avlMax = '-infinity';


  SELECT COUNT (*) INTO overlp    -- count lines that overlap input availability
  FROM ms_available
  WHERE logname = lognam AND
        caseID = casID AND
        (((avlStart, avlEnd) OVERLAPS (availStart, availEnd)) OR avlEnd = availStart OR avlStart = availEnd);

  IF overlp = 0 THEN              -- if there are no overlaps, just insert the tuple
    INSERT INTO ms_available(logname, caseID, availStart, availEnd)
    VALUES (lognam, casID, avlStart, avlEnd);
    RETURN 1;
  ELSE                            -- but if there are overlaps

    FOR oneline IN SELECT *       -- for each overlapping tuple
                   FROM ms_available
		   WHERE logname = lognam AND
                         caseID = casID AND
                         (((avlStart, avlEnd) OVERLAPS (availStart, availEnd)) OR
                            avlEnd = availStart OR avlStart = availEnd) LOOP

      IF avlStart < avlMin THEN       -- get the earliest start time
          avlMin := avlStart;
      END IF;
      IF oneline.availStart < avlMin THEN
          avlMin := oneline.availStart;
      END IF;

      IF avlEnd > avlMax THEN         -- get the latest end time
        avlMax := avlEnd;
      END IF;
      IF oneline.availEnd > avlMax THEN
        avlMax := oneline.availEnd;
      END IF;
    END LOOP;

    DELETE FROM ms_available            -- get rid of the overlapping tuple(s)
    WHERE logname = lognam AND
          caseID = casID AND
          (((avlStart, avlEnd) OVERLAPS (availStart, availEnd)) OR avlEnd = availStart OR avlStart = availEnd);

    INSERT INTO ms_available(logname, caseID, availStart, availEnd)   -- insert an extended tuple
    VALUES (lognam, casID, avlMin, avlMax);

    RETURN 2;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;

END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- remove an availability from the ms_available table
-- if user is scheduled to attend a meeting during this availability,
--    refuse to remove it
-- split existing availability in two when necessary
-- delete any left over segments < 15 minutes

-- return 1 for removed successfully
--        0 for nothing found to remove
--        -1 for system error
--        -2 for availability to be removed ends before starting
--        -3 for meeting scheduled during availability to be deleted
--           which lognam is supposed to attend

CREATE OR REPLACE FUNCTION ms_deleteAvailable(lognam VARCHAR, casID INTEGER,
  notAvlStart TIMESTAMP WITH TIME ZONE, notAvlEnd TIMESTAMP WITH TIME ZONE) RETURNS INTEGER AS $$

DECLARE
  removed INTEGER;
  overlapFound INTEGER;
  oneline RECORD;
  newAvlOneStart TIMESTAMP WITH TIME ZONE;
  newAvlOneEnd TIMESTAMP WITH TIME ZONE;
  newAvlTwoStart TIMESTAMP WITH TIME ZONE;
  newAvlTwoEnd TIMESTAMP WITH TIME ZONE;
  cantDelete INTEGER;

BEGIN
  IF notAvlEnd <= notAvlStart THEN
    RETURN -2;
  END IF;

  newAvlOneStart := NULL;
  newAvlOneEnd := NULL;
  newAvlTwoStart := NULL;
  newAvlTwoEnd := NULL;
  overlapFound := 0;
  cantDelete := 0;

  -- check if theres a meeting scheduled during the availability to be deleted
  -- which lognam is supposed to attend
  SELECT COUNT (*)
  INTO cantDelete
  FROM ms_meeting M, ms_attendance A
  WHERE A.logname = lognam  AND
        A.meetingID = M.meetingID AND
        (M.meetingStart, M.meetingEnd) OVERLAPS (notAvlStart, notAvlEnd) AND
	M.meetingStatus <> 'Cancelled';        
	
  -- if so, refuse to delete the availability, and return
  IF (cantDelete > 0) THEN 
    RETURN -3;
  END IF;

  FOR oneline IN SELECT *                                                        -- for each overlapping tuple
                 FROM ms_available
	         WHERE logname = lognam AND
                       caseID = casID AND
                       (notAvlStart, notAvlEnd) OVERLAPS (availStart, availEnd) LOOP

    IF notAvlStart > oneline.availStart AND notAvlEnd < oneline.availEnd THEN       -- break stored availibility in two
      newAvlOneStart := oneline.availStart;
      newAvlOneEnd := notAvlStart;
      newAvlTwoStart := notAvlEnd;
      newAvlTwoEnd := oneline.availEnd; 
    ELSIF notAvlStart <= oneline.availStart AND notAvlEnd >= oneline.availEnd THEN  -- delete this stored availability
      NULL;
    ELSIF notAvlStart > oneline.availStart AND notAvlEnd >= oneline.availEnd THEN   -- keep the left segment
      newAvlOneStart := oneline.availStart;
      newAvlOneEnd := notAvlStart;
    ELSIF notAvlStart <= oneline.availStart AND notAvlEnd < oneline.availEnd THEN   -- keep the right segment 
      newAvlTwoStart := notAvlEnd;
      newAvlTwoEnd := oneline.availEnd;
    END IF; 
    overlapFound := 1;

  END LOOP;

    -- if we're trying to delete an availability that isn't there, return
    IF overlapFound = 0 THEN
      RETURN 0;
    END IF;

    DELETE FROM ms_available            -- get rid of the overlapping tuple(s)
    WHERE logname = lognam AND
          caseID = casID AND
          (notAvlStart, notAvlEnd) OVERLAPS (availStart, availEnd);

    -- re-insert any leftover pieces
    IF newAvlOneStart IS NOT NULL THEN
      INSERT INTO ms_available(logname, caseID, availStart, availEnd)   -- insert a truncated availability
      VALUES (lognam, casID, newAvlOneStart, newAvlOneEnd);
    END IF;

    IF newAvlTwoStart IS NOT NULL THEN
      INSERT INTO ms_available(logname, caseID, availStart, availEnd)   -- insert a truncated availability
      VALUES (lognam, casID, newAvlTwoStart, newAvlTwoEnd);
    END IF;

    DELETE FROM ms_available                                            -- delete any segments < 15 minutes
    WHERE logname = lognam AND
          caseID = casID AND
          (availEnd - availStart) < '00:15:00'; 

    RETURN 1; 

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;

END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new meeting 
-- status created as 'Open'
-- return: new meeting ID on success
--         -1 for error

CREATE OR REPLACE FUNCTION ms_newMeeting(casID INTEGER, meetStart TIMESTAMP WITH TIME ZONE, meetEnd TIMESTAMP WITH TIME ZONE) 
                                                                                                           RETURNS INTEGER AS $$

DECLARE
  newMeetingID INTEGER;

BEGIN
  newMeetingID := 0;

  IF meetStart >= meetEnd THEN    -- meeting ends before it starts: error
    RETURN -1;
  END IF;

  INSERT INTO ms_meeting (meetingID, caseID, meetingStart, meetingEnd, meetingStatus)
  values (nextval('ms_meetingIDSeq'), casID, meetStart, meetEnd, 'Open');

  SELECT currval('ms_meetingIDSeq')
  INTO newMeetingID;

  RETURN newMeetingID;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create a new attendance
-- (associate a logname with a meetingID)
-- return: 1 for successfully created new attendance
--         -1 for system error
--         -2 if logname is not available at the meeting time
--         -3 for logname not involved in case that meeting belongs to

CREATE OR REPLACE FUNCTION ms_newAttendance(meetID INTEGER, lognam VARCHAR) RETURNS INTEGER AS $$

DECLARE 
  availExists INTEGER;
  rightCase INTEGER;

BEGIN
  availExists := 0;
  rightCase := 0;

  SELECT COUNT (*)     -- check logname is involved in case
  INTO rightCase
  FROM ms_accountcaserole ACR, ms_account AC, ms_meeting M
  WHERE ACR.logname = lognam AND
        AC.logname = ACR.logname AND
        M.meetingID = meetID AND
        M.caseID =ACR.caseID;

  IF (rightCase = 0) THEN
    RETURN -3;
  END IF;  

  SELECT COUNT (*)     -- check logname is available for meeting
  INTO availExists
  FROM ms_available AV, ms_account AC, ms_accountcaserole ACR, ms_meeting M
  WHERE M.meetingID = meetID AND 
        AC.logname = lognam AND
        AV.logname = AC.logname AND
        AV.availStart <= M.meetingStart AND
        AV.availEnd >= M.meetingEnd AND
        M.caseID = ACR.caseID;

  IF (availExists = 0) THEN
    RETURN -2;  
  END IF;

  INSERT INTO ms_attendance(meetingID, logname)   -- insert the attendance
  VALUES (meetID, lognam);

  RETURN 1;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- remove an entry from the ms_attendance table
-- (a user is *not* going to attend a meeting)

-- returns: 1 for success
--          0 for no such entry
--          -1 for system error
--	    -2 for no such meeting

CREATE OR REPLACE FUNCTION ms_deleteAttendance(meetID INTEGER, lognam VARCHAR) RETURNS INTEGER AS $$

DECLARE
  attendanceExists INTEGER;
  meetingExists INTEGER;

BEGIN
  SELECT COUNT (*)     -- check meeting exists
  INTO meetingExists
  FROM ms_meeting
  WHERE meetingID = meetID;
                
  IF meetingExists = 0 THEN
    RETURN -2;
  END IF;

  SELECT COUNT (*)    -- check attendance exists
  INTO attendanceExists
  FROM ms_attendance
  WHERE meetingID = meetID AND
        logname = lognam;

  IF attendanceExists = 0 THEN
    RETURN 0;
  END IF;

  DELETE FROM ms_attendance    -- delete the attendance
  WHERE meetingID = meetID AND
        logname = lognam;

  RETURN 1;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
  
-- mark a meeting as open, held, or cancelled

-- returns: 1 for success
--          0 for no such meeting or has been cancelled
--          -1 for system error
--          -2 for invalid meeting status

CREATE OR REPLACE FUNCTION ms_updateMeetingStatus(meetID INTEGER, meetStatus VARCHAR) RETURNS INTEGER AS $$

DECLARE
  meetingExists INTEGER;
  wasCancelled INTEGER;

BEGIN
  SELECT COUNT (*)  -- check meeting exists and has not been cancelled
  INTO meetingExists
  FROM ms_meeting
  WHERE meetingID = meetID AND
        meetingStatus <> 'Cancelled';

  IF meetingExists = 0 THEN
    RETURN 0;
  END IF;

  -- check we are passing a good value for meeting status
  IF meetStatus <> 'Open' AND meetStatus <> 'Held' AND meetStatus <> 'Cancelled' THEN 
    RETURN -2;
  END IF;

  UPDATE ms_meeting   -- update the meeting status
  SET meetingStatus = meetStatus
  WHERE meetingID = meetID;

  RETURN 1;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- mark logname as attended or not attended meeting
-- check meeting exists
-- check logname was scheduled to attend

-- returns: 1 for success
--          0 for no such attendance
--          -1 for system error
--          -2 for bad value for yes/no
--          -3 for no such meeting

CREATE OR REPLACE FUNCTION ms_updateAttendanceYN(meetID INTEGER, lognam VARCHAR, yesno CHAR) RETURNS INTEGER AS $$

DECLARE
  attendanceExists INTEGER;
  meetingExists INTEGER;

BEGIN
  SELECT COUNT (*)        -- check attendance exists
  INTO attendanceExists
  FROM ms_attendance
  WHERE meetingID = meetID AND
        logname = lognam;

  IF attendanceExists = 0 THEN
    RETURN 0;
  END IF;

  SELECT count(*)       -- check meeting has happened
  INTO meetingExists
  FROM ms_meeting
  WHERE meetingID = meetID AND
        meetingStatus = 'Held';
          
  IF meetingExists < 1 THEN
    RETURN -3;
  END IF;

  IF yesno <> 'y' AND yesno <> 'n' AND yesno IS NOT NULL THEN   -- check good value for yes/no
    RETURN -2;
  END IF;

  UPDATE ms_attendance            -- save the data
  SET present = yesno
  WHERE meetingID = meetID AND
        logname = lognam;
 
  RETURN 1;

  EXCEPTION
    WHEN OTHERS THEN 
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create a new message
-- sendr, sender are sender logname
-- body and/or subject may be null
-- returns: new message ID for success
--          -1 for system error
--          -2 for bad logname, caseID

CREATE OR REPLACE FUNCTION ms_addMessage(sendr VARCHAR, casID INTEGER, subj VARCHAR, bod VARCHAR) RETURNS INTEGER AS $$

DECLARE
  retval INTEGER;
  subjEntry VARCHAR;
  bodEntry VARCHAR;
  goodCasID INTEGER;

BEGIN
  SELECT COUNT(*)             -- check logname, caseID are good
  INTO goodCasID
  FROM ms_accountCaseRole
  WHERE caseID = casID AND
        logname = sendr;

  IF goodCasID = 0 THEN
    RETURN -2;
  END IF;
  
  IF subj = 'NULL' THEN       -- if no subject line
    subjEntry := null;        
  ELSE
    subjEntry := subj;
  END IF;

  IF bod = 'NULL' THEN        -- if empty body
    bodEntry := null;
  ELSE
    bodEntry := bod;
  END IF;

  -- save the data
  INSERT INTO ms_messageSent(messageID, caseID, sender, timeSent, subject, body)
  VALUES (nextval('ms_messageIDSeq'), casID, sendr, CURRENT_TIMESTAMP, subjEntry, bodEntry);


  SELECT currval('ms_messageIDSeq')    -- return the new message id
  INTO retval;

  RETURN retval;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- add a recipient for a message
-- recip, recipient are recipient logname
-- returns: 1 for success
--          -1 for system error
--          -2 for bad message ID
--          -3 for no such recipient
--          -4 for recipient already has message

CREATE OR REPLACE FUNCTION ms_addMessageRecipient(messID INTEGER, recip VARCHAR) RETURNS INTEGER AS $$

DECLARE
  messageExists INTEGER;
  goodRecipient INTEGER;  
  sameCase INTEGER;

BEGIN
  SELECT COUNT (*)
  INTO messageExists
  FROM ms_messageSent
  WHERE messageID = messID;

  IF messageExists = 0 THEN
    RETURN -2;    -- no such message
  END IF;

  SELECT COUNT (*)
  INTO goodRecipient
  FROM ms_account
  WHERE  logname = recip;

  IF goodRecipient = 0 THEN
    RETURN -3;    -- no such recipient
  END IF;

  SELECT COUNT (*)
  INTO sameCase
  FROM ms_messageSent MS, ms_accountcaserole ACR
  WHERE MS.messageID = messID AND
        ACR.logname = recip AND
        MS.caseID = ACR.caseID;

  IF sameCase = 0 THEN
    RETURN -3;   -- bad recipient
  END IF;

  INSERT INTO ms_messageRecipient(messageID, recipient, read)
  VALUES (messID, recip, 'n');

  RETURN 1;

  EXCEPTION
    WHEN UNIQUE_VIOLATION THEN
      RETURN -4;   -- recipient already received this message

    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- read a message received

-- returns tuple with success field set to 
--          1 for success
--          -1 for system error
--          -2 for bad message ID
--          -3 for reader not a recipient

DROP TYPE ms_messagereceived_tuple CASCADE;

CREATE TYPE ms_messagereceived_tuple AS (
  messID INTEGER,
  cID INTEGER, 
  recip VARCHAR,
  sendr VARCHAR,
  subj VARCHAR,
  bod VARCHAR,
  timsent TIMESTAMP WITH TIME ZONE,
  red CHAR,
  success INTEGER);


CREATE OR REPLACE FUNCTION ms_readMessageReceived(mstsMessageID INTEGER, reader VARCHAR) RETURNS ms_messagereceived_tuple AS $$

DECLARE
  result MS_MESSAGERECEIVED_TUPLE;
  messageExists INTEGER;
  messageReceived INTEGER;
  subjectIn VARCHAR;
  bodyIn VARCHAR;
  alreadyRead CHAR;

BEGIN
  subjectIn := null;
  bodyIn := null;

  SELECT COUNT (*) 
  INTO messageExists
  FROM ms_messageSent
  WHERE messageID = mstsMessageID;

  IF messageExists = 0 THEN
    result.success =  -2;
    RETURN result;
  END IF;

  SELECT COUNT (*)
  INTO messageReceived
  FROM ms_messageRecipient
  WHERE messageID = mstsMessageID AND
        recipient = reader;

  IF messageReceived = 0 THEN
    result.success =  -3;
    RETURN result;
  END IF;

  SELECT read
  INTO alreadyRead
  FROM ms_messageRecipient
  WHERE messageID = mstsMessageID AND
        recipient = reader;

  IF alreadyRead = 'n' THEN
    UPDATE ms_messageRecipient
    SET read = 'y', timeread = CURRENT_TIMESTAMP
    WHERE messageID = mstsMessageID AND
          recipient = reader;
  END IF;

  SELECT S.messageID, S.caseID, R.recipient, S.sender, S.subject, S.body, S.timesent, R.read, 1
  INTO result.messID, result.cID, result.recip, result.sendr, subjectIn, bodyIn, result.timsent,
       result.red, result.success
  FROM ms_messageSent S, ms_messageRecipient R
  WHERE S.messageID = mstsMessageID AND
        S.messageID = R.messageID AND
        R.recipient = reader; 

  IF subjectIn IS NULL THEN    -- handle null value for subject
    result.subj := 'NULL';
  ELSE
    result.subj := subjectIn;
  END IF;

  IF bodyIn IS NULL THEN      -- handle null value for body
    result.bod := 'NULL';
  ELSE
    result.bod := bodyIn;
  END IF;

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success = -1;
    RETURN  result;

END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- create type to return the data we need

DROP TYPE ms_messagesent_tuple CASCADE;

CREATE TYPE ms_messagesent_tuple AS (
  messID   INTEGER,
  cID      INTEGER,
  sendr    VARCHAR,
  bod      VARCHAR,
  success  INTEGER);


-- read a sent message

-- returns tuple with success field set to 
--          1 for success
--          -1 for system error
--          -2 for bad message ID
--          -3 for reader not sender

CREATE OR REPLACE FUNCTION  ms_readMessageSent(messID INTEGER, readr VARCHAR) RETURNS MS_MESSAGESENT_TUPLE AS $$

DECLARE
  result MS_MESSAGESENT_TUPLE;
  messageExists INTEGER;
  messageSent INTEGER;
  bodyIn VARCHAR;

BEGIN

  SELECT COUNT (*) 
  INTO messageExists
  FROM ms_messageSent
  WHERE messageID = messID;

  IF messageExists = 0 THEN
    result.success =  -2;
    RETURN result;
  END IF;

  SELECT COUNT (*)
  INTO messageSent
  FROM ms_messageSent
  WHERE messageID = messID AND
        sender = readr;

  IF messageSent = 0 THEN
    result.success =  -3;
    RETURN result;
  END IF;
 
  SELECT messageID, caseID, sender, body, 1
  INTO result.messID, result.cID, result.sendr, bodyIn, result.success
  FROM ms_messageSent
  WHERE messageID = messID AND
        sender = readr; 

  IF bodyIn IS NULL THEN      -- handle null value for body
    result.bod := 'NULL';
  ELSE
    result.bod := bodyIn;
  END IF;

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success = -1;
    RETURN  result;

END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
 
-- store a meetingID, documentID pair

-- return: 1 for success
--         -1 for system error
--         -2 for no such meetingID
--         -3 for no such docID

CREATE OR REPLACE FUNCTION ms_storeMeetingDocumentPair(meetID INTEGER, dID INTEGER) RETURNS INTEGER AS $$

DECLARE
  meetingExists INTEGER;
  documentExists INTEGER;
  
BEGIN
  SELECT COUNT (*)
  INTO meetingExists
  FROM ms_meeting
  WHERE meetingID = meetID;

  IF meetingExists = 0 THEN
    RETURN -2;
  END IF;

  SELECT COUNT (*)
  INTO documentExists
  FROM ms_document
  WHERE docID = dID;

  IF documentExists = 0 THEN
    RETURN -3;
  END IF;

  INSERT INTO ms_meetingdocumentpair(meetingID, docID)
  VALUES (meetID, dID);
  
  RETURN 1;

EXCEPTION  
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- create type to return the data we need

DROP TYPE ms_meetingdocpair_tuple CASCADE;

CREATE TYPE ms_meetingdocpair_tuple AS (
  meetID INTEGER,
  dID INTEGER,
  success INTEGER);


-- given a meeting ID, retrieve the corresponding meeting ID, doc ID pair 

-- return: struct with success field set to 1 for success
--                                          -1 for system error
--                                          -2 for no such meeting

CREATE OR REPLACE FUNCTION ms_getDocIDByMeetingID(meetID INTEGER) RETURNS MS_MEETINGDOCPAIR_TUPLE AS $$

DECLARE
  meetingExists INTEGER;
  retval MS_MEETINGDOCPAIR_TUPLE;
  
BEGIN
  SELECT COUNT (*)
  INTO meetingExists
  FROM ms_meetingDocumentPair
  WHERE meetingID = meetID;

  IF meetingExists = 0 THEN
    retval.success = -2;
    RETURN retval;
  END IF;

  SELECT meetingID, docID
  INTO retval.meetID, retval.dID
  FROM ms_meetingDocumentPair
  WHERE meetingID = meetID;

  retval.success = 1;

  RETURN retval;

EXCEPTION
  WHEN OTHERS THEN
    retval.success = -1;
    RETURN retval;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- given a logname, tell whether it's free (i.e. no account already exists under that logname)

-- return 1 if logname is free
--        0 if logname is not free
--        -1 for system error

CREATE OR REPLACE FUNCTION ms_lognameFree(lognam VARCHAR) RETURNS INTEGER AS $$

DECLARE
  alreadyInUse INTEGER;

BEGIN
  SELECT COUNT (*)
  INTO alreadyInUse
  FROM ms_account
  WHERE logname = lognam;

  IF alreadyInUse = 1 THEN        -- logname already taken
    RETURN 0;
  ELSIF alreadyInUse = 0 THEN     -- logname is free
    RETURN 1; 
  ELSE 
    RETURN -1;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- store the initial and final agreements in a separate table
-- return 1 for success
--       -1 for system error
--       -2 for agreements with that caseNum already on file
--       -3 for caseNum does not exist
--       -4 for caseNum is not resolved

CREATE OR REPLACE FUNCTION ms_storeInitialAndFinal(caseNum INTEGER, initialAgr VARCHAR, finalAgr VARCHAR) RETURNS INTEGER AS $$

DECLARE 
  caseExists INTEGER;
  caseIsResolved INTEGER;

BEGIN
  SELECT COUNT (*) 
  INTO caseExists
  FROM ms_case
  WHERE caseID = caseNum;

  IF caseExists = 0 THEN
    RETURN -3;
  END IF;        

  SELECT COUNT (*) 
  INTO caseIsResolved
  FROM ms_caseState
  WHERE caseID = caseNum AND
        caseStatus = 'Resolved';

  IF caseExists = 0 THEN
    RETURN -4;
  END IF;        

  INSERT INTO ms_initialAndFinalAgreements(caseNumber, initialAgreement, finalAgreement)
  VALUES (caseNum, initialAgr, finalAgr);
  
  RETURN 1;

EXCEPTION
  WHEN UNIQUE_VIOLATION THEN
    RETURN -2;
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- given a caseID, return the doc IDs of the Preliminary and Final Agreements
-- success value of struct is set to 1 for success
--                                  -1 for system error
--                                  -2 for no such case
--                                  -3 for no preliminary agreement on file
--                                  -4 for no final agreement on file

-- create type to return the data we need

DROP TYPE ms_initialfinaldocid_tuple CASCADE;

CREATE TYPE ms_initialfinaldocid_tuple AS (
  cID INTEGER,
  initDID INTEGER,
  initVer INTEGER,
  finDID INTEGER,
  finVer INTEGER,
  success INTEGER);


CREATE OR REPLACE FUNCTION ms_getInitialAndFinalDocID(cID INTEGER) 
                           RETURNS MS_INITIALFINALDOCID_TUPLE AS $$

DECLARE
  caseExists INTEGER;
  initialExists INTEGER;
  finalExists INTEGER;
  retval MS_INITIALFINALDOCID_TUPLE;

BEGIN
  SELECT COUNT (*) 
  INTO caseExists
  FROM ms_case
  WHERE caseID = cID;

  IF caseExists = 0 THEN
    retval.success = -2;
    RETURN retval;
  END IF;

  SELECT COUNT (*)
  INTO initialExists
  FROM ms_document
  WHERE caseID = cID AND
        type = 'PrelimAgr';

  IF initialExists = 0 THEN
    retval.success = -3;
    RETURN retval;
  END IF;  

  SELECT COUNT (*)
  INTO finalExists
  FROM ms_document
  WHERE caseID = cID AND
        type = 'FinalAgr';

  IF finalExists = 0 THEN
    retval.success = -4;
    RETURN retval;
  END IF;

  SELECT D1.caseID, D1.docID, MAX(DV1.version), D2.docID, MAX(DV2.version), 1
  INTO retval.cID, retval.initDID, retval.initVer, retval.finDID, retval.finVer, retval.success
  FROM ms_document D1, ms_document D2, ms_docversion DV1, ms_docversion DV2
  WHERE D1.caseID = cID AND
        D1.caseID = D2.caseID AND
        D1.type = 'PrelimAgr' AND
        D2.type = 'FinalAgr' AND
        DV1.docID = D1.docID AND
        DV2.docID = D2.docID
  GROUP BY D1.caseID, D1.docID, D2.docID;

  RETURN retval;
  
EXCEPTION
  WHEN OTHERS THEN 
    retval.success = -1;
    RETURN retval;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- given a caseID, return the caseID and the Preliminary and Final Agreements
-- success value of struct is set to 1 for success
--                                  -1 for system error
--                                  -2 for not on file

-- create type to return the data we need

DROP TYPE ms_initialfinaldoc_tuple CASCADE;

CREATE TYPE ms_initialfinaldoc_tuple AS (
  cNum INTEGER,
  initAgr VARCHAR,
  finAgr VARCHAR,
  success INTEGER);


CREATE OR REPLACE FUNCTION ms_retrieveInitialAndFinal(cNum INTEGER) 
                           RETURNS MS_INITIALFINALDOC_TUPLE AS $$

DECLARE
  caseOnFile INTEGER;
  retval MS_INITIALFINALDOC_TUPLE;

BEGIN
  SELECT COUNT (*) 
  INTO caseOnFile
  FROM ms_initialandfinalagreements
  WHERE casenumber = cNum;

  IF caseOnFile = 0 THEN
    retval.success = -2;
    RETURN retval;
  END IF;

  SELECT casenumber, initialagreement, finalagreement, 1
  INTO retval.cNum, retval.initAgr, retval.finAgr, retval.success
  FROM ms_initialandfinalagreements
  WHERE casenumber = cNum;

  RETURN retval;
  
EXCEPTION
  WHEN OTHERS THEN 
    retval.success = -1;
    RETURN retval;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- delete a case
-- returns: 300 + number of accounts deleted for success
--         -1 for system error
--         -3 for case not terminated or resolved
--         -4 for case resolved but no agreements on file

-- NOTE: CALLING FUNCTION MUST FIRST OBTAIN AND STORE A LIST OF ACCOUNTS ASSOCIATED
--       WITH THE CASE. THIS LIST WILL BE USED TO DELETE THE ACCOUNTS.


CREATE OR REPLACE FUNCTION ms_deleteCase(cID INTEGER) RETURNS INTEGER AS $$

DECLARE
  isOnFile INTEGER;
  isResolvedOrTerminated INTEGER;
  isResolved INTEGER;
  isTerminated INTEGER;
  agrsOnFile INTEGER;

BEGIN
  SELECT COUNT (*)
  INTO isOnFile
  FROM ms_case
  WHERE caseID = cID;

  IF isOnFile = 0 THEN 
    RETURN 0;
  END IF;

  SELECT COUNT (*)
  INTO isResolvedOrTerminated
  FROM ms_casestate
  WHERE caseid = cID AND
        (casestatus = 'Resolved' OR casestatus = 'Terminated');

  IF isResolvedOrTerminated = 0 THEN
    RETURN -3;
  END IF;

  SELECT COUNT (*)
  INTO isResolved
  FROM ms_casestate
  WHERE caseid = cID AND
        casestatus = 'Resolved';

  SELECT COUNT (*)
  INTO agrsOnFile
  FROM ms_initialandfinalagreements
  WHERE caseNumber = cID;

  IF isResolved > 0 AND agrsOnFile = 0 THEN
    return -4;
  END IF;  
       
  -- delete message recipients
  DELETE FROM ms_messagerecipient
  WHERE messageID IN
    (SELECT messageID
     FROM ms_messageSent
     WHERE caseID = cID);

  -- delete messages
  DELETE FROM ms_messagesent
  WHERE caseid = cID;

  -- delete doc signatures
  DELETE FROM ms_docsignature
  WHERE logname IN
    (SELECT logname
     FROM ms_accountcaserole
     WHERE caseid = cID);

  -- delete doc accesses
  DELETE FROM ms_docaccess
  WHERE logname IN
    (SELECT logname
     FROM ms_accountcaserole
     WHERE caseid = cID);

  -- delete doc versions
  DELETE FROM ms_docversion
  WHERE docid IN
    (SELECT docid FROM ms_document
     WHERE caseid = cID);

  -- delete meeting document pairs
  DELETE FROM ms_meetingdocumentpair
  WHERE docid IN
    (SELECT docid FROM ms_document
     WHERE caseid = cID);
  
  -- delete documents
  DELETE FROM ms_document
  WHERE caseid = cID;

  -- delete attendance
  DELETE FROM ms_attendance
  WHERE logname IN
    (SELECT logname
     FROM ms_accountcaserole
     WHERE caseid = cID);

  -- delete meeting
  DELETE FROM ms_meeting
  WHERE caseid = cID;

  -- delete available
  DELETE FROM ms_available
  WHERE caseid = cID;

  -- delete logins
  DELETE FROM ms_loginout
  WHERE logname IN
    (SELECT logname
     FROM ms_accountcaserole
     WHERE caseid = cID)
       AND (caseid = cID OR caseid < 1000);

  -- delete logins (old)
--   DELETE FROM ms_loginout
--   WHERE caseid = cID;

  -- delete case states
  DELETE FROM ms_casestate
  WHERE caseid = cID;

  -- delete account case role tuples  
  DELETE FROM ms_accountcaserole
  WHERE caseid = cID;

  -- delete case
  DELETE FROM ms_case
  WHERE caseid = cID;

  RETURN 100;
 

EXCEPTION
  WHEN OTHERS THEN 
    RETURN -1;
END;

$$ LANGUAGE plpgsql;
 
-- ---------------------------------------------------------------------------

-- delete an account
-- SHOULD ONLY BE CALLED AFTER CASE IT RELATES TO HAS BEEN DELETED

-- returns 1 for success
--         0 for no such account
--        -1 for system error

CREATE OR REPLACE FUNCTION ms_deleteAccount(accountName VARCHAR) RETURNS INTEGER AS $$

DECLARE
  accountExists INTEGER;
 
BEGIN
  IF accountName = 'Admin01' THEN  -- don't allow delete of this account
  RETURN -1;
  END IF;

  SELECT COUNT (*)
  INTO accountExists
  FROM ms_account
  WHERE logname = accountName;

  IF accountExists = 0 THEN
    RETURN 0;
  END IF;

  DELETE FROM ms_account
  WHERE logname = accountName;

  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------

-- delete a loginout, given a user name

-- returns 1 for success
--        -1 for system error

CREATE OR REPLACE FUNCTION ms_deleteLoginout(lognam VARCHAR) RETURNS INTEGER AS $$

BEGIN
  DELETE FROM ms_loginout
  WHERE logname = lognam;

  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
