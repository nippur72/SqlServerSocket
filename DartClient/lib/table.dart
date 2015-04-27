
import "dart:async";

import "sqlconnection.dart";

// information about a column as filled by SQL Server
class ColumnDefinition
{
   String ColumnName;
   String DataTypeName;
   bool AllowDBNull;
   bool IsIdentity;
   bool IsKey;
   bool IsReadOnly;
   int ColumnSize;
   String BaseTableName;
   
   ColumnDefinition.fromMap(Map map)
   {
      ColumnName    = map["ColumnName"];
      DataTypeName  = map["DataTypeName"];
      AllowDBNull   = map["AllowDBNull"];
      IsIdentity    = map["IsIdentity"];
      IsKey         = map["IsKey"];
      IsReadOnly    = map["IsReadOnly"];
      ColumnSize    = map["ColumnSize"];
      BaseTableName = map["BaseTableName"];      
   }
}

// stores modified rows to send to server for updating the dataset 
class ChangeSet
{
   String tablename;
   List inserted     = new List();
   List deleted      = new List();
   List updated_new  = new List();
   List updated_old  = new List();  
   
   Map toEncodable() => 
   { 
      "tablename"   : tablename, 
      "inserted"    : inserted, 
      "deleted"     : deleted, 
      "updated_new" : updated_new,
      "updated_old" : updated_old
   };   
}

// response from server after a "postback", containing IDENTITY numbers 
// assigned by the database server after an INSERT operation.
// These numbers are used to update the local copy of the Table
class PostBackResponse
{
   String idcolumn;
   List<int> identities;
}

// table result from "queryTable". 
//
// Insert, update or delete operations done on the Table object
// can be sent back to server via Table.post().
class Table
{
   SqlConnection _conn;   
   String tableName;
   List<Map<String,dynamic>> rows;   
   List<ColumnDefinition> columns;        
   
   List<Map<String,dynamic>> originalrows;       
   
   static const originalIndex = "_originalIndex";
   
   bool get modified
   {
      var chg = _detectChanges();      
      return (chg.inserted.length!=0 || chg.deleted.length!=0 || chg.updated_new.length!=0);
   }
   
   Table(SqlConnection conn, String tableName, List<Map<String,dynamic>> rows, List<Map<String,String>> columns)
   {
      this._conn = conn;
      this.tableName = tableName;
      this.rows = rows;
      
      // keep a shallow copy of original rows for compare
      this.originalrows = _copyRows(this.rows);
      
      // build column definitions
      this.columns = new List<ColumnDefinition>();
      for(var coldef in columns)
      {
         this.columns.add(new ColumnDefinition.fromMap(coldef));
      }      

      // add _originalIndex field
      this._addOriginalIndexField(this.rows);
      this._addOriginalIndexField(this.originalrows);
      
      // fix types 
      for(var column in this.columns)
      {
         TypeFixer.fixColumn(rows, column.ColumnName, column.DataTypeName);
      }
   }
   
   /// adds an hidden field "_originalIndex" to keep track of changes done on the rows
   void _addOriginalIndexField(List rows)
   {
      for(int t=0;t<rows.length;t++)
      {
         var r = rows[t];
         r[originalIndex] = t;  
      }      
   }
   
   /// creates a shallow copy of a whole list of rows
   List<Map<String,dynamic>> _copyRows(List<Map<String,dynamic>> rows)
   {
      List<Map<String,dynamic>> result = [];
      for(int t=0;t<rows.length;t++)
      {
         result.add(_copyRow(rows[t]));
      }
      return result;
   }
   
   /// creates a shallow copy of a row
   Map<String,dynamic> _copyRow(Map row)
   {      
      return new Map.from(row);
   }
   
   /// compare two rows
   bool _areRowEquals(Map<String,dynamic> row1, Map<String,dynamic> row2)
   {
      if(row1.length != row2.length) return false;
      
      for(var key in row1.keys)
      {
         if(row1[key]!=row2[key]) return false;
      }
      return true;
   }
   
