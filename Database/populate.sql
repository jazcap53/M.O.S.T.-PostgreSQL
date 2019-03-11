-- file: populate.sql
-- modified: 6/2/2008 12:15a

-- create accounts

   SELECT ms_newaccount ('bgates01', 'Gates', 'Bill', 'billg@microsoft.com');
   SELECT ms_newaccount ('sjobs01', 'Jobs', 'Steve', 'stevej@apple.com');
   SELECT ms_newaccount ('jwapne01', 'Wapner', 'Judge', 'courtroom@TV.com');
   SELECT ms_newaccount ('ppan01', 'Pan', 'Peter', 'ppan@never.edu');
   SELECT ms_newaccount ('flegho01', 'Leghorn', 'Foghorn', 'rooster@yahoo.com');
   SELECT ms_newaccount ('hdumpt01', 'Dumpty', 'Humpty', 'bigegg@gmail.com');
   SELECT ms_newaccount ('fperdu01', 'Perdue', 'Frank', 'toughman@farm.com');
   SELECT ms_newaccount('jschmo01', 'Schmoe', 'Joe', 'jschmoe@aol.com');
  
-- create cases
   SELECT ms_newcase ('Apple vs. Microsoft');
   SELECT ms_newcase ('The Case of the Missing Peanut Butter');
   SELECT ms_newcase ('Which Came First');
   SELECT ms_newcase ('Test Case A');
   SELECT ms_newcase ('Test Case B');
   SELECT ms_newcase ('Test Case C');
   SELECT ms_newcase ('Test Case D');
   SELECT ms_newcase ('Test Case E');
   SELECT ms_newcase ('Test Case F');
   SELECT ms_newcase ('Test Case G');

-- link acct, case, role
   SELECT ms_newaccountcaserole('bgates01', 1000, 'Client');
   SELECT ms_newaccountcaserole('sjobs01', 1000, 'Client');
   SELECT ms_newaccountcaserole('jwapne01', 1000, 'Mediator');
   SELECT ms_newaccountcaserole('ppan01', 1001, 'Client');
   SELECT ms_newaccountcaserole('flegho01', 1002, 'Client');
   SELECT ms_newaccountcaserole('hdumpt01', 1002, 'Client');
   SELECT ms_newaccountcaserole('fperdu01', 1002, 'Mediator');
   SELECT ms_newaccountcaserole('jschmo01', 1000, 'Client');
   SELECT ms_newaccountcaserole('fperdu01', 1000, 'Client');
   SELECT ms_newaccountcaserole('jschmo01', 1001, 'Client');
   SELECT ms_newaccountcaserole('jschmo01', 1002, 'Client');

-- log in, out
   SELECT ms_login('bgates01', 'Default', 1000);
   SELECT ms_logout('bgates01');
   SELECT ms_login('bgates01', 'Default', 1000);
   SELECT ms_logout('bgates01');
   SELECT ms_login('sjobs01', 'Default', 1000);
   SELECT ms_logout('sjobs01');
   SELECT ms_login('flegho01', 'Default', 1002);
   SELECT ms_login('hdumpt01', 'Default', 1002);
   SELECT ms_login('fperdu01', 'Default', 1002);
   SELECT ms_login('fperdu01', 'Default', 1000);
   SELECT ms_logout('fperdu01');
   SELECT ms_login('fperdu01', 'Default', 1000);
   SELECT ms_login('jwapne01', 'Default', 900);

-- see who's logged in
   SELECT ms_isLoggedIn('ppan01');
   SELECT ms_isLoggedIn('bgates01');
   SELECT ms_isLoggedIn('sjobs01');
   SELECT ms_isLoggedIn('flegho01');
   SELECT ms_isLoggedIn('hdumpt01');
   SELECT ms_isLoggedIn('fperdu01');
   SELECT ms_isLoggedIn('jwapne01');

-- change passwords
   SELECT ms_changepassword('bgates01', 'Default', 'MSFT');
   SELECT ms_changepassword('sjobs01', 'Default', 'AAPL');
   SELECT ms_changepassword('jwapne01', 'Default', 'HangEm');
   SELECT ms_changepassword('flegho01', 'Default', 'Cluck');
   SELECT ms_changepassword('hdumpt01', 'Default', 'Geronimo');
   SELECT ms_changepassword('fperdu01', 'Default', 'ImTough');
   SELECT ms_changepassword('jschmo01', 'Default', 'Password');

