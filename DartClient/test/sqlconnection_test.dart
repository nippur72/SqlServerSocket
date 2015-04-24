// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library SockedSql_test;

import '../lib/sqlconnection.dart';
import 'package:unittest/unittest.dart';

void main() => defineTests();

void defineTests()
{
  group('SqlConnection tests', () 
  {
    test('test1', () async 
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
  });
}
