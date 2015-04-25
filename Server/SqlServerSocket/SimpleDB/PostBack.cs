using System;
using System.Collections.Generic;
using System.Web;

using Newtonsoft;
using Newtonsoft.Json;
using SimpleDB;
using System.Data.SqlClient;
using System.Data;
using Newtonsoft.Json.Linq;

namespace SimpleDB
{
   // keep in sync with Client.DataTable
   public class ChangeSet
   {
      public string tablename;
      public List<Row> inserted;
      public List<Row> deleted;
      public List<Row> updated_new;
      public List<Row> updated_old;   
   }

   public class PostBackManager
   {
      public static dynamic DoPostBack(Database DB, ChangeSet changes)
      {
         // build list of used column names
         List<string> used_columns = new List<string>();
         if(changes.inserted   .Count>0) foreach(string n in changes.inserted   [0].Keys) if(!used_columns.Contains(n)) used_columns.Add(n);
         if(changes.deleted    .Count>0) foreach(string n in changes.deleted    [0].Keys) if(!used_columns.Contains(n)) used_columns.Add(n);      
         if(changes.updated_old.Count>0) foreach(string n in changes.updated_old[0].Keys) if(!used_columns.Contains(n)) used_columns.Add(n);

         // prepare identity column values to return to client
         List<int> identities = new List<int>();           

         // gets schema about the rows we're working on
         var namelist = StringUtils.CommaList(used_columns); 
         var schema = DB.GetSchema(used_columns.ToArray(), changes.tablename);     
         var columndefs = new ColumnDefinitions(schema);
         var idcolumn = columndefs.GetIdentityColumn();
         var used_columns_without_id = new List<string>(used_columns);
         used_columns_without_id.Remove(idcolumn);

         DB.BeginTrans();      

         try
         {
            // inserts
            for(int t=0;t<changes.inserted.Count;t++)
            {
               var row = changes.inserted[t];
               int inserted_id = DoInsert(DB, row, columndefs, used_columns_without_id, changes.tablename);
               identities.Add(inserted_id);
            }
      
            // deletes
            for(int t=0;t<changes.deleted.Count;t++)
            {
               var row = changes.deleted[t];
               DoDelete(DB, row, columndefs, used_columns, changes.tablename);
            }

            // updates
            for(int t=0;t<changes.updated_new.Count;t++)
            {
               var row = changes.updated_new[t];
               var old = changes.updated_old[t];
               DoUpdate(DB, row, old, columndefs, used_columns, changes.tablename);
            }
         }
         catch(PostBackException ex)
         {
            DB.RollBackTrans();         
            throw ex;
         }
         catch(Exception ex)
         {
            DB.RollBackTrans();
            throw ex;
         }
      
         DB.CommitTrans();               

         // postback ok
         var postback_response = new 
         {
            idcolumn = idcolumn,
            identities = identities
         };
            
         return postback_response;            
      }

      private static int DoInsert(Database DB, Row row, ColumnDefinitions schema, List<string> used_columns_without_id, string tablename)
      {
         // build SQL insert command         
         var fieldnames = StringUtils.CommaList(used_columns_without_id);
         List<string> parnames = new List<string>();
         for(int i=0;i<used_columns_without_id.Count;i++) parnames.Add(string.Format("@p{0}",i));
         var SQL = String.Format("INSERT INTO [{0}] ({1}) VALUES ({2}); SET @ID = SCOPE_IDENTITY()", tablename, fieldnames, StringUtils.CommaList(parnames));                  

         SqlCommand cmd = new SqlCommand(SQL,DB.Conn,DB.Trans);
         cmd.CommandTimeout = DB.TimeOut;

         for(int i=0;i<used_columns_without_id.Count;i++) 
         {
            var cname = used_columns_without_id[i];
            var parm = new SqlParameter();
            parm.Direction = ParameterDirection.Input;                   
            parm.ParameterName = string.Format("@p{0}",i);
            parm.SqlDbType = Database.TypeNameToSqlDbType(schema.Column(cname).DataTypeName);         
            parm.Value = Database.ToSqlValue(row[cname],parm.SqlDbType);                     
            parm.IsNullable = schema.Column(cname).AllowDBNull;
            cmd.Parameters.Add(parm);
         }
        
         // aggiunge al comando di insert la lettura di SCOPE_IDENTITY mediante parametro @ID                  
         {                                               
            var parm = new SqlParameter();
            parm.Direction = ParameterDirection.Output;                   
            parm.Size = 4;            
            parm.SqlDbType = SqlDbType.Int;
            parm.ParameterName = "@ID";
            parm.DbType = DbType.Int32;                                      
            cmd.Parameters.Add(parm);
         }

         int n = cmd.ExecuteNonQuery();

         if(n!=1)
         {
            throw new PostBackException("insert");
         }

         // reads inserted id value
         int returned_id = (int) cmd.Parameters["@ID"].Value;      

         cmd.Dispose();

         return returned_id;
      }