-- create new docs
   SELECT ms_newdocument('PrelimAgr', 'Preliminary agreement to mediate', 'Bill Gates and Steve Jobs agree to mediate their dispute with Judge Wapner as the mediator.', 1000); 
   SELECT ms_newdocument('PrelimAgr', 'Preliminary agreement to mediate', 'Humpty Dumpty and Foghorn Leghorn agree to mediate their dispute with Frank Perdue as the mediator.', 1002); 
   SELECT ms_newdocument('Meeting', 'Minutes of meeting between BG and SJ', 'Steve says Hiya Bill  Bill says Hiya Steve', 1000);
   SELECT ms_newdocument('Meeting', 'Minutes of meeting between FL and HD', 'Foghorn says Cluck, cluck  Humpty says Smash', 1002);
   SELECT ms_newdocument('Position', 'On the Windows issue', 'Steve says Bill stole Windows from him. Bill says Steve stole it in the first place.', 1000);

-- create new doc versions
   SELECT ms_newdocversion(5, 'Steve and Bill agree theyre both thieves. Steve says Bill makes buggy software. Bill says the iPod is overpriced and overrated');

-- create doc access
   SELECT ms_newdocaccess(1, 'bgates01');
   SELECT ms_newdocaccess(1, 'sjobs01');
   SELECT ms_newdocaccess(1, 'jwapne01');   
   SELECT ms_newdocaccess(3, 'bgates01');
   SELECT ms_newdocaccess(3, 'sjobs01');
   SELECT ms_newdocaccess(3, 'jwapne01');
   SELECT ms_newdocaccess(2, 'hdumpt01');
   SELECT ms_newdocaccess(2, 'flegho01');
   SELECT ms_newdocaccess(2, 'fperdu01');
   SELECT ms_newdocaccess(5, 'bgates01');
   SELECT ms_newdocaccess(5, 'sjobs01');
   SELECT ms_newdocaccess(5, 'jwapne01');   

-- create doc signature
   SELECT ms_newdocsignature(1, 1, 'bgates01', 'nyc');
   SELECT ms_newdocsignature(1, 1, 'sjobs01', 'nyc');
   SELECT ms_newdocsignature(1, 1, 'jwapne01', 'nyc');
   SELECT ms_newdocsignature(3, 1, 'bgates01', 'redmond');
   SELECT ms_newdocsignature(3, 1, 'sjobs01', 'cupertino');
   SELECT ms_newdocsignature(2, 1, 'flegho01', 'kfc');
   SELECT ms_newdocsignature(2, 1, 'hdumpt01', 'mcdonalds');
   SELECT ms_newdocsignature(2, 1, 'fperdu01', 'mcdonalds');
   SELECT ms_newdocsignature(5, 1, 'bgates01', 'redmond');
   SELECT ms_newdocsignature(5, 1, 'sjobs01', 'cupertino');
   SELECT ms_newdocsignature(5, 2, 'bgates01', 'redmond');
   SELECT ms_newdocsignature(5, 2, 'sjobs01', 'cupertino');

-- update case state
   SELECT ms_updatecasestate(1001, 'Suspended');
   SELECT ms_updatecasestate(1002, 'Terminated');
   SELECT ms_updatecasestate(1007, 'Terminated');
   SELECT ms_updatecasestate(1008, 'Terminated');
   SELECT ms_updatecasestate(1009, 'Terminated');

-- create availabilities
   SELECT ms_addavailable('flegho01', 1002, '4/10/2007 12:00pm', '4/10/2007 6:00pm');
   SELECT ms_addavailable('hdumpt01', 1002, '4/1/2007 12:30am', '4/20/2007 11:30pm');
   SELECT ms_addavailable('fperdu01', 1002, '4/10/2007 11:30am', '4/10/2007 5:30pm');
   SELECT ms_addavailable('flegho01', 1002, '4/11/2007 12:00pm', '4/11/2007 6:00pm');
   SELECT ms_addavailable('fperdu01', 1002, '4/11/2007 11:30am', '4/11/2007 5:30pm');
   SELECT ms_addavailable('bgates01', 1000, '7/15/2008 12:30pm', '7/15/2008 5:00pm');
   SELECT ms_addavailable('sjobs01', 1000, '7/15/2008 9:00am', '7/15/2008 2:00pm');
   SELECT ms_addavailable('jwapne01', 1000, '7/15/2008 9:30am', '7/15/2008 5:00pm');

