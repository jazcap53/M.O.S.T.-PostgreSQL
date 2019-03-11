-- File: createTablesPg.sql
-- Andrew Jarcho
-- modified 7/23/2011 4:30p
-- create tables for MSTS project  MIGRATED TO POSTGRESQL
-- create sequences
-- create initial administrator account

 
-- there are three basic entities: accounts, cases, and roles
-- an account is a user, a case is a dispute, and a role is
--    Admin, Mediator, or Client
-- each user has a single account
-- an ms_accountCaseRole table entry links one account with one 
--    case and one role
-- a user may have different roles in different cases


-- create account table
-- there will be one Admin account
-- and accounts for each Mediator and Client
DROP TABLE ms_account CASCADE;

CREATE TABLE ms_account
(logname          VARCHAR(20),
 lastName         VARCHAR(30) NOT NULL,
 firstName        VARCHAR(30) NOT NULL,
 middleInitial    CHAR(1),
 homePhone        VARCHAR(20),
 workPhone        VARCHAR(20),
 cellPhone        VARCHAR(20),
 email            VARCHAR(100) NOT NULL,
 password         VARCHAR(40) NOT NULL,
 PRIMARY KEY (logname));
 

-- create logInOut table
-- track times of logins, logouts
DROP TABLE ms_logInOut CASCADE;

CREATE TABLE ms_logInOut
(logname          VARCHAR(20),
 logDate          TIMESTAMP WITH TIME ZONE,
 caseID           INTEGER NOT NULL,
 PRIMARY KEY (logname, logDate),
 FOREIGN KEY (logname) REFERENCES ms_account);              


-- create case table
-- each dispute has one tuple
DROP TABLE ms_case CASCADE;

CREATE TABLE ms_case
(caseID           INTEGER,
 caseTitle        VARCHAR(40) NOT NULL UNIQUE,
 PRIMARY KEY (caseID));


-- create accountCaseRole table
-- link an account, a case, and a role
DROP TABLE ms_accountCaseRole CASCADE;

CREATE TABLE ms_accountCaseRole
(logname          VARCHAR(20),
 caseID           INTEGER,
 role             VARCHAR(20) NOT NULL CHECK (role IN ('Mediator', 'Client', 'Admin')),
 PRIMARY KEY (logname, caseID),
 FOREIGN KEY (logname) REFERENCES ms_account,
 FOREIGN KEY (caseID) REFERENCES ms_case);


-- create caseState table
-- associate a state (a.k.a. status) with each case
-- record all changes in case state as well as the
--    timestamp of each change
DROP TABLE ms_caseState CASCADE;

CREATE TABLE ms_caseState
(caseID           INTEGER,
 caseStatus       VARCHAR(20) CHECK (caseStatus IN ('Opened', 'Suspended', 'Reopened', 'Resolved', 'Terminated')),
 statusDate       TIMESTAMP WITH TIME ZONE,
 PRIMARY KEY (caseID, caseStatus, statusDate),
 FOREIGN KEY (caseID) REFERENCES ms_case);


-- create document table
-- document id , type, and title are stored here, as well as the
--    case to which the document belongs
-- document contents (text) are NOT stored here
-- document contents are stored in the ms_docVersion table
DROP TABLE ms_document CASCADE;

CREATE TABLE ms_document
(docID            INTEGER,
 type             VARCHAR(20) NOT NULL CHECK (type IN ('PrelimAgr', 'IntermedAgr', 'FinalAgr', 'Misc', 'Meeting', 'Position', 'StatusRpt')),
 title            VARCHAR(40) NOT NULL,
 caseID           INTEGER NOT NULL,
 docOut           CHAR(1) NOT NULL CHECK (docOut IN ('y', 'n')),
 PRIMARY KEY (docID),
 FOREIGN KEY (caseID) REFERENCES ms_case);


-- create document version table
-- each document may have a series of versions
-- only the latest version may be edited, but
--    any version may be viewed
DROP TABLE ms_docVersion CASCADE;

CREATE TABLE ms_docVersion
(docID            INTEGER,
 version          INTEGER,
 dateCreated      TIMESTAMP WITH TIME ZONE NOT NULL,
 body             VARCHAR,
 PRIMARY KEY (docID, version),
 FOREIGN KEY (docID) REFERENCES ms_document);


-- create document access table
-- only a user who has been granted access may sign a document
DROP TABLE ms_docAccess CASCADE;

CREATE TABLE ms_docAccess
(docID            INTEGER,
 logname          VARCHAR(20),
 PRIMARY KEY (docID, logname),
 FOREIGN KEY (docID) REFERENCES ms_document,
 FOREIGN KEY (logname) REFERENCES ms_account);


-- create document signature table
-- records that a user signed a document, as
--    well as the timestamp and place
DROP TABLE ms_docSignature CASCADE;

