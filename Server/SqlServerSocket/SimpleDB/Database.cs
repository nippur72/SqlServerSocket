using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.IO;
using System.Text.RegularExpressions;
using System.Data.SqlClient;

//using SQLSyntax = Portento.SQLSyntax;

namespace SimpleDB
{   
   public class Database : IDisposable
   {      
      public string connectionString; 
      public int TimeOut;
            
      public SqlConnection Conn;                        
      public SqlTransaction Trans;                                         
        
      public Database()
      {      
         connectionString = ""; 
         Conn = new SqlConnection();
         Trans = null;                                   
         TimeOut = 15;                 
      }

      public void Dispose()
      {      
         Dispose(true);
         GC.SuppressFinalize(this);
      }

      protected virtual void Dispose(bool disposing)
      {       
         if (disposing == true)
         {
            Close(); // call close here to close connection
         }
      }        

      ~Database()
      {        
         Dispose(false);
      }

      public bool Connected
      {
         get 
         {
            return Conn.State == ConnectionState.Open;
         }
      }
                                               
      public void Open()
      {
         Conn.ConnectionString = connectionString;                           
         Conn.Open();            
      }  
      
      public void Close()
      {
         Conn.Close();
      }                 
        
      public void BeginTrans()
      {                      
         Trans = Conn.BeginTransaction();          
      }

      public void CommitTrans()
      {
         if(Trans!=null) Trans.Commit();
      }

      public void RollBackTrans()
      {
         if(Trans!=null) Trans.Rollback();           
      }

      public QueryTableResult QueryTable(string SQL)
      {         
         List<Row> rows = new List<Row>();
                  
         var cmdtext = SQL;

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.KeyInfo);
         
         var schema = dr.GetSchemaTable();  
         var coldefs = new ColumnDefinitions(schema);
                    
         while(dr.Read())
         {
            Row row = new Row();

            for(int t=0;t<dr.FieldCount;t++) 
            {
               row.Add(dr.GetName(t),dr.GetValue(t));
            }
            rows.Add(row);
         }
         dr.Close();
         cmd.Dispose();

         var qtr = new QueryTableResult();
         qtr.rows = rows;
         qtr.columns = coldefs;
         qtr.TableName = coldefs.CommonTableName();

         return qtr;          
      }

      public QueryResult Query(string SQL)
      {         
         var result = new QueryResult();
                           
         var cmdtext = SQL;

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.Default);  
                    
         while(dr.Read())
         {
            Row row = new Row();

            for(int t=0;t<dr.FieldCount;t++) 
            {
               string fieldName = dr.GetName(t);
               object fieldValue = dr.GetValue(t);
               row.Add(fieldName,fieldValue);
               
               if(result.rows.Count==0) result.columns.Add(fieldName, dr.GetDataTypeName(t));
            }
            result.rows.Add(row);
         }
         dr.Close();
         cmd.Dispose();
         
         return result;          
      }

      public QueryResult QuerySingle(string SQL)
      {         
         var result = new QueryResult();
                  
         var cmdtext = SQL;

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.SingleRow);
                                                                                 
         if(dr.FieldCount>0) 
         {            
            if(dr.Read())
            {
               Row row = new Row();               
               for(int t=0;t<dr.FieldCount;t++) 
               {
                  string fieldName = dr.GetName(t);
                  object fieldValue = dr.GetValue(t);
                  row.Add(fieldName,fieldValue);
               
                  if(result.rows.Count==0) result.columns.Add(fieldName, dr.GetDataTypeName(t));                  
               }
               result.rows.Add(row);
            }             
         }                          

         dr.Close();
         cmd.Dispose();
         return result;          
      }

      public QueryResult QueryValue(string SQL)
      {
         var result = new QueryResult();
                  
         var cmdtext = SQL;

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.SingleRow);
                                                                                 
         if(dr.FieldCount>0) 
         {            
            if(dr.Read())
            {
               Row row = new Row();
               
               for(int t=0;t<1;t++) 
               {
                  string fieldName = "value"; // dr.GetName(t);
                  object fieldValue = dr.GetValue(t);
                  row.Add(fieldName,fieldValue);
               
                  if(result.rows.Count==0) result.columns.Add(fieldName, dr.GetDataTypeName(t));                  
               }

               result.rows.Add(row);
            } 
         }                  

         dr.Close();
         cmd.Dispose();
         return result;                         
      }

      public QueryResult Execute(string SQL)
      {         
         var cmdtext = SQL;

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;          
           
         int rowsAffected = cmd.ExecuteNonQuery(); 
         
         var result = new QueryResult();
         Row row = new Row();
         row.Add("rowsAffected",rowsAffected);
         result.rows.Add(row);
         result.columns.Add("rowsAffected","int");
                                 
         cmd.Dispose();
         return result;          
      }

      public DataTable GetSchema(string[] columns, string tablename)
      {
         var namelist = StringUtils.CommaList(columns);
         var cmdtext = String.Format("SELECT TOP 0 {0} FROM {1}",namelist,tablename);
         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.KeyInfo);
         var DT = dr.GetSchemaTable();
         dr.Close();
         cmd.Dispose();
         return DT;
      } 
                            
      public static SqlDbType TypeNameToSqlDbType(string tn)
      {
         SqlDbType tipo;

         if(Enum.TryParse<SqlDbType>(tn, true, out tipo)) return tipo;
         else 
         {
            throw new Exception("unable to convert type");
         }         
      }

      public static object ToSqlValue(object val, SqlDbType tipo)
      {
         if(val==null) return DBNull.Value;
         return val;         
      }
   }
}