   /// creates a new row for the table, filled with default values 
   Map<String,dynamic> newRow()
   {
      Map<String,dynamic> new_row = new Map<String,dynamic>(); 
      
      // create a new row 
      for(int t=0;t<columns.length;t++)
      {
         new_row[columns[t].ColumnName] = columns[t].AllowDBNull ? null : _defaultValue(columns[t].DataTypeName);
      }            
      return new_row;
   }
   
   /// sends table modifications to the server
   Future post() async
   {
      var postCompleter = new Completer();

      // calculate changes
      ChangeSet chg = _detectChanges();

      // if no changes, does not call server
      if(chg.inserted.length==0 && chg.deleted.length==0 && chg.updated_new.length==0) return postCompleter.future;  
      
      _conn.postBack(chg).then((response)
      {
         // update identities (they appeare the same order in chg.inserted
         var idcolumn = response.idcolumn;
         for(int t=0;t<response.identities.length;t++)
         {
            var row = chg.inserted[t];  // row points to this.rows           
            row[idcolumn] = response.identities[t];
         }
         
         // adds index field to inserted rows
         _addOriginalIndexField(this.rows);
         
         // update is ok, so accept changes
         this.originalrows = _copyRows(rows);         

         postCompleter.complete();                 
      })
      .catchError((error)
      {
         postCompleter.completeError(error);
      });      

      return postCompleter.future;
   }   
   
   /// detect changes occurred on the table by comparing its rows with "originalrows"
   /// and build a ChangeSet result to send to the server 
   ChangeSet _detectChanges()
   {
      ChangeSet chg = new ChangeSet();
      
      chg.tablename = tableName;
      
      // list of original indexes that are still alive   
      var remaining = new Set<int>();              

      // inserted: rows that does not have the "_originalIndex" field 
      for(int t=0;t<rows.length;t++)
      {
         var r = rows[t];

         if(!r.containsKey(originalIndex))
         {                         
             chg.inserted.add(r); 
         }
         else
         {
             remaining.add(r[originalIndex]);
         }
      }

      // deleted: rows in original that does not appear in remaining rows 
      for(int t=0;t<originalrows.length;t++)
      {
         if(!remaining.contains(originalrows[t][originalIndex]))
         {
            // row was deleted                       
            var deleted_row = _copyRow(originalrows[t]);
            deleted_row.remove(originalIndex);            
            chg.deleted.add(deleted_row); 
         }
      }

      // updated: rows not inserted that does not match original
      for(var t=0;t<rows.length;t++)
      {
         if(!rows[t].containsKey(originalIndex)) continue;
                  
         var current_row = rows[t];
         var index = current_row[originalIndex]; 
         var original_row = originalrows[index];

         if(!_areRowEquals(current_row, original_row))
         {
            // rows are different
            var cr = _copyRow(current_row ); cr.remove(originalIndex);
            var or = _copyRow(original_row); or.remove(originalIndex); 
            
            // strips from row fields that are equal
            var fields = new List.from(cr.keys); // copy to a new list to avoid concurrent cancellation
            for(var fieldname in fields)
            {
               if(cr[fieldname]==or[fieldname]) 
               {
                  cr.remove(fieldname);
                  or.remove(fieldname);
               }   
            }
                       
            chg.updated_new.add(cr);
            chg.updated_old.add(or);
         }
      }

      return chg;
   }      
   
   /// returns a default value for the SQL Server type specified
   dynamic _defaultValue(String type)
   {
      Map def = 
      { 
         "bit"      : false, 
         "varchar"  : "",
         "int"      : 0,
         "smallint" : 0,
         "decimal"  : 0.0, 
         "float"    : 0.0,      
         "datetime" : DateTime.parse("1899-12-30T12:00:00")
      };
      if(def.containsKey(type)) return def[type];
      throw "data type $type not supported";
   }
   
   /// undo changes on the table since last read or post()
   void cancel()
   {
      // keep a shallow copy of original rows for compare
      this.rows = _copyRows(originalrows);         
   }   
}

