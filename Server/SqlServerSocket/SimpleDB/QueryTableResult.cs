using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleDB
{
   public class QueryTableResult
   {
      public List<Row> rows;
      public string TableName;
      public ColumnDefinitions columns;     
   }
}
