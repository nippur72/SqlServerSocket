using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

class Program
{   
   public static bool exitFlag = false;

   static void Main(string[] args)
   {
      Console.CancelKeyPress += Console_CancelKeyPress;  // ^C key closes server
      
      var server = new Server(10980);      
      server.StartListening();            
   }

   static void Console_CancelKeyPress(object sender, ConsoleCancelEventArgs e)
   {
      exitFlag = true;
   }
}

