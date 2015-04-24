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
      public string Connessione; 
      public int TimeOut;
            
      public SqlConnection Conn;                        
      public SqlTransaction Trans;                                         
        
      public Database()
      {      
         Connessione = ""; 
         Conn = new SqlConnection();
         Trans = null;                                   
         TimeOut = 15;                 
      }

      public Database(string conn) : this()
      {
         Connessione = conn;
      }      

      public Database(SqlConnection sqlconn) : this()
      {
         Conn = sqlconn;
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
                                               
      public void Open()
      {
         Conn.ConnectionString = Connessione;                           
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

      public QueryTableResult QueryTable(string SQL, params object[] parms)
      {         
         List<Row> rows = new List<Row>();
         
         //var cmdtext = String.Format(SQLSyntax.Formatter,SQL,parms);
         var cmdtext = String.Format(SQL,parms);

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

      public List<Row> Query(string SQL, params object[] parms)
      {         
         List<Row> result = new List<Row>();
         
         //var cmdtext = String.Format(SQLSyntax.Formatter,SQL,parms);
         var cmdtext = String.Format(SQL,parms);

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.Default);  
                    
         while(dr.Read())
         {
            Row row = new Row();

            for(int t=0;t<dr.FieldCount;t++) 
            {
               row.Add(dr.GetName(t),dr.GetValue(t));
            }
            result.Add(row);
         }
         dr.Close();
         cmd.Dispose();
         return result;          
      }

      public Row QuerySingle(string SQL, params object[] parms)
      {         
         Row result = new Row();
         
         //var cmdtext = String.Format(SQLSyntax.Formatter,SQL,parms);
         var cmdtext = String.Format(SQL,parms);

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;
         SqlDataReader dr = cmd.ExecuteReader(CommandBehavior.SingleRow);
                                                                                 
         if(dr.FieldCount>0) 
         {            
            if(dr.Read())
            {
               for(int t=0;t<dr.FieldCount;t++) 
               {
                  result.Add(dr.GetName(t),dr.GetValue(t));
               }
            } else result = null; // 0-rows results in null response
         }
         else result = null; // 0-rows results in null response
         dr.Close();
         cmd.Dispose();
         return result;          
      }

      public dynamic QueryValue(string SQL, params object[] parms)
      {
         //var cmdtext = String.Format(SQLSyntax.Formatter,SQL,parms);
         var cmdtext = String.Format(SQL,parms);

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;          
           
         dynamic dr = cmd.ExecuteScalar();      
                                 
         cmd.Dispose();
         return dr;          
      }

      public int Execute(string SQL, params object[] parms)
      {
         //var cmdtext = String.Format(SQLSyntax.Formatter,SQL,parms);
         var cmdtext = String.Format(SQL,parms);

         SqlCommand cmd = new SqlCommand(cmdtext,Conn,Trans);
         cmd.CommandTimeout = TimeOut;          
           
         int nrows = cmd.ExecuteNonQuery(); 
                                 
         cmd.Dispose();
         return nrows;          
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


