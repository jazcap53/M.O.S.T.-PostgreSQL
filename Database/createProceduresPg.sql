-- File: createProceduresPg.sql
-- Modified 7/23/2011 1:30a
-- Andrew Jarcho
-- NEW Procedures for MSTS  POSTGRESQL PORT
 
-- ----------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------

-- FUNCTIONS CREATED

-- ms_login(lognm VARCHAR, passw VARCHAR) RETURNS INTEGER
-- ms_logout(lognm VARCHAR) RETURNS INTEGER
-- ms_changePassword(lognm VARCHAR, oldPassw VARCHAR, newPassw VARCHAR) RETURNS INTEGER
-- ms_newAccount (newLognm VARCHAR, newLastName VARCHAR, newFirstName VARCHAR, newEmail VARCHAR) RETURNS INTEGER
-- ms_updateCaseState(cID INTEGER, cStatus  VARCHAR) RETURNS INTEGER
-- ms_newCase (newCaseTitle VARCHAR) RETURNS INTEGER
-- ms_newAccountCaseRole(lognam VARCHAR, cID INTEGER, rol VARCHAR) RETURNS INTEGER
-- ms_updateAccountInfo(lognam VARCHAR, lastnam VARCHAR, firstnam VARCHAR, midinit CHAR, homephn VARCHAR, 
--                      workphn VARCHAR, cellphn VARCHAR, emal VARCHAR) RETURNS INTEGER
-- ms_newDocument (typ VARCHAR, titl VARCHAR, bod VARCHAR, cID INTEGER) RETURNS INTEGER
-- ms_newDocVersion (dID INTEGER, bod VARCHAR) RETURNS INTEGER
-- ms_retrieveAccount (lognm VARCHAR) RETURNS MS_ACCOUNT_TUPLE
-- ms_getCaseTitleByID (cID INTEGER) RETURNS MS_CASE_TITLE_TUPLE
-- ms_retrieveDocForEdit (dIDIn INTEGER) RETURNS MS_DOCUMENT_TUPLE
-- ms_returnDocument(dID INTEGER) RETURNS INTEGER
-- ms_retrieveDocReadOnly (dIDIn INTEGER, versnIn INTEGER) RETURNS MS_DOCUMENT_TUPLE
-- ms_newDocAccess (dID INTEGER, lognm VARCHAR) RETURNS INTEGER
-- ms_newDocSignature (dID INTEGER, versn INTEGER, lognm VARCHAR, sigPlac VARCHAR) RETURNS INTEGER
-- ms_getRole (lognm VARCHAR, cID INTEGER) RETURNS MS_ROLE_TUPLE
-- ms_isLoggedIn (lognm VARCHAR) RETURNS INTEGER
-- ms_getCaseStatusByID (cID INTEGER) RETURNS MS_CASE_STATUS_TUPLE
-- ms_getMeeting (mID INTEGER) RETURNS MS_MEETING_TUPLE

-- ----------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------

-- log in
-- logs a user in to the system
-- user may log in with a 'dummy' case id (< 1000) to check messages only
-- if a 'valid' case id is given (>= 1000), function checks that such a case 
--     exists, and that this user is allowed to access it
-- if this user is already logged in to a *different* case, function tries to log them
--    out of the 'old' case, then in to the 'new' case
-- if this user is already logged in to the *given* case, function returns without taking action
-- returns: 2 for already logged in to this case 
--          1 for successful new log in
--          -1 for system error 
--          -2 for bad logname, password pair
--          -3 for user not involved in this case 
--          -4 for no such case
--          XXXX for successful login: logged you out of case XXXX first

CREATE OR REPLACE FUNCTION ms_login(lognm VARCHAR, passw VARCHAR, cID INTEGER) RETURNS INTEGER AS $$

DECLARE
  casExists INTEGER;
  goodPw INTEGER;
  goodCas INTEGER;
  isLoggedIn INTEGER;
  logoutStatus INTEGER;
