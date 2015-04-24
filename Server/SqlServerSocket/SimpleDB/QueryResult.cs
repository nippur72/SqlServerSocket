using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleDB
{
   public class QueryResult
   {
      public List<Row> rows = new List<Row>();      
      public Dictionary<string,string> columns = new Dictionary<string,string>();     
   }
}
