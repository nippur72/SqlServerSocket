// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library sql_server_socket_test;

import '../lib/sqlconnection.dart';
import '../lib/table.dart';
import '../lib/sqlformats.dart';

import 'dart:async';

import "package:guinness/guinness.dart";

void main()
{
   defineTests().then((_)
   {
      print("done");
   });
}   

Future defineTests() async
{  
   /// define a common database where to perform all tests
   
   var conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=master;Trusted_Connection=yes;");
   //var conn = new SqlConnection("Server=DEVIL\\SQLEXPRESS;Database=master;User Id=sa;Password=;");
   
   await conn.open();
   await conn.execute("IF EXISTS (SELECT name FROM master.sys.databases WHERE name = 'sql_server_socket_test_db') DROP DATABASE sql_server_socket_test_db");
   await conn.execute("CREATE DATABASE sql_server_socket_test_db");
   await conn.execute("USE sql_server_socket_test_db");
   await conn.execute("CREATE TABLE Customers (Id INT IDENTITY PRIMARY KEY, Name VARCHAR(64), Age INT, Born DATETIME, HasWebSite BIT NOT NULL)");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite) VALUES ('Bob' ,33, 0)");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite, Born) VALUES ('Tom' ,42, 1, ${sqlDate(new DateTime(1972,05,03))})");
   await conn.execute("INSERT INTO Customers (Name, Age, HasWebSite) VALUES ('Mary',18, 1)");
   await conn.close();
      
   conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=sql_server_socket_test_db;Trusted_Connection=yes;");
   //conn = new SqlConnection("Server=DEVIL\\SQLEXPRESS;Database=sql_server_socket_test_db;User Id=sa;Password=;");
  
   describe("SQL formatting functions", ()
   {
       describe("sqlDate()", ()  
       {
          it("returns a SQL formatted date", ()
          {
             var d = sqlDate(new DateTime(1980,5,3));             
             expect(d).toEqual("CONVERT(DATETIME,'1980-05-03 00:00:00.000',102)");             
          });
       });   
    
       describe("sqlBool()", ()  
       {
          it("converts true and false into 1 and 0", ()
          {                 
             expect(sqlBool(false)).toEqual("0");
             expect(sqlBool(true )).toEqual("1");         
          });
       });
    
       describe("sqlString()", ()
       {    
          it("sqlString() formats a string to SQL, keeping care of single quotes", ()
          {                 
             expect(sqlString("ONE'TWO''THREE'''")).toEqual("'ONE''TWO''''THREE'''''''");                  
          });
       });
   });

   // TODO connection tests (ports/service running etc)
   
   describe('SqlConnection methods', ()  
   {   
      beforeEach(() async
      {
         await conn.open();
      });
      
      afterEach(() async
      {
         await conn.close();
      });

      describe("execute()", ()
      {
         it("returns the number of rows effected", () async
         {
            var n = await conn.execute("UPDATE Customers SET HasWebSite=1 WHERE HasWebSite=1");
            expect(n).toEqual(2);
         });
         
         it("does UPDATE commands correctly when not changing anything", () async
         {
            var n = await conn.execute("UPDATE Customers SET HasWebSite=1 WHERE HasWebSite=1");
            expect(n).toEqual(2);
         });
            
         it("returns 0 when nothing done", () async
         {
            var n = await conn.execute("UPDATE Customers SET HasWebSite=1 WHERE 0=1");
            expect(n).toEqual(0);            
         });
            
         it("does UPDATE commands correctly", () async
         {
            var n = await conn.execute("UPDATE Customers SET Name='Bill' WHERE Name='Bob'");
            expect(n).toEqual(1);            
 
            var n1 = await conn.queryValue("SELECT COUNT(*) FROM Customers WHERE Name='Bob'");
            var n2 = await conn.queryValue("SELECT COUNT(*) FROM Customers WHERE Name='Bill'");
            expect(n1).toEqual(0);
            expect(n2).toEqual(1);

            n = await conn.execute("UPDATE Customers SET Name='Bob' WHERE Name='Bill'");  // reverts back 
            expect(n).toEqual(1);
         });         
      });
      
      describe("queryValue()", ()
      {
         it("returns null when quering empty rows", () async
         {                  
            // no customers named 'Mark'
            var n = await conn.queryValue("SELECT Name FROM Customers WHERE Name='Mark'");
            expect(n,null);
         });
         
         it("returns an integer value from query", () async
         {
            // Mary's Age is 18
            var age = await conn.queryValue("SELECT Age FROM Customers WHERE Name='Mary'");
            expect(age,18);
         });
         
         it("returns a boolean from query", () async
         {
            // Mary has a web site
            var bit = await conn.queryValue("SELECT HasWebSite FROM Customers WHERE Name='Mary'");
            expect(bit,true);
         });
         
         it("returns a String from query", () async
         {
            // Bob does not have a website
            var name = await conn.queryValue("SELECT Name FROM Customers WHERE HasWebSite=0");
            expect(name,"Bob");
         });

         it("returns null when queried field is null", () async
         {         
            // First customer does not have a date
            var born = await conn.queryValue("SELECT Born FROM Customers");
            expect(born,null);
         });
                  
         it("returns a DateTime from query", () async
         {            
            var tomsborn = await conn.queryValue("SELECT Born FROM Customers WHERE Name = 'Tom'");
            expect(tomsborn is DateTime).toEqual(true);
            expect(tomsborn).toEqual(new DateTime(1972,05,03));
         });               
      });
   });
   
   /*     
    });

    test('querySingle()', () async 
    {
       await conn.open();
              
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
 
  */  
}
  