BEGIN

  IF cID > 999 THEN    -- we're trying to log in to a 'real' case
    SELECT COUNT (*)   -- check case exists
    INTO casExists
    FROM ms_case
    WHERE caseID = cID;

    IF casExists = 0 THEN
      RETURN -4;       -- no such animal
    END IF;
  END IF;

  SELECT COUNT (*)     -- check for good lognm / pw combo 
  INTO goodPw
  FROM ms_account A
  WHERE A.logname = lognm AND
    A.password = crypt(passw, A.password);

  IF goodPw < 1 THEN
    RETURN -2;         -- bad lognm / pw combo
  END IF;

  IF cID > 999 THEN    -- check logname is involved in case
    SELECT COUNT (*) 
    INTO goodCas
    FROM ms_accountcaserole ACR
    WHERE ACR.logname = lognm AND
          ACR.caseID = cID;
    IF goodCas < 1 THEN   -- if this user not involved in this case
      RETURN -3;          -- return error
    END IF;
  END IF;


  -- if we reach here, AOK, ready to log in

  SELECT ms_isLoggedIn(lognm)                  -- is user already logged in?
  INTO isLoggedIn;

  IF isLoggedIn = cID THEN                     -- if already logged in to *this* case
    RETURN 2;                                  -- just return that fact
  ELSIF isLoggedIn > 0 THEN                    -- if user is already logged in to some *other* case
    SELECT ms_logout(lognm)                    -- try to log them out of that case
    INTO logoutStatus;
    IF logoutStatus < 1 THEN                   -- logout failed
      RETURN -1;                               -- sys error somewhere
    END IF;
  END IF;

  INSERT INTO ms_loginout(logname, logdate, caseID)  -- do the login
  VALUES(lognm, CURRENT_TIMESTAMP + '.001 sec', cID);

  IF isLoggedIn > 0 THEN                      -- if they were already logged in
    RETURN isLoggedIn;                        -- return the case num we just logged out of
  ELSE
    RETURN 1;                                 -- return 0K
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------

-- log out
-- log a user out of the system
-- deletes any log in / out records older than 6 months
-- returns: 1 for successful logout
--          0 for user not logged in
--          -1 for error 

CREATE OR REPLACE FUNCTION ms_logout(lognm VARCHAR) RETURNS INTEGER AS $$

DECLARE
  isLoggedIn INTEGER;

BEGIN
  DELETE FROM ms_loginout
  WHERE (age(logdate)) > '6 mon';        -- moldy oldie

  SELECT ms_isLoggedIn(lognm)            -- is user already logged in?
  INTO isLoggedIn;
  IF isLoggedIn > 0 THEN                 -- if so, then
    INSERT INTO ms_loginout (logname, logdate, caseID)  -- log them out
    VALUES (lognm, CURRENT_TIMESTAMP, 0);
    RETURN 1;
  ELSIF isLoggedIn = 0 THEN              -- if not logged in
    NULL;                                -- do nothing
    RETURN 0;                            -- return 'not logged in'
  ELSE
    RETURN isLoggedIn;                   -- return error msg
  END IF; 

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------

-- change password
-- returns: 1 for password updated successfully
--          0 for password not updated
--          -1 for system error (number of matches to old
--              logname / pw pair is not 1 or 0)

CREATE OR REPLACE FUNCTION ms_changePassword(lognm VARCHAR, oldPassw VARCHAR, newPassw VARCHAR) RETURNS INTEGER AS $$

DECLARE success INTEGER;

BEGIN
  SELECT COUNT(*) INTO success
  FROM ms_account A1
  WHERE A1.logname = lognm AND 
    A1.password = crypt(oldPassw, A1.password);
  IF success = 1 THEN         -- old password is correct
    UPDATE ms_account         -- change to new password
    SET password = crypt(newPassw, gen_salt('md5'))
    WHERE logname = lognm;
  ELSIF success = 0 THEN      -- old password is wrong
    NULL;
  ELSE
    success := -1;            -- system error
  END IF;
  RETURN success;
END;

$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------

-- create type to return an account tuple

DROP TYPE ms_littleaccount_tuple CASCADE;

CREATE TYPE ms_littleaccount_tuple AS (
  lognam VARCHAR,
  success INTEGER);

-- create new account with all *required* fields
-- password created as 'Default'
-- returns:
--     a tuple with 'success' field set to 
--         1 for account created
--         0 if duplicate log name
--         -1 on other error

CREATE OR REPLACE FUNCTION ms_newAccount (newLognm VARCHAR, newLastName VARCHAR,
  newFirstName VARCHAR, newEmail VARCHAR) RETURNS MS_LITTLEACCOUNT_TUPLE AS $$

DECLARE
  retval MS_LITTLEACCOUNT_TUPLE;

