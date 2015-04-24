using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.Data.SqlClient;

namespace SimpleDB
{   
   public class ColumnDefinitions : Dictionary<string,ColumnDefinition> 
   {
      public ColumnDefinitions(DataTable schema) : base()
      {
         for(int t=0;t<schema.Rows.Count;t++)
         {
            var column = schema.Rows[t];
            var cd = new ColumnDefinition();

            cd.ColumnName    = (string) column["ColumnName"];
            cd.DataTypeName  = (string) column["DataTypeName"];
            cd.AllowDBNull   = (bool)   column["AllowDBNull"];
            cd.IsIdentity    = (bool)   column["IsIdentity"];
            cd.IsKey         = (bool)   column["IsKey"];
            cd.IsReadOnly    = (bool)   column["IsReadOnly"];
            cd.ColumnSize    = (int)    column["ColumnSize"];  
            cd.BaseTableName = (string) column["BaseTableName"];
            
            this.Add(cd.ColumnName,cd);          
         }
      }                                              

      public string GetIdentityColumn()
      {
         foreach(var cd in this.Values)
         {
            if(cd.IsIdentity) return cd.ColumnName;
         }
         return null;
      }

      public string CommonTableName()
      {
         string tn = "";

         foreach(var cd in this.Values)
         {
            if(!cd.IsReadOnly)
            {
               if(tn=="") tn = cd.BaseTableName;
               if(tn!=cd.BaseTableName) return null;
            }
         }
         return tn;
      }
   }  

   public class ColumnDefinition
   {
      public string ColumnName;
      public string DataTypeName;
      public bool AllowDBNull;
      public bool IsIdentity;
      public bool IsKey;
      public bool IsReadOnly;
      public int ColumnSize;
      public string BaseTableName;
   }
}


