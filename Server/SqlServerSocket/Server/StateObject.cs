using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using SimpleDB;

// State object for reading client data asynchronously
public class StateObject 
{    
    public Socket workSocket = null;               // Client  socket.    
    public const int BufferSize = 1024;            // Size of receive buffer.    
    public byte[] buffer = new byte[BufferSize];   // Receive buffer.    
    public StringBuilder sb = new StringBuilder(); // Received data string.    
    public Database database = new Database();     // database connection
    public bool disconnect = false;                
}