BEGIN
  INSERT INTO ms_account (logname, password, lastName, firstName, email)
  values (newLognm, crypt('Default', gen_salt('md5')), newLastName, newFirstName, newEmail);
  retval.lognam := newLognm;
  retval.success := 1;
  RETURN retval;

  EXCEPTION
    WHEN UNIQUE_VIOLATION THEN    -- logname is already being used
      retval.lognam := newLognm;
      retval.success := 0;
      RETURN retval;

    WHEN OTHERS THEN
      retval.lognam := 'NULL';
      retval.success := -1;
      RETURN retval;
END;

$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- update case state
-- does not allow an update to 'resolved' if no final agreement exists
-- returns: 1 for case state updated successfully
--          -1 for error

CREATE OR REPLACE FUNCTION ms_updateCaseState(cID INTEGER, cStatus VARCHAR) 
  RETURNS INTEGER AS $$

DECLARE 
  finalAgrExists INTEGER;

BEGIN
  IF cStatus = 'Resolved' THEN   -- if we're trying to set case status to 'resolved'
    SELECT COUNT (*)             -- check that a final agreement exists
    INTO finalAgrExists
    FROM ms_document
    WHERE caseID = cID AND
          type = 'FinalAgr';

    IF finalAgrExists = 0 THEN   -- if no agreement then return error
      RETURN -1;
    END IF;
  END IF;

  INSERT INTO ms_caseState (caseID, caseStatus, statusDate)  -- update the case state
  VALUES (cID, cStatus, CURRENT_TIMESTAMP);
  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new case
-- status created as 'Opened'
-- also calls ms_updateCaseState
-- returns: new case ID on success 
--          -1 for error

CREATE OR REPLACE FUNCTION ms_newCase (newCaseTitle VARCHAR) RETURNS INTEGER AS $$

DECLARE
  newCaseID INTEGER;
  caseStateOK INTEGER;

BEGIN
  INSERT INTO ms_case (caseID, caseTitle)         -- create the new case
  values (nextval('ms_caseIDSeq'), newCaseTitle);
    
  SELECT currval('ms_caseIDSeq') INTO newCaseID;

  caseStateOK := ms_updateCaseState(newCaseID, 'Opened');  -- create entry in case state table

  IF caseStateOK = 1 THEN                         -- if *both* operations succeeded
    RETURN newCaseID;
  ELSE
    RETURN -1;                                    -- else caller will roll back transaction
  END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new accountCaseRole entry
-- returns: 1 for success
--          -1 for error

CREATE OR REPLACE FUNCTION ms_newAccountCaseRole(lognam VARCHAR, cID INTEGER,
  rol VARCHAR) RETURNS INTEGER AS $$

BEGIN
  INSERT INTO ms_accountCaseRole (logname, caseID, role)
  values (lognam, cID, rol);
  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- update account info
-- update non-null input fields
-- returns: 1 for successful update
--          -1 for error
-- FIX??: rollback partial updates

CREATE OR REPLACE FUNCTION ms_updateAccountInfo(lognam VARCHAR, lastnam VARCHAR, firstnam VARCHAR, midinit CHAR,
  homephn VARCHAR, workphn VARCHAR, cellphn VARCHAR, emal VARCHAR) RETURNS INTEGER AS $$

BEGIN
  IF lastnam <> 'NULL' THEN
    UPDATE ms_account
    SET lastname = lastnam
    WHERE logname = lognam;
  END IF;
 
  IF firstnam <> 'NULL' THEN
    UPDATE ms_account
    SET firstname = firstnam
    WHERE logname = lognam;
  END IF; 

  IF midinit <> '%' THEN       -- % is our 'NULL' char
    UPDATE ms_account
    SET middleinitial = midinit
    WHERE logname = lognam;
  END IF;

  IF homephn <> 'NULL' THEN
    UPDATE ms_account
    SET homephone = homephn
    WHERE logname = lognam;
  END IF; 

  IF workphn <> 'NULL' THEN
    UPDATE ms_account
    SET workphone = workphn
    WHERE logname = lognam;
  END IF; 

  IF cellphn <> 'NULL' THEN
    UPDATE ms_account
    SET cellphone = cellphn
    WHERE logname = lognam;
  END IF;
 
  IF emal <> 'NULL' THEN
    UPDATE ms_account
    SET email = emal
    WHERE logname = lognam;
  END IF;

  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new document
