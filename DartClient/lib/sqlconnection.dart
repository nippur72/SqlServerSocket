library sql_server_socket;

import "dart:io";
import "dart:async";
import "dart:convert";
import 'dart:typed_data';

import "table.dart";

class SqlConnection {
  late Socket _socket;
  late StringBuffer _receiveBuffer;
  late Completer _completer;
  late bool _connected;

  late String _address;
  late int _port;
  late String _connectionString;

  SqlConnection(String connStr,
      {String address: "localhost", int port: 10980}) {
    _address = address;
    _port = port;
    _connected = false;
    _connectionString = connStr;
  }

  /// tells if database is connected
  bool get connected => _connected;

  /// connects to sql server database using the specified connection string
  Future<bool> open() async {
    try {
      this._socket = await Socket.connect(_address, _port);
      //print("Connected to: ${_socket.remoteAddress.address}:${_socket.remotePort}");
    } catch (ex) {
      // throw "can't connect to ${_address}:${_port} -- $ex";
      throw "can't connect to $_address:$_port -- $ex";
    }

    //Establish the onData, and onDone callbacks
    _socket
        .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
        .listen(_receiveData, onError: _onError, onDone: _onDone);

    Completer<bool> connectCompleter = new Completer();

    // String json = JSON.encode({"type": "open", "text": _connectionString});
    String json = jsonEncode({"type": "open", "text": _connectionString});

    _sendCommand(json).then((result) {
      var res = _parseResult(result);
      if (res is _OkResult) {
        _connected = true;
        connectCompleter.complete(true);
      } else if (res is _ErrorResult) {
        _connected = false;
        connectCompleter.completeError(res.error);
      } else
        throw "unknown response";
    }).catchError((err) {
      _connected = false;
      connectCompleter.completeError(err);
    });

    return connectCompleter.future;
  }

  /// disconnects from sql server
  Future<bool> close() {
    if (!connected) throw "not connected";

    Completer<bool> disconnectCompleter = new Completer();

    String json = jsonEncode({"type": "close", "text": ""});

    _sendCommand(json).then((risp) {
      var res = _parseResult(risp);

      if (res is _OkResult) {
        _connected = false;
        disconnectCompleter.complete(true);
      } else if (res is _ErrorResult) {
        disconnectCompleter.completeError(res.error);
      } else
        throw "unknown response";
    }).catchError((err) {
      disconnectCompleter.completeError(err);
    });

    return Future.value(disconnectCompleter.future);
  }

