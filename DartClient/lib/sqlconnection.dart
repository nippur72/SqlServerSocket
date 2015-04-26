
library sql_server_socket;

import "dart:io";
import "dart:async";
import "dart:convert";

import "table.dart";

class SqlConnection
{
   Socket _socket;
   StringBuffer _receiveBuffer;
   Completer _completer;
   bool _connected;
   
   String _address;
   int _port;
   String _connectionString;
   
   SqlConnection(String connStr, {String address: "localhost", int port: 10980})
   {
      _address = address;
      _port = port;
      _connected = false;
      _connectionString = connStr;
   }
   
   /// tells if database is connected
   bool get connected => _connected;  
   
   /// connects to sql server database using the specified connection string
   Future<bool> open() async
   {
      try
      {
         this._socket = await Socket.connect(_address, _port);           
         //print("Connected to: ${_socket.remoteAddress.address}:${_socket.remotePort}");
      }
      catch(ex)
      {
         throw "can't connect to ${_address}:${_port} -- $ex";         
      }
       
      //Establish the onData, and onDone callbacks
      _socket.transform(UTF8.decoder)
             .listen(_receiveData, onError: _onError, onDone: _onDone);
      
      var connectCompleter = new Completer();
      
      String json = JSON.encode({ "type": "open", "text": _connectionString });
      
      _SendCommand(json).then((result) 
      {
         var res = _parseResult(result);
         if(res is _OkResult)
         {
           _connected = true;
           connectCompleter.complete(true);
         }
         else if(res is _ErrorResult)
         {
           _connected = false;
           connectCompleter.completeError(res.error);         
         }
         else throw "unknown response";
      })
      .catchError((err)
      {
         _connected = false;
         connectCompleter.completeError(err);
      });         
       
      return connectCompleter.future;
   }
   
   /// disconnects from sql server
   Future<bool> close()
   {
      if(!connected) throw "not connected";
      
      Completer disconnectCompleter = new Completer();
      
      String json = JSON.encode({ "type": "close", "text": "" });
      
      _SendCommand(json).then((risp)
      {
         var res = _parseResult(risp);
         
         if(res is _OkResult) 
         {
            _connected = false;
            disconnectCompleter.complete(true);
         }
         else if(res is _ErrorResult)
         {           
            disconnectCompleter.completeError(res.error);           
         }
         else throw "unknown response";
      })
      .catchError((err)
      {
        disconnectCompleter.completeError(err);    
      });               
      
      return disconnectCompleter.future;     
   }
   
   /// launch a query on the database, returning a table
   Future<Table> queryTable(String SQL)
   {      
      if(!connected) throw "not connected";
      
      String json = JSON.encode({ "type": "table", "text": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);

               if(res is _ErrorResult) compl.completeError(res.error);          
          else if(res is _TableResult) 
          {
              var tres = res as _TableResult;              
              Table tab = new Table(this, tres.tableName, tres.rows, tres.columns);
              compl.complete(tab);
          }
          else throw "unknown response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;
   }

   Future<PostBackResponse> postBack(ChangeSet chg)
   {      
      if(!connected) throw "not connected";
      
      String params = JSON.encode(chg.toEncodable());
      
      String json = JSON.encode({ "type": "postback", "text": params });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);

               if(res is _ErrorResult) compl.completeError(res.error);          
          else if(res is _PostBackResult) 
          {
              var tres = res as _PostBackResult; 
              PostBackResponse resp = new PostBackResponse();
              resp.idcolumn = tres.idcolumn;
              resp.identities = tres.identities;              
              compl.complete(resp);
          }
          else throw "invalid postback response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;           
   }
   
