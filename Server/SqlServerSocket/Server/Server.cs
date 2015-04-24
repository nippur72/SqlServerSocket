using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Newtonsoft.Json;
using SimpleDB;

public class Server 
{
    // Thread signal.
    public static ManualResetEvent allDone = new ManualResetEvent(false);
    private int port;

    public Server(int port) 
    {
      this.port = port;
    }

    public void StartListening() 
    {
        // Data buffer for incoming data.
        byte[] bytes = new Byte[1024];
        
        IPHostEntry ipHostInfo = Dns.Resolve("localhost");
        IPAddress ipAddress = ipHostInfo.AddressList[0];
        IPEndPoint localEndPoint = new IPEndPoint(ipAddress, port);

        Console.WriteLine(string.Format("SocketSQL is listening localhost:{0} ... press ^C to exit",port));

        // Create a TCP/IP socket.
        Socket listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp );

        // Bind the socket to the local endpoint and listen for incoming connections.
        try 
        {
            listener.Bind(localEndPoint);
            listener.Listen(100);

            while(true) 
            {
                // Set the event to nonsignaled state.
                allDone.Reset();                

                listener.BeginAccept( new AsyncCallback(AcceptCallback), listener );

                // Wait until a connection is made before continuing.
                allDone.WaitOne(1000);

                if(Program.exitFlag) return;
            }
        } 
        catch(Exception e) 
        {
            Console.WriteLine(e.ToString());
        }
    }

    public void AcceptCallback(IAsyncResult ar) 
    {
        Console.WriteLine("new connection established");

        // Signal the main thread to continue.
        allDone.Set();

        // Get the socket that handles the client request.
        Socket listener = (Socket) ar.AsyncState;
        Socket handler = listener.EndAccept(ar);

        // Create the state object.
        StateObject state = new StateObject();
        state.workSocket = handler;
        handler.BeginReceive( state.buffer, 0, StateObject.BufferSize, 0, new AsyncCallback(ReadCallback), state);
    }

    public void ReadCallback(IAsyncResult ar) 
    {        
        String content = String.Empty;
        
        // Retrieve the state object and the handler socket
        // from the asynchronous state object.
        StateObject state = (StateObject) ar.AsyncState;
        Socket handler = state.workSocket;

        // Read data from the client socket. 
        int bytesRead = 0;
        
        try
        {
           bytesRead = handler.EndReceive(ar);
        }
        catch(SocketException ex)
        {
           Console.WriteLine("forced disconnect");
           handler.Shutdown(SocketShutdown.Both);
           handler.Close();
           return;
        }

        if(bytesRead > 0) 
        {
            // There  might be more data, so store the data received so far.
            //state.sb.Append(Encoding.ASCII.GetString(state.buffer,0,bytesRead));
            state.sb.Append(Encoding.UTF8.GetString(state.buffer,0,bytesRead));

            // Check for end-of-file tag. If it is not there, read more data.
            content = state.sb.ToString();
            if(content.IndexOf("\r\n") > -1) 
            {
                int x = content.IndexOf("\r\n");
                int len = int.Parse(content.Substring(0,x));
                //Console.WriteLine("size = "+len.ToString());
                string cmd = content.Substring(x+2);
                if(cmd.Length==len)
                {
                   // All the data has been read from the client                
                   //Console.WriteLine("Read {0} bytes from socket. \n Data : {1}", cmd.Length, cmd );

                   string result = ParseCommand(cmd, state);
                   state.sb = new StringBuilder();

                   // Echo the data back to the client.
                   Send(handler, result);

                   // check if client asked disconnection
                   if(state.disconnect)
                   {
                     handler.Shutdown(SocketShutdown.Both);
                     handler.Close();
                     return;
                   }
                }
            } 
        }

        // Not all data received. Get more.
        handler.BeginReceive(state.buffer, 0, StateObject.BufferSize, 0, new AsyncCallback(ReadCallback), state);
    }
    
    private void Send(Socket handler, String data) 
    {
        string dataToSend = data.Length.ToString()+"\r\n"+data;

        // Convert the string data to byte data using ASCII encoding.
        byte[] byteData = Encoding.UTF8.GetBytes(dataToSend);

        // Begin sending the data to the remote device.
        handler.BeginSend(byteData, 0, byteData.Length, 0, new AsyncCallback(SendCallback), handler);
    }

    private void SendCallback(IAsyncResult ar) 
    {
        try 
        {
            // Retrieve the socket from the state object.
            Socket handler = (Socket) ar.AsyncState;

            // Complete sending the data to the remote device.
            int bytesSent = handler.EndSend(ar);
            //Console.WriteLine("Sent {0} bytes to client.", bytesSent);            
        } 
        catch(Exception e) 
        {
            Console.WriteLine(e.ToString());
        }
    }

    public string ParseCommand(string command, StateObject st)
    {
        object ob = ParseCommandInner(command, st);

        return JsonConvert.SerializeObject(ob);
    }

    public object ParseCommandInner(string command, StateObject st)
    {        
        Command cmd;
        
        try
        {
          cmd = JsonConvert.DeserializeObject<Command>(command);
        }
        catch(Exception ex)
        {
          return new ErrorResult("invalid command");
        }

        if(cmd.type=="open")
        {
            if(st.database!=null) return new ErrorResult("already connected");

            try
            {               
               st.database = new SimpleDB.Database(cmd.text);
               st.database.Open();
               return new OkResult();
            }
            catch(Exception ex)
            {
               return new ErrorResult(ex.Message);
            }
        }
        else if(cmd.type=="close")
        {
            if(st.database==null) return new ErrorResult("not connected");

            st.database.Close();
            st.database = null;
            st.disconnect = true;
            return new OkResult();
        }
        else if(cmd.type=="query")
         {
            if(st.database==null) return new ErrorResult("not connected");

            try
            {
               var rows = st.database.Query(cmd.text);                                                                                       
               return new DataResult(rows);
            }
            catch(Exception ex)
            {
               return new ErrorResult(ex.Message);
            }
         }
         else if(cmd.type=="querysingle")
         {
            if(st.database==null) return new ErrorResult("not connected");

            try
            {
               var row = st.database.QuerySingle(cmd.text);                                                   
               List<Row> result = new List<Row>();
               result.Add(row);               
               return new DataResult(result);
            }
            catch(Exception ex)
            {
               return new ErrorResult(ex.Message);
            }
         }
         else if(cmd.type=="queryvalue")
         {
            if(st.database==null) return new ErrorResult("not connected");

            try
            {
               var value = st.database.QueryValue(cmd.text);               
               Row r = new Row();
               r.Add("value",value);
               List<Row> result = new List<Row>();
               result.Add(r);               
               return new DataResult(result);
            }
            catch(Exception ex)
            {
               return new ErrorResult(ex.Message);
            }
         }
         else if(cmd.type=="execute")
         {               
            if(st.database==null) return new ErrorResult("not connected");

            try
            {
               int rowsAffected = st.database.Execute(cmd.text);               
               Row r = new Row();
               r.Add("rowsAffected",rowsAffected);
               List<Row> result = new List<Row>();
               result.Add(r);               
               return new DataResult(result);
            }
            catch(Exception ex)
            {
               return new ErrorResult(ex.Message);
            }
         }
         else return new ErrorResult("unknown command");                            
    }
}

public class OkResult
{
   public string type;   

   public OkResult()
   {
      type = "ok";      
   }
}

public class ErrorResult
{
   public string type;
   public string error;

   public ErrorResult(string message)
   {
      type = "error";
      error = message;
   }
}

public class DataResult
{
   public string type;
   public List<Row> rows;

   public DataResult(List<Row> data)
   {
      type = "data";
      rows = data;
   }
}

public class Command
{
   public string type;
   public string text;
}