      private static void DoDelete(Database DB, Row old, ColumnDefinitions schema, List<string> used_columns, string tablename)
      {      
         List<string> oldnames = new List<string>();
      
         foreach(string fieldname in old.Keys) oldnames.Add(fieldname);
      
         List<string> whererules = new List<string>();
         for(int i=0;i<oldnames.Count;i++) 
         {
            var cname = oldnames[i];
            if(old[cname]==null) whererules.Add(string.Format("{0} IS NULL",oldnames[i],i));
            else                 whererules.Add(string.Format("{0}=@p{1}"  ,oldnames[i],i));
         }

         var SQL = String.Format("DELETE FROM [{0}] WHERE ({1})", tablename, StringUtils.AndList(whererules.ToArray()));                  

         SqlCommand cmd = new SqlCommand(SQL,DB.Conn,DB.Trans);
         cmd.CommandTimeout = DB.TimeOut;
        
         for(int i=0;i<oldnames.Count;i++) 
         {
            var cname = oldnames[i];
            var parm = new SqlParameter();
            parm.Direction = ParameterDirection.Input;                   
            parm.ParameterName = string.Format("@p{0}",i);
            parm.SqlDbType = Database.TypeNameToSqlDbType(schema.Column(cname).DataTypeName);         
            parm.Value = Database.ToSqlValue(old[cname],parm.SqlDbType);                     
            parm.IsNullable = schema.Column(cname).AllowDBNull;
            cmd.Parameters.Add(parm);
         }

         int n = cmd.ExecuteNonQuery();

         if(n!=1)
         {
            throw new PostBackException("delete");
         }

         cmd.Dispose();
      }

      private static void DoUpdate(Database DB, Row row, Row old, ColumnDefinitions schema, List<string> used_columns, string tablename)
      {      
         List<string> newnames = new List<string>();
         List<string> oldnames = new List<string>();

         foreach(string fieldname in row.Keys) newnames.Add(fieldname);
         foreach(string fieldname in old.Keys) oldnames.Add(fieldname);

         List<string> updaterules = new List<string>();
         for(int i=0;i<newnames.Count;i++)
         {
            updaterules.Add(string.Format("{0}=@p{1}",newnames[i],i));
         }
      
         List<string> whererules = new List<string>();
         for(int i=0;i<oldnames.Count;i++) 
         {
            var cname = oldnames[i];
            if(old[cname]==null) whererules.Add(string.Format("{0} IS NULL",oldnames[i],i+newnames.Count));
            else                 whererules.Add(string.Format("{0}=@p{1}"  ,oldnames[i],i+newnames.Count));
         }

         var SQL = String.Format("UPDATE [{0}] SET {1} WHERE ({2})", tablename, StringUtils.CommaList(updaterules), StringUtils.AndList(whererules));                  

         SqlCommand cmd = new SqlCommand(SQL,DB.Conn,DB.Trans);
         cmd.CommandTimeout = DB.TimeOut;

         for(int i=0;i<newnames.Count;i++) 
         {
            var cname = newnames[i];
            var parm = new SqlParameter();
            parm.Direction = ParameterDirection.Input;                   
            parm.ParameterName = string.Format("@p{0}",i);
            parm.SqlDbType = Database.TypeNameToSqlDbType(schema.Column(cname).DataTypeName);         
            parm.Value = Database.ToSqlValue(row[cname],parm.SqlDbType);                     
            parm.IsNullable = schema.Column(cname).AllowDBNull;
            cmd.Parameters.Add(parm);
         }
        
         for(int i=0;i<oldnames.Count;i++) 
         {
            var cname = oldnames[i];
            var parm = new SqlParameter();
            parm.Direction = ParameterDirection.Input;                   
            parm.ParameterName = string.Format("@p{0}",i+newnames.Count);
            parm.SqlDbType = Database.TypeNameToSqlDbType(schema.Column(cname).DataTypeName);         
            parm.Value = Database.ToSqlValue(old[cname],parm.SqlDbType);                     
            parm.IsNullable = schema.Column(cname).AllowDBNull;
            cmd.Parameters.Add(parm);
         }

         int n = cmd.ExecuteNonQuery();

         if(n!=1)
         {
            throw new PostBackException("update");
         }

         cmd.Dispose();
      }

   }
}

