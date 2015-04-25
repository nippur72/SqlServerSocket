// Copyright (c) 2015, Antonino Porcino. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import '../lib/sqlconnection.dart';
import '../lib/table.dart';

main() async
{
   //var connstr = @"Server=DEVIL\\SQLEXPRESS;Database=Phoenix64;User Id=sa;Password=;";
   SqlConnection conn = new SqlConnection("Server=localhost\\SQLEXPRESS;Database=Portento;Trusted_Connection=yes;");

   await conn.open();
      
   print("connected");
   
   /*
   List rows = await conn.query("SELECT TOP 3 Id,Nome,Cognome FROM Comuni_Anagrafe");
      
   print("queried");
   
   for(var r in rows)
   {
      print(r["Cognome"]);
   }
   */
   
   Table tab = await conn.queryTable("SELECT TOP 3 Id,Nome,Cognome FROM Comuni_Anagrafe");
      
   print("queried");
   
   for(var r in tab.rows)
   {
      print(r["Cognome"]);
   }
   
   var r = tab.newRow();
   r["Cognome"] = "pisapia";
   r["Nome"] = "alessio";
   tab.rows.add(r);
   
   await tab.post();
      
   /*
   var s = await conn.queryValue("SELECT DataStampa FROM Mag_DocMag WHERE DataStampa IS NOT NULL");
   
   assert(s is DateTime);
   
   print("dbname=$s");
   
   await conn.close();
   */
   
   print("done");
}