-- set version number to 1
-- use CURRENT_TIMESTAMP as date created
-- set ms_document.docOut to 'n'
-- inserts entries into BOTH ms_document AND ms_docVersion
-- returns: new doc_id on success
--          0 if doc w/ given title already exists for given case
--          -1 for sys error
--          -2 if trying to create intermediate or final agr, and there is no prelim agr
-- FIX??: rollback if insert into document succeeds but insert into docVersion fails?

CREATE OR REPLACE FUNCTION ms_newDocument (typ VARCHAR, titl VARCHAR, bod VARCHAR,
  cID INTEGER) RETURNS INTEGER AS $$

DECLARE 
  dID INTEGER;
  alreadyThere INTEGER;
  newVersionOK INTEGER;
  havePrelim INTEGER;

BEGIN
  IF typ = 'IntermedAgr' OR typ = 'FinalAgr' THEN  -- if trying to create intermediate or final agreement
    SELECT COUNT (*)                  -- is there a preliminary agreement?
    INTO havePrelim
    FROM ms_document
    WHERE caseID = cID AND
          type = 'PrelimAgr';
    IF havePrelim = 0 THEN            -- if not
      RETURN -2;
    END IF;
  END IF; 

  SELECT COUNT(*) INTO alreadyThere
  FROM ms_document
  WHERE caseID = cID AND
        title = titl;
  IF alreadyThere <> 0 THEN
    RETURN 0;                         -- return if there already exists a doc with that name in this Case
  END IF;  

  INSERT INTO ms_document (docID, type, title, caseID, docOut)  -- insert the document
  values(nextval('ms_docIDSeq'), typ, titl, cID, 'n');

  SELECT currval('ms_docIDSeq')
  INTO dID;

  SELECT ms_newDocVersion(dID, bod)   -- call function to insert new doc version
  INTO newVersionOK;

  IF newVersionOK > 0 THEN
    RETURN dID;
  ELSE
    RETURN -1;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new version of document
-- use CURRENT_TIMESTAMP as date created
-- get existing version number if any and increment
--    else use 1 for version num
-- body may be 'NULL'
-- returns: new version number for success
--          -1 for error

CREATE OR REPLACE FUNCTION ms_newDocVersion (dID INTEGER, bod VARCHAR)
  RETURNS INTEGER AS $$

DECLARE
  versn INTEGER;
  bodyValue VARCHAR;
  existingVersion INTEGER; 

BEGIN
  IF bod = 'NULL' THEN
    bodyValue := null;
  ELSE
    bodyValue := bod;
  END IF;

  SELECT COUNT (*)               -- get number of previous versions
  INTO existingVersion
  FROM ms_docVersion
  WHERE docID = dID;

  IF existingVersion = 0 THEN    -- kludge
    versn := 1;
  ELSE
    SELECT (MAX(version) + 1)    -- get number of most recent version and add 1
    INTO versn
    FROM ms_docVersion
    WHERE docID = dID;
  END IF;

  INSERT INTO ms_docVersion (docID, version, dateCreated, body)  -- insert version
  VALUES (dID, versn, CURRENT_TIMESTAMP, bodyValue);
  RETURN versn;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return an account tuple

DROP TYPE ms_account_tuple CASCADE;

CREATE TYPE ms_account_tuple AS (
  lastnm VARCHAR,
  firstnm VARCHAR,
  midinit CHAR,
  homephn VARCHAR,
  workphn VARCHAR,
  cellphn VARCHAR,
  emal VARCHAR,
  success INTEGER);

-- retrieve account details
-- returns:
--    a tuple with 'success' field set to
--        1 for details retrieved 
--        0 for no such user
--        -1 for error

CREATE OR REPLACE FUNCTION ms_retrieveAccount (lognm VARCHAR) RETURNS MS_ACCOUNT_TUPLE AS $$

DECLARE
  result MS_ACCOUNT_TUPLE;

BEGIN
  SELECT count(logname)    -- check for valid user name 
  into result.success
  FROM ms_account
  WHERE logname = lognm;
  IF result.success = 1 THEN
    -- get the user's data
    SELECT lastName, firstName, middleInitial, homePhone, workPhone, cellPhone, email
    INTO result.lastnm, result.firstnm, result.midinit, result.homephn, result.workphn, 
         result.cellphn, result.emal
    FROM ms_account
    WHERE logname = lognm;
  ELSIF result.success = 0 THEN
    NULL;
  END IF;
  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success := -1;
    RETURN result;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return a case title tuple

