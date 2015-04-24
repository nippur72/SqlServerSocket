// Copyright (c) 2015, Antonino Porcino. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

//import 'package:SockedSql/SockedSql.dart' as SockedSql;

import "dart:io";
import "dart:async";
import "dart:convert";

main() async
{
   Database db = new Database();
   
   await db.connect("portento.dsn");
      
   print("connected");
   
   List rows = await db.query("SELECT TOP 3 * FROM Comuni_Anagrafe");
      
   print("queried");
   
   for(var r in rows)
   {
      print(r["Cognome"]);
   }
   
   var s = await db.queryValue("SELECT db_name()");
   
   print("dbname=$s");
   
   await db.disconnect();
   
   print("done");
}

class Database
{
   Socket _socket;
   StringBuffer _receiveBuffer;
   Completer _completer;
   bool _connected;
   
   final port = 10980;
   
   Database()
   {
   }
   
   bool get connected => _connected;  
   
   Future<bool> connect(String conn) async
   {
      try
      {
         this._socket = await Socket.connect("localhost", port);           
         print('Connected to: ${_socket.remoteAddress.address}:${_socket.remotePort}');
      }
      catch(ex)
      {
         throw "can't connect";         
      }
       
      //Establish the onData, and onDone callbacks
      _socket.listen(_receiveData, onError: onError, onDone: onDone);
      
      var connectCompleter = new Completer();
      
      _SendCommand("CONNECT").then((result) {
         var res = parseResult(result);
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
   
   Future<bool> disconnect()
   {
      Completer disconnectCompleter = new Completer();
      
      _SendCommand("DISCONNECT").then((risp)
      {
         var res = parseResult(risp);
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
   
   Future<List<Map<String,dynamic>>> query(String SQL)
   {      
      String json = JSON.encode({ "type": "query", "sql": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = parseResult(result);
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
   
   Future<Map<String,dynamic>> querySingle(String SQL)
   {      
      String json = JSON.encode({ "type": "querysingle", "sql": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = parseResult(result);
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

   Future<dynamic> queryValue(String SQL)
   {      
      String json = JSON.encode({ "type": "queryvalue", "sql": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = parseResult(result);
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

   Future<int> execute(String SQL)
   {      
      String json = JSON.encode({ "type": "execute", "sql": SQL });
      
      Completer compl = new Completer(); 
      _SendCommand(json).then((result)
      {
          var res = parseResult(result);
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

   Future<String> _SendCommand(String command)
   {
      //print("sending $command");
      _receiveBuffer = new StringBuffer();
      _completer = new Completer();
      String cmd = command.length.toString() + "\r\n" + command;
      _socket.write(cmd);
      return _completer.future;
   }

   void onDone()
   {
       print("onDone()");
       //socket.destroy();
   }
   
   void onError(error)
   {
       print("error occurred: $error");
   }
   
   void _receiveData(data)
   {
      _receiveBuffer.write(new String.fromCharCodes(data));
      
      String content = _receiveBuffer.toString();
      //print("--${content}--");
      if(content.indexOf("\r\n")>0)
      {
         int x = content.indexOf("\r\n");
         int len = int.parse(content.substring(0,x));
         
         String cmd = content.substring(x+2);
         if(cmd.length==len)
         {
           //print("received complete response ${cmd}");
           _completer.complete(cmd);           
         }              
      }
   }
   
   Result parseResult(String json)
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
        r.type = result["type"];
        r.rows = result["rows"];
        return r;      
      }
      else throw "unknown response";
   }   
}

class Result
{
   String type;
   String error;
   List   rows;
   
   bool get isOk    => type=="ok";
   bool get isError => type=="error";
   bool get isData  => type=="data";
}



