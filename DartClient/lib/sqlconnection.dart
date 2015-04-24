
library SqlServerSocket;

import "dart:io";
import "dart:async";
import "dart:convert";

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
         throw "can't connect";         
      }
       
      //Establish the onData, and onDone callbacks
      _socket.transform(UTF8.decoder)
             .listen(_receiveData, onError: _onError, onDone: _onDone);
      
      var connectCompleter = new Completer();
      
      String json = JSON.encode({ "type": "open", "text": _connectionString });
      
      _SendCommand(json).then((result) {
         var res = _parseResult(result);
         if(res.isOk)
         {
           _connected = true;
           connectCompleter.complete(true);
         }
         else if(res.isError)
         {
           _connected = false;
           connectCompleter.completeError(res.error);         
         }
         else throw "unknown response";
      }).catchError((err)
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
         if(res.isOk) 
         {
            _connected = false;
            disconnectCompleter.complete(true);
         }
         else if(res.isError)
         {           
           disconnectCompleter.completeError(res.error);           
         }
         else throw "unknown response";
      }).catchError((err)
      {
        disconnectCompleter.completeError(err);    
      });               
      
      return disconnectCompleter.future;     
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
          if(res.isError)
          {
              compl.completeError(res.error);
          }
          else if(res.isData)
          {
              compl.complete(res.rows);
          }
          else throw "unknown response";
      }).catchError((err)
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
          if(res.isError)
          {
              compl.completeError(res.error);
          }
          else if(res.isData)
          {
              if(res.rows.length==0) compl.complete(null);
              else                   compl.complete(res.rows[0]);
          }
          else throw "unknown response";
      }).catchError((err)
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
          if(res.isError)
          {
              compl.completeError(res.error);
          }
          else if(res.isData)
          {
              if(res.rows.length==0) compl.complete(null);
              else                   compl.complete(res.rows[0]["value"]);
          }
          else throw "unknown response";
      }).catchError((err)
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
          if(res.isError)
          {
              compl.completeError(res.error);
          }
          else if(res.isData)
          {
              if(res.rows.length==0) compl.complete(-1);
              else                   compl.complete(res.rows[0]["rowsAffected"]);
          }
          else throw "unknown response";
      }).catchError((err)
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
   Result _parseResult(String json)
   {
      Map result = JSON.decode(json);
      
      var r = new Result();
      
      if(result["type"]=="ok") 
      {
         r.type = result["type"];
         return r;
      }  
      else if(result["type"]=="error")
      {
        r.type = result["type"];
        r.error = result["error"];
        return r;      
      }
      else if(result["type"]=="data")
      {
        r.type    = result["type"];
        r.rows    = result["rows"];
        r.columns = result["columns"]; 
        _fixTypes(r);
        return r;      
      }
      else throw "unknown response";
   }   
   
   /// fix string data type coming from JSON into proper Dart data type
   void _fixTypes(Result r)
   {
      void _fixDateTime(String columnName)
      {
         for(int t=0;t<r.rows.length;t++) r.rows[t][columnName] = DateTime.parse(r.rows[t][columnName]);         
      }
      
      for(var fname in r.columns.keys)
      {
         if(r.columns[fname]=="datetime") _fixDateTime(fname);
      }
   }  
}

/// implements the type of results returning from SqlServerSocket.exe
/// a result can be either "ok", "error" or "data".
class Result
{
   String type;
   String error;
   List   rows;
   Map    columns;
   
   bool get isOk    => type=="ok";
   bool get isError => type=="error";
   bool get isData  => type=="data";
}