DROP TYPE ms_case_title_tuple CASCADE;

CREATE TYPE ms_case_title_tuple AS (
  cTitl VARCHAR,
  success INTEGER);

-- given a case ID, retrieve the case title
-- returns: 
--    a tuple with success field set to
--        1 for title retrieved
--        0 for no such case
--        -1 for other error

CREATE OR REPLACE FUNCTION ms_getCaseTitleByID (cID INTEGER) RETURNS MS_CASE_TITLE_TUPLE AS $$

DECLARE
  result MS_CASE_TITLE_TUPLE;
  cTitlCount INTEGER;

BEGIN
  SELECT count(caseTitle)     -- check for valid case id
  INTO cTitlCount
  FROM ms_case
  WHERE caseID = cID;
  IF cTitlCount = 0 THEN
    result.success := 0;
  ELSE
    SELECT caseTitle          -- retrieve case title for that id
    INTO result.cTitl
    FROM ms_case
    WHERE caseID = cID;
    result.success := 1;
  END IF;
  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success := -1;
    RETURN result;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return a document tuple

DROP TYPE ms_document_tuple CASCADE;

CREATE TYPE ms_document_tuple AS (
  dIDOut INTEGER,
  versnOut INTEGER,
  dtcreated VARCHAR,
  titl VARCHAR,
  bod VARCHAR,
  editable CHAR,     -- 'y' or 'n'
  success INTEGER);

-- if a document is not already out for edit
-- retrieve the most recent version of the document for edit
-- if successful, 'editable' field of return value will be set to 'y'
-- returns:
--     1 on success
--     0 if doc is already out for edit
--     -1 on error

CREATE OR REPLACE FUNCTION ms_retrieveDocForEdit (dIDIn INTEGER)
  RETURNS MS_DOCUMENT_TUPLE AS $$

DECLARE
  alreadyOut CHAR;
  result MS_DOCUMENT_TUPLE;
  versnTemp INTEGER; 
  bodFromTable VARCHAR;

BEGIN
  SELECT docOut                 -- is the document already out for edit?
  INTO alreadyOut
  FROM ms_document 
  WHERE ms_document.docID = dIDIn;

  IF alreadyOut = 'y' THEN      -- if yes
    result.success := 0;
    RETURN result;
  ELSE
    SELECT MAX(dv1.version)     -- else get number of most recent version
    INTO versnTemp
    FROM ms_docVersion dv1
    WHERE dv1.docID = dIDIn;

    -- retrieve the data
    SELECT to_char(dv2.datecreated, 'MON DD YYYY  HH12:MI:SS AM'), d3.title, dv2.body
    INTO result.dtcreated, result.titl, bodFromTable
    FROM ms_docVersion dv2, ms_document d3
    WHERE dv2.docID = dIDIn AND
          dv2.docID = d3.docID AND
          dv2.version = versnTemp;

    UPDATE ms_document          -- mark document as out for edit
    SET docOut = 'y'
    WHERE docID = dIDIn;
  END IF;

  IF bodFromTable IS NULL THEN
    result.bod := 'NULL';       -- 'NULL' a text value recognized by the application
  ELSE
    result.bod := bodFromTable;
  END IF;

  result.dIDOut := dIDIn;
  result.editable := 'y';
  result.success := 1;
  result.versnOut := versnTemp;
  RETURN result;  

  EXCEPTION
    WHEN OTHERS THEN
      result.success := -1;
      RETURN result;
END;
 
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- 'return' a document that has been out for edit
-- alter the docOut field for that document to 'n'
-- argument: docID of the document
-- returns: 1 on success
--          0 if doc in NOT out for edit
--          -1 on error

CREATE OR REPLACE FUNCTION ms_returnDocument(dID INTEGER) RETURNS INTEGER AS $$

DECLARE isOut CHAR;

BEGIN
  SELECT docOut           -- check that the doc is out for edit
  INTO isOut
  FROM ms_document
  WHERE docID = dID;
  IF isOut = 'n' THEN     -- if it's not out
    RETURN 0;
  ELSIF isOut = 'y' THEN  -- if it's out
    UPDATE ms_document
    SET docOut = 'n'
    WHERE docID = dID;
    RETURN 1;
  ELSE 
    RETURN -1;            -- db error: docOut should be 'y' or 'n'
  END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- retrieve a document FOR READ-ONLY
