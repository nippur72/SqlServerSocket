// Copyright (c) 2015, Antonino Porcino. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import '../lib/sqlconnection.dart';

main() async
{
   //var connstr = @"Server=DEVIL\\SQLEXPRESS;Database=Phoenix64;User Id=sa;Password=;";
   SqlConnection conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=Portento;Trusted_Connection=yes;");

   await conn.open();
      
   print("connected");
   
   List rows = await conn.query("SELECT TOP 3 * FROM Comuni_Anagrafe");
      
   print("queried");
   
   for(var r in rows)
   {
      print(r["Cognome"]);
   }
   
   var s = await conn.queryValue("SELECT db_name()");
   
   print("dbname=$s");
   
   await conn.close();
   
   print("done");
}

