
import "dart:async";

import "sqlconnection.dart";

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

class PostBackResponse
{
   String idcolumn;
   List<int> identities;
}

class Table
{
   SqlConnection _conn;   
   String tableName;
   List<Map<String,dynamic>> rows;   
   List<ColumnDefinition> columns;        
   
   List<Map<String,dynamic>> originalrows;
   
   bool modified;  
   
   Table(SqlConnection conn, String tableName, List<Map<String,dynamic>> rows, List<Map<String,String>> columns)
   {
      this._conn = conn;
      this.tableName = tableName;
      this.rows = rows;
      
      // keep a shallow copy of original rows for compare
      this.originalrows = _copyRows(rows);
      
      // build column definitions
      this.columns = new List<ColumnDefinition>();
      for(var coldef in columns)
      {
         this.columns.add(new ColumnDefinition.fromMap(coldef));
      }      

      // add _originalIndex field
      this._addIndexField(rows);
      this._addIndexField(originalrows);
      
      // TODO fix types
      
      modified = false;
   }
   
   void _addIndexField(List rows)
   {
      for(int t=0;t<rows.length;t++)
      {
         var r = rows[t];
         r["_originalIndex"] = t+1;  // number starting from 1, so 0=new insert
      }      
   }
   
   List<Map<String,dynamic>> _copyRows(List<Map<String,dynamic>> rows)
   {
      List<Map<String,dynamic>> result = [];
      for(int t=0;t<rows.length;t++)
      {
         result.add(_copyRow(rows[t]));
      }
      return result;
   }
   
   Map<String,dynamic> _copyRow(Map row)
   {      
      return new Map.from(row);
   }
   
   bool _areRowEquals(Map<String,dynamic> row1, Map<String,dynamic> row2)
   {
      if(row1.length != row2.length) return false;
      
      for(var key in row1.keys)
      {
         if(row1[key]!=row2[key]) return false;
      }
      return true;
   }
   
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
   
   Future post() async
   {
      var postCompleter = new Completer();

      // calculate changes
      ChangeSet chg = _detectChanges();

      // if no changes at all, does not call server
      if(!this.modified) return postCompleter.future;  
      
      _conn.postBack(chg).then((response)
      {
         // update identities (they appeare the same order in chg.inserted
         var idcolumn = response.idcolumn;
         for(int t=0;t<response.identities.length;t++)
         {
            var row = chg.inserted[t];             
            row[idcolumn] = response.identities[t];
         }
         
         // adds index field to inserted rows
         _addIndexField(this.rows);
         
         // update is ok, so accept changes
         this.originalrows = _copyRows(rows);
         this.modified = false;

         postCompleter.complete();                 
      })
      .catchError((error)
      {
         postCompleter.completeError(error);
      });      

      return postCompleter.future;
   }   
   
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

         if(!r.containsKey("_originalIndex"))
         {                         
             chg.inserted.add(r); 
         }
         else
         {
             remaining.add(r["_originalIndex"]);
         }
      }

      // deleted: rows in original that does not appear in remaining rows 
      for(int t=0;t<originalrows.length;t++)
      {
         if(!remaining.contains(originalrows[t]["_originalIndex"]))
         {
            // row was deleted                       
            var deleted_row = _copyRow(originalrows[t]);
            deleted_row.remove("_originalIndex");            
            chg.deleted.add(deleted_row); 
         }
      }

      // updated: rows not inserted that does not match original
      for(var t=0;t<rows.length;t++)
      {
         if(!rows[t].containsKey("_originalIndex")) continue;
                  
         var current_row = rows[t];
         var original_row = originalrows[current_row["_originalIndex"]];

         if(!_areRowEquals(current_row, original_row))
         {
            // rows are different
            var cr = _copyRow(current_row ); cr.remove("_originalIndex");
            var or = _copyRow(original_row); or.remove("_originalIndex"); 
            
            // strips from current data that are equal
            var fields = cr.keys;
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

      // updates modified property
      this.modified = (chg.inserted.length!=0 || chg.deleted.length!=0 || chg.updated_new.length!=0);

      return chg;
   }      
    
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
}