   /// launch a query on the database, returning all rows
   Future<List<Map<String,dynamic>>> query(String SQL)
   {      
      if(!connected) throw "not connected";
      
      String json = JSON.encode({ "type": "query", "text": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);
               if(res is _ErrorResult) compl.completeError(res.error);         
          else if(res is _QueryResult) compl.complete(res.rows);          
          else throw "unknown response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;
   }
   
   /// launch a query on the database, returning the first rows only
   Future<Map<String,dynamic>> querySingle(String SQL)
   {      
      if(!connected) throw "not connected";
      
      String json = JSON.encode({ "type": "querysingle", "text": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);
          
               if(res is _ErrorResult) compl.completeError(res.error);          
          else if(res is _QueryResult)
          {   
              if(res.rows.length==0) compl.complete(null);
              else                   compl.complete(res.rows[0]);
          }
          else throw "unknown response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;
   }

   /// launch a query on the database, returning the value from the first column of the first row
   Future<dynamic> queryValue(String SQL)
   {      
      if(!connected) throw "not connected";
      
      String json = JSON.encode({ "type": "queryvalue", "text": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);

               if(res is _ErrorResult) compl.completeError(res.error);         
          else if(res is _QueryResult)
          {
              if(res.rows.length==0) compl.complete(null);
              else                   compl.complete(res.rows[0]["value"]);
          }
          else throw "unknown response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;
   }

   /// executes a sql command, returning the number of rows affected
   Future<int> execute(String SQL)
   {      
      if(!connected) throw "not connected";
      
      String json = JSON.encode({ "type": "execute", "text": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = _parseResult(result);
          
               if(res is _ErrorResult) compl.completeError(res.error);          
          else if(res is _QueryResult)
          {
              if(res.rows.length==0) compl.complete(-1);
              else                   compl.complete(res.rows[0]["rowsAffected"]);
          }
          else throw "unknown response";
      })
      .catchError((err)
      {
          compl.completeError(err);  
      });
      return compl.future;
   }

   /// formats and write a command to the socket    
   Future<String> _SendCommand(String command)
   {
      // prepare buffer for response
      _receiveBuffer = new StringBuffer();
      
      _completer = new Completer();
      String cmd = command.length.toString() + "\r\n" + command;
      _socket.write(cmd);

      return _completer.future;
   }

   void _onDone()
   {
       //print("onDone()");
       //socket.destroy();
   }
   
   void _onError(error)
   {
       print("error occurred: $error");
   }
   
   /// receive data from socket and build a command string
   /// 
   /// client sends text-based commands with the format:
   /// size_of_command_string + "\r\n" + command_string
   void _receiveData(data)
   {      
      _receiveBuffer.write(data);
            
      String content = _receiveBuffer.toString();
      
      if(content.indexOf("\r\n")>0)
      {
         int x = content.indexOf("\r\n");
         int len = int.parse(content.substring(0,x)); // size of command string
         
         String cmd = content.substring(x+2);
         if(cmd.length==len)
         {           
           _completer.complete(cmd);           
         }              
      }
   }
   
   /// translates generic json result into a Result type
   dynamic _parseResult(String json)
   {
      Map result = JSON.decode(json);           
      
           if(result["type"]=="ok")       return new _OkResult("ok");      
      else if(result["type"]=="error")    return new _ErrorResult(result["error"]);      
      else if(result["type"]=="query")    return new _QueryResult(result["rows"], result["columns"]);            
      else if(result["type"]=="table")    return new _TableResult(result["tablename"], result["rows"], result["columns"]);
      else if(result["type"]=="postback") return new _PostBackResult(result["idcolumn"], result["identities"]);
      else throw "unknown response";
   }         
}

class _ErrorResult
{
   String error;
   
   _ErrorResult(String error)
   {
      this.error = error;
   }
}

class _OkResult
{
   String ok;
   
   _OkResult(String ok)
   {
      this.ok = ok;
   }
}

class _QueryResult
{
   List rows;
   Map  columns;

   _QueryResult(List rows, Map columns)
   {
       this.rows = rows;
       this.columns = columns;
       _fixTypes();
   }

   /// fix string data type coming from JSON into proper Dart data type
   void _fixTypes()
   {
      void _fixDateTime(String columnName)
      {
         for(int t=0;t<rows.length;t++) rows[t][columnName] = DateTime.parse(rows[t][columnName]);         
      }
      
      for(var fname in columns.keys)
      {
         if(columns[fname]=="datetime") _fixDateTime(fname);
      }
   }  
}

class _TableResult
{
   String tableName;
   List rows;   
   List columns;
   
   _TableResult(String tableName, List rows, List columns)
   {
       this.tableName = tableName;
       this.rows = rows;
       this.columns = columns;       
   }
}

class _PostBackResult
{
   String idcolumn;
   List<int> identities;
   
   _PostBackResult(String idcolumn, List<int> identities)
   {
       this.idcolumn = idcolumn;
       this.identities = identities;
   }
}

