// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library SockedSql_test;

import '../lib/sqlconnection.dart';
import '../lib/table.dart';

import 'package:unittest/unittest.dart';

void main() => defineTests();

void defineTests()
{
  group('SqlConnection tests', () 
  {
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
    */
    
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
    });
          
  });
}