-- create meetings
   SELECT ms_newmeeting(1002, '4/10/2007 4:00pm', '4/10/2007 5:30pm');
   SELECT ms_newmeeting(1002, '4/11/2007 3:00pm', '4/11/2007 5:00pm');
   SELECT ms_newmeeting(1000, '7/15/2008 1:00pm', '7/15/2008 2:00pm');

-- associate meeting with its doc
   SELECT ms_storemeetingdocumentpair(1, 4);
   SELECT ms_storemeetingdocumentpair(3, 3);

-- create attendance
   SELECT ms_newattendance(1, 'hdumpt01');
   SELECT ms_newattendance(1, 'flegho01');
   SELECT ms_newattendance(1, 'fperdu01');
   SELECT ms_newattendance(2, 'hdumpt01');
   SELECT ms_newattendance(2, 'fperdu01');

-- update meeting status
   SELECT ms_updatemeetingstatus(2, 'Cancelled');   
   SELECT ms_updatemeetingstatus(1, 'Held');

-- update attendances
   SELECT ms_updateattendanceyn(1, 'hdumpt01', 'n');
   SELECT ms_updateattendanceyn(1, 'flegho01', 'y');

-- create some messages   
   SELECT ms_addmessage('fperdu01', 1002, 'Cancelling meeting', 'I wont be able to meet on April 11. I have the chicken pox.');
   SELECT ms_addmessage('jwapne01', 1000, 'Office painting', 'If we meet this week it will have to be in Room 320. My office is being painted.');
   SELECT ms_addmessage('jschmo01', 1000, 'Introduction', 'Hi Im Joe');
   SELECT ms_addmessage('jschmo01', 1002, 'Introduction', 'Hi Im Joe');
      
-- add recipients
   SELECT ms_addmessagerecipient(1, 'flegho01');
   SELECT ms_addmessagerecipient(1, 'hdumpt01');
   SELECT ms_addmessagerecipient(1, 'jschmo01');
   SELECT ms_addmessagerecipient(2, 'bgates01');
   SELECT ms_addmessagerecipient(2, 'sjobs01');
   SELECT ms_addmessagerecipient(2, 'jschmo01');
   SELECT ms_addmessagerecipient(4, 'fperdu01');
   SELECT ms_addmessagerecipient(3, 'jwapne01');

-- receive messages
   SELECT ms_readmessagereceived(1, 'flegho01');
   SELECT ms_readmessagereceived(1, 'hdumpt01');

-- create initial agreement
   SELECT ms_newdocument('PrelimAgr', 'Init Agreement', 'Peanut Butter', 1001);
   SELECT ms_newdocument('PrelimAgr', 'Init Agreement', 'Placeholder', 1003); 
   SELECT ms_newdocument('PrelimAgr', 'Init Agreement', 'Placeholder', 1004); 
   SELECT ms_newdocument('PrelimAgr', 'Init Agreement', 'Placeholder', 1005); 

-- create final agreement
   SELECT ms_newdocument('FinalAgr', 'Final Agreement', 'Bill Gates and Steve Jobs agree to disagree.', 1000); 
   SELECT ms_newdocument('FinalAgr', 'Final Agreement', 'Placeholder', 1003); 
   SELECT ms_newdocument('FinalAgr', 'Final Agreement', 'Placeholder', 1004); 
   SELECT ms_newdocument('FinalAgr', 'Final Agreement', 'Placeholder', 1005); 

-- resolve cases
   SELECT ms_updatecasestate(1000, 'Resolved');
   SELECT ms_updatecasestate(1003, 'Resolved');
   SELECT ms_updatecasestate(1004, 'Resolved');

-- store initial, final
   SELECT ms_storeinitialandfinal(1000, 'Placeholder preliminary agreement', 'Placeholder final agreement');
