using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SimpleDB
{
   public class PostBackException : Exception
   {
      public PostBackException(string msg) : base(msg)
      {
      }
   }
}