CREATE TABLE ms_docSignature
(docID            INTEGER,
 version          INTEGER,
 logname          VARCHAR(20),
 sigDate          TIMESTAMP WITH TIME ZONE NOT NULL,
 sigPlace         VARCHAR(40) NOT NULL,
 PRIMARY KEY (docID, version, logname),
 FOREIGN KEY (docID) REFERENCES ms_document,
 FOREIGN KEY (docID, version) REFERENCES ms_docVersion,
 FOREIGN KEY (docID, logname) REFERENCES ms_docAccess,
 FOREIGN KEY (logname) REFERENCES ms_account);


-- create meeting table
-- records a scheduled meeting
-- with case ID
-- date/time and status
DROP TABLE ms_meeting CASCADE;

CREATE TABLE ms_meeting
(meetingID           INTEGER,
 caseID              INTEGER NOT NULL,
 meetingStart        TIMESTAMP WITH TIME ZONE NOT NULL,
 meetingEnd          TIMESTAMP WITH TIME ZONE NOT NULL,
 meetingStatus       VARCHAR(20) NOT NULL CHECK (meetingStatus IN ('Open', 'Held', 'Cancelled')),
 PRIMARY KEY (meetingID),
 FOREIGN KEY (caseID) REFERENCES ms_case);


-- create attendance table
-- records who is scheduled to attend a meeting
-- and whether they were actually present
DROP TABLE ms_attendance CASCADE;

CREATE TABLE ms_attendance
(meetingID        INTEGER,
 logname          VARCHAR(20),
 present          CHAR(1) CHECK (present IN ('y', 'n', null)),
 PRIMARY KEY (meetingID, logname),
 FOREIGN KEY (meetingID) REFERENCES ms_meeting);


-- create available table
-- times when a participant is available to meet
DROP TABLE ms_available CASCADE;

CREATE TABLE ms_available
(logname       VARCHAR(20),
 caseID        INTEGER, 
 availStart    TIMESTAMP WITH TIME ZONE NOT NULL,
 availEnd      TIMESTAMP WITH TIME ZONE NOT NULL,     -- may be infinity
 PRIMARY KEY (logname, caseID, availStart, availEnd),
 FOREIGN KEY (logname) REFERENCES ms_account,
 FOREIGN KEY (caseID) REFERENCES ms_case);


-- create message sent table
-- hold message details including text
DROP TABLE ms_messageSent CASCADE;

CREATE TABLE ms_messageSent
(messageID      INTEGER,
 caseID         INTEGER NOT NULL,
 sender         VARCHAR(20) NOT NULL,
 timeSent       TIMESTAMP WITH TIME ZONE NOT NULL,
 subject	VARCHAR(80),
 body		VARCHAR,
 PRIMARY KEY (messageID),
 FOREIGN KEY (sender) REFERENCES ms_account);


-- create meeting/document pair table
-- each meeting may have an associated meeting doc
DROP TABLE ms_meetingDocumentPair CASCADE;

CREATE TABLE ms_meetingDocumentPair
(meetingID INTEGER,
 docID INTEGER,
 PRIMARY KEY (meetingID, docID),
 FOREIGN KEY (meetingID) REFERENCES ms_meeting,
 FOREIGN KEY (docID) REFERENCES ms_document);


-- create message recipient table
-- a message may have multiple recipients
-- does NOT hold message text, which is in 
--    ms_messageSent
DROP TABLE ms_messageRecipient;

CREATE TABLE ms_messageRecipient
(messageID     INTEGER,
 recipient     VARCHAR(20) NOT NULL,
 read          CHAR(1) NOT NULL CHECK (read IN ('y', 'n')),
 timeRead      TIMESTAMP WITH TIME ZONE,
 PRIMARY KEY (messageID, recipient),
 FOREIGN KEY (messageID) REFERENCES ms_messageSent,
 FOREIGN KEY (recipient) REFERENCES ms_account);


-- create table to hold initial and final agreements of resolved case
-- these tables are independent of the rest of the database
-- initial and final agreements will remain after other documents
--    have been destroyed
DROP TABLE ms_initialAndFinalAgreements;

CREATE TABLE ms_initialAndFinalAgreements
(caseNumber        INTEGER,
 initialAgreement  VARCHAR NOT NULL,
 finalAgreement    VARCHAR NOT NULL,
 PRIMARY KEY (caseNumber));


-- create sequence for ms_case::caseID
DROP SEQUENCE ms_caseIDSeq;

CREATE SEQUENCE ms_caseIDSeq START WITH 1000;


-- create sequence for ms_meeting::meetingID
DROP SEQUENCE ms_meetingIDSeq;

CREATE SEQUENCE ms_meetingIDSeq START WITH 1;


-- create sequence for ms_document::docID
DROP SEQUENCE ms_docIDSeq;

CREATE SEQUENCE ms_docIDSeq START WITH 1;


-- create sequence for ms_messageSent::messageID
DROP SEQUENCE ms_messageIDSeq;

CREATE SEQUENCE ms_messageIDSeq START WITH 1;


-- create the default account
INSERT INTO ms_account (logname, password, lastName, firstName, email)
values('Admin01', crypt('Admin01', gen_salt('md5')), 'Admin01', 'Admin01', 'Admin01@Admin01');