  /// launch a query on the database, returning a table
  Future<Table> queryTable(String sql) {
    if (!connected) throw "not connected";

    String json = jsonEncode({"type": "table", "text": sql});

    Completer<Table> compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);

      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _TableResult) {
        var tres = res;
        Table tab = new Table(this, tres.tableName, tres.rows, tres.columns);
        compl.complete(tab);
      } else
        throw "unknown response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  Future<PostBackResponse> postBack(ChangeSet chg) {
    if (!connected) throw "not connected";

    String params = jsonEncode(chg.toEncodable());

    String json = jsonEncode({"type": "postback", "text": params});

    Completer<PostBackResponse> compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);

      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _PostBackResult) {
        var tres = res;
        PostBackResponse resp = new PostBackResponse();
        resp.idcolumn = tres.idcolumn;
        resp.identities = tres.identities;
        compl.complete(resp);
      } else
        throw "invalid postback response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  /// launch a query on the database, returning all rows
  Future<List<Map<String, dynamic>>> query(String sql) {
    if (!connected) throw "not connected";

    String json = jsonEncode({"type": "query", "text": sql});

    Completer<List<Map<String, dynamic>>> compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);
      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _QueryResult)
        compl.complete(res.rows);
      else
        throw "unknown response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  /// launch a query on the database, returning the first rows only
  Future<Map<String, dynamic>> querySingle(String sql) {
    if (!connected) throw "not connected";

    String json = jsonEncode({"type": "querysingle", "text": sql});

    Completer<Map<String, dynamic>> compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);

      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _QueryResult) {
        if (res.rows.length == 0)
          compl.complete(null);
        else
          compl.complete(res.rows[0]);
      } else
        throw "unknown response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  /// launch a query on the database, returning the value from the first column of the first row
  Future<dynamic> queryValue(String sql) {
    if (!connected) throw "not connected";

    String json = jsonEncode({"type": "queryvalue", "text": sql});

    Completer compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);

      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _QueryResult) {
        if (res.rows.length == 0)
          compl.complete(null);
        else
          compl.complete(res.rows[0]["value"]);
      } else
        throw "unknown response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  /// executes a sql command, returning the number of rows affected
  Future<int> execute(String sql) {
    if (!connected) throw "not connected";

    String json = jsonEncode({"type": "execute", "text": sql});

    Completer<int> compl = new Completer();
    _sendCommand(json).then((result) {
      var res = _parseResult(result);

      if (res is _ErrorResult)
        compl.completeError(res.error);
      else if (res is _QueryResult) {
        if (res.rows.length == 0)
          compl.complete(-1);
        else
          compl.complete(res.rows[0]["rowsAffected"]);
      } else
        throw "unknown response";
    }).catchError((err) {
      compl.completeError(err);
    });
    return compl.future;
  }

  /// formats and write a command to the socket
  Future<String> _sendCommand(String command) {
    // prepare buffer for response
    _receiveBuffer = new StringBuffer();

    Completer<String> _completer = new Completer();
    String cmd = command.length.toString() + "\r\n" + command;
    _socket.write(cmd);

    return _completer.future;
  }

  void _onDone() {
    //print("onDone()");
    //socket.destroy();
  }

  void _onError(error) {
    print("error occurred: $error");
  }

  /// receive data from socket and build a command string
  ///
  /// client sends text-based commands with the format:
  /// size_of_command_string + "\r\n" + command_string
  void _receiveData(data) {
    _receiveBuffer.write(data);

    String content = _receiveBuffer.toString();

    if (content.indexOf("\r\n") > 0) {
      int x = content.indexOf("\r\n");
      int len = int.parse(content.substring(0, x)); // size of command string

      String cmd = content.substring(x + 2);
      if (cmd.length == len) {
        _completer.complete(cmd);
      }
    }
  }

  /// translates generic json result into a Result type
  dynamic _parseResult(String json) {
    Map result = jsonDecode(json);

    if (result["type"] == "ok")
      return new _OkResult("ok");
    else if (result["type"] == "error")
      return new _ErrorResult(result["error"]);
    else if (result["type"] == "query")
      return new _QueryResult(result["rows"], result["columns"]);
    else if (result["type"] == "table")
      return new _TableResult(
          result["tablename"], result["rows"], result["columns"]);
    else if (result["type"] == "postback")
      return new _PostBackResult(result["idcolumn"], result["identities"]);
    else
      throw "unknown response";
  }
}

class _ErrorResult {
  late String error;

  _ErrorResult(String error) {
    this.error = error;
  }
}

class _OkResult {
  late String ok;

  _OkResult(String ok) {
    this.ok = ok;
  }
}

class _QueryResult {
  late List<Map<String, dynamic>> rows;
  late Map<String, dynamic> columns;

  _QueryResult(List<Map<String, dynamic>> rows, Map<String, dynamic> columns) {
    this.rows = rows;
    this.columns = columns;

    // fix types
    for (var fieldName in columns.keys) {
      TypeFixer.fixColumn(rows, fieldName, columns[fieldName]);
    }
  }
}

class _TableResult {
  late String tableName;
  late List<Map<String, dynamic>> rows;
  late List<Map<String, String>> columns;

  _TableResult(String tableName, List<Map<String, dynamic>> rows,
      List<Map<String, String>> columns) {
    this.tableName = tableName;
    this.rows = rows;
    this.columns = columns;
  }
}

class _PostBackResult {
  late String idcolumn;
  late List<int> identities;

  _PostBackResult(String idcolumn, List<int> identities) {
    this.idcolumn = idcolumn;
    this.identities = identities;
  }
}

/// translates a JSON encoded SQL type into a Dart type
class TypeFixer {
  /// fix string data type coming from JSON into proper Dart data type
  static void fixColumn(
      List<Map<String, dynamic>> rows, String columnName, String columnType) {
    if (columnType == "datetime") {
      for (int t = 0; t < rows.length; t++) {
        if (rows[t][columnName] != null)
          rows[t][columnName] = DateTime.parse(rows[t][columnName]);
      }
    }
  }
}