-- if versn (version number) is zero
-- retrieve the most recent version of a document
-- otherwise retrieve version number versn
-- if success, editable field of return value set to 'n'
-- returns a tuple with success field set to
--    1 on success
--    0 if doc is out for edit 
--    -1 on error

CREATE OR REPLACE FUNCTION ms_retrieveDocReadOnly (dIDIn INTEGER, versnIn INTEGER)
  RETURNS MS_DOCUMENT_TUPLE AS $$

DECLARE
  result MS_DOCUMENT_TUPLE;
  versnTemp INTEGER;
  bodFromTable VARCHAR;
 
BEGIN
  IF versnIn = 0 THEN             -- if the given version number is 0
    SELECT MAX(dv1.version)       -- get the number of the most recent version
    INTO versnTemp
    FROM ms_docVersion dv1
    WHERE dv1.docID = dIDIn;
  ELSE versnTemp = versnIn;       -- else we look for the specified version
  END IF;

  -- retrieve the data
  SELECT to_char(dv2.datecreated, 'MON DD, YYYY, HH12:MI:SS AM'), d3.title, dv2.body
  INTO result.dtcreated, result.titl, bodFromTable
  FROM ms_docVersion dv2, ms_document d3
  WHERE dv2.docID = dIDIn AND
        dv2.docID = d3.docId AND
        dv2.version = versnTemp;

  IF bodFromTable IS NULL THEN    
    result.bod := 'NULL';         -- convert null value to string recognized by application
  ELSE
    result.bod := bodFromTable;
  END IF;
    
  result.dIDOut := dIDIn;
  result.success := 1;
  result.editable := 'n';
  result.versnOut := versnTemp;
  RETURN result;  

  EXCEPTION
    WHEN OTHERS THEN
      result.success := -1;
      RETURN result;
END;
 
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new docAccess entry
-- access to a document is given to a participant
-- returns: 1 for success
--          -1 for error

CREATE OR REPLACE FUNCTION ms_newDocAccess (dID INTEGER, lognm VARCHAR) RETURNS INTEGER AS $$ 

BEGIN
  INSERT INTO ms_docAccess (docID, logname)
  values(dID, lognm);
  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;

END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create new docSignature entry
-- participant 'signs' a version of a document
-- returns 1 for success
--         0 for user already signed this doc version
--         -1 for system error
--         -2 for no such doc
--         -3 for no such version
--         -4 for logname does not have access

CREATE OR REPLACE FUNCTION ms_newDocSignature (dID INTEGER, versn INTEGER, lognam VARCHAR,
  sigPlac VARCHAR) RETURNS INTEGER AS $$

DECLARE
  docExists INTEGER;
  versionExists INTEGER;
  lognameHasAccess INTEGER;

BEGIN
  SELECT COUNT (*)           -- check that document exists
  INTO docExists
  FROM ms_document
  WHERE docID = dID;

  IF docExists = 0 THEN
    RETURN -2;
  END IF;

  SELECT COUNT (*)           -- check that version exists
  INTO versionExists
  FROM ms_docversion
  WHERE docID = dID AND
        version = versn;

  IF versionExists = 0 THEN
    RETURN -3;
  END IF;

  SELECT COUNT (*)           -- check that user has access to the document
  INTO lognameHasAccess
  FROM ms_docaccess
  WHERE docID = dID AND
        logname = lognam;

  IF lognameHasAccess = 0 THEN
    RETURN -4;
  END IF;  

  -- 'sign' the document
  INSERT INTO ms_docSignature (docID, version, logname, sigDate, sigPlace)
  VALUES(dID, versn, lognam, CURRENT_TIMESTAMP, sigPlac);
  RETURN 1;

EXCEPTION
  WHEN UNIQUE_VIOLATION THEN
    RETURN 0;

  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return a role tuple

DROP TYPE ms_role_tuple CASCADE;

CREATE TYPE ms_role_tuple AS (
  rol VARCHAR,
  success INTEGER);

-- given a logname and a case id, retrieve the role of that user in that case
-- returns:
--    a struct whose success field is
--        1 for success
--        0 for bad input
--        -1 for system error

CREATE OR REPLACE FUNCTION ms_getRole (lognm VARCHAR, cID INTEGER) RETURNS MS_ROLE_TUPLE AS $$

