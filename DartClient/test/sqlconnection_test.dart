// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library sql_server_socket_test;

import '../lib/sqlconnection.dart';
import '../lib/table.dart';

import 'dart:async';
import 'package:unittest/unittest.dart';

void main()
{
   defineTests().then((_)
   {
      print("done");
   });
}   

Future defineTests() async
{  
   // define a common database where to perform all tests
   var conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=master;Trusted_Connection=yes;");
   
   await conn.open();
   await conn.execute("IF EXISTS (SELECT name FROM master.sys.databases WHERE name = 'sql_server_socket_test_db') DROP DATABASE sql_server_socket_test_db");
   await conn.execute("CREATE DATABASE sql_server_socket_test_db");
   await conn.execute("USE sql_server_socket_test_db");
   await conn.execute("CREATE TABLE Customers (Id INT IDENTITY PRIMARY KEY, Name VARCHAR(64), Age INT, Born DATETIME, HasWebSite BIT NOT NULL)");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite) VALUES ('Bob' ,33, 0)");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite) VALUES ('Tom' ,42, 1)");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite) VALUES ('Mary',18, 1)");
   await conn.close();
   
   conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=sql_server_socket_test_db;Trusted_Connection=yes;");

   group('SqlConnection tests', ()  
   {   
    // TODO connection tests (ports/service running etc)
    
    test('execute()', () async 
    {
       int n;
       
       await conn.open();

       n = await conn.execute("UPDATE Customers SET HasWebSite=1 WHERE HasWebSite=1");
       expect(n,2, reason: "returns the number of rows affected when are more than one");

       n = await conn.execute("UPDATE Customers SET HasWebSite=1 WHERE 0=1");
       expect(n,0, reason: "returns the number of rows affected when are none");
       
       n = await conn.execute("UPDATE Customers SET Name='Bill' WHERE Name='Bob'");
       expect(n,1);
       
       n = await conn.queryValue("SELECT COUNT(*) FROM Customers WHERE Name='Bob'");
       expect(n,0);

       n = await conn.execute("UPDATE Customers SET Name='Bob' WHERE Name='Bill'");  // reverts back 
       expect(n,1);
       
       await conn.close();
    });
    
    test('queryValue()', () async 
    {
       await conn.open();
       
       // no customers named 'Mark'
       var n = await conn.queryValue("SELECT Name FROM Customers WHERE Name='Mark'");
       expect(n,null, reason: "returns <null> when no rows");

       // Mary's Age is 18
       var age = await conn.queryValue("SELECT Age FROM Customers WHERE Name='Mary'");
       expect(age,18);

       // Mary has a web site
       var bit = await conn.queryValue("SELECT HasWebSite FROM Customers WHERE Name='Mary'");
       expect(bit,true);
       
       // First customer does not have a date
       var born = await conn.queryValue("SELECT Born FROM Customers");
       expect(born,null);

       // Bob does not have a website
       var name = await conn.queryValue("SELECT Name FROM Customers WHERE HasWebSite=0");
       expect(name,"Bob");

       await conn.close();
    });

    /*
 test('test generic', () async 
 {       
    var conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=master;Trusted_Connection=yes;");
    
    await conn.open();       
    expect(conn.connected, true);
    
    await conn.execute("CREATE DATABASE sql_test");
    await conn.execute("USE sql_test");
    var dbName = await conn.queryValue("SELECT db_name()"); 
    
    expect(conn.connected, true);
    expect(dbName, "sql_test");
    
    await conn.close();
    
    await conn.open();
   
    await conn.execute("DROP DATABASE sql_test");
    
    await conn.close();
    expect(conn.connected, false);
 });
 
 
 test("table", () async
 {
    var conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=master;Trusted_Connection=yes;");
    
    await conn.open();              
    
    //await conn.execute("CREATE DATABASE sql_test");
    await conn.execute("USE sql_test");
    //await conn.execute("CREATE TABLE Customers (Id INT IDENTITY PRIMARY KEY, Name VARCHAR(64), Age INT, Born DATETIME)");
    
    int n = await conn.queryValue("SELECT COUNT(*) FROM Customers");
    
    expect(n, 0);
    
    Table cust = await conn.queryTable("SELECT Id, Name, Age FROM Customers");
    
    expect(cust.rows.length,0);
    
    var r = cust.newRow();
    r["Name"] = "Porcino";
    r["Age"] = 74;
    cust.rows.add(r);
    
    await cust.post();
    
    n = await conn.queryValue("SELECT COUNT(*) FROM Customers");
    expect(n, 1);
    
    //await conn.execute("DROP TABLE Customers");

    //await conn.execute("DROP DATABASE sql_test");
    
    await conn.close();            
  });*/          
 });  
}
  