DECLARE
  result MS_ROLE_TUPLE;

BEGIN
  SELECT COUNT(logname)           -- is this user associated with this case?
  INTO result.success
  FROM ms_accountCaseRole
  WHERE logname = lognm AND
        caseID = cID;
  IF (result.success = 1) THEN    
    SELECT role                   -- get the role
    INTO result.rol
    FROM ms_accountCaseRole
    WHERE logname = lognm AND
          caseID = cID;
  END IF;

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success := -1;
    RETURN result;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- is the specified user currently logged in to the system?
-- returns: case ID if logged in
--          0 if not logged in
--         -1 for system error

CREATE OR REPLACE FUNCTION ms_isLoggedIn (lognm VARCHAR) RETURNS INTEGER AS $$

DECLARE
  lastLoginoutAge INTERVAL;
  casID INTEGER;

BEGIN
  SELECT MIN(age(logdate))            -- look for latest login / logout
  INTO lastLoginoutAge  
  FROM ms_loginout
  WHERE logname = lognm;

  IF lastLoginoutAge IS NULL THEN     -- if there was neither, then
      RETURN 0;                       -- return not logged in
  ELSE
    SELECT caseID                     -- get caseID from most recent log in / out
    INTO casID                
    FROM ms_loginout          
    WHERE logname = lognm AND
          age(logdate) = lastLoginoutAge;   
    RETURN casID;                     -- return that caseID (may be 0 for logout)
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return a case status tuple

DROP TYPE ms_case_status_tuple CASCADE;

CREATE TYPE ms_case_status_tuple AS (
  cStatus VARCHAR,
  cStatDt VARCHAR,
  success INTEGER);

-- given a case id, report its status
-- returns:
--    a struct with the success field set to
--        0 for case not found (error)
--        1 for case found
--        -1 for system error

CREATE OR REPLACE FUNCTION ms_getCaseStatusByID (cID INTEGER) RETURNS MS_CASE_STATUS_TUPLE AS $$

DECLARE
  result MS_CASE_STATUS_TUPLE;
  maxDate TIMESTAMP WITH TIME ZONE;        -- timestamp of latest entry in ms_casestate relation

BEGIN
  SELECT MAX(statusdate)                   -- get latest timestamp
  INTO maxDate 
  FROM ms_casestate
  WHERE caseID = cID;
  IF maxDate IS NULL THEN
    result.success := 0;
  ELSE                                     -- get most recent status, and time of last status change
    SELECT casestatus, to_char(statusdate, 'MON DD, YYYY, HH12:MI:SS AM')
    INTO result.cStatus, result.cStatDt
    FROM ms_casestate
    WHERE caseID = cID AND
      statusdate = maxDate;
    result.success := 1;
  END IF;
  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success := -1;
    RETURN result;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- create type to return a meeting tuple

DROP TYPE ms_meeting_tuple CASCADE;

CREATE TYPE ms_meeting_tuple AS (
  mID INTEGER,
  cID INTEGER,
  meetStart VARCHAR,
  meetEnd VARCHAR,
  meetStatus VARCHAR,
  success INTEGER);

-- given a meeting id, retrieve basic info about that meeting
-- returns:
--    a struct with success field set to
--        0 for no such meeting
--        1 for info retrieved successfully
--        -1 for error

CREATE OR REPLACE FUNCTION ms_getMeeting(mID INTEGER) RETURNS MS_MEETING_TUPLE AS $$

DECLARE
  result MS_MEETING_TUPLE;
  meetCount INTEGER;
  oneline RECORD;

BEGIN
  SELECT COUNT (*)                     -- is there a meeting with the given id
  INTO meetCount
  FROM ms_meeting
  WHERE meetingID = mID;

  IF meetCount = 0 THEN
    result.success := 0;
  ELSIF meetCount = 1 THEN
    SELECT *                           -- retrieve the meeting info
    INTO oneline
    FROM ms_meeting
    WHERE meetingID = mID;

    result.mID := oneline.meetingID;   -- copy info to the return struct
    result.cID := oneline.caseID;
    result.meetStart := oneline.meetingStart;
    result.meetEnd := oneline.meetingEnd;
    result.meetStatus := oneline.meetingStatus;
    result.success := 1;
  END IF;

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    result.success := -1;
    RETURN result;
END;

$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
