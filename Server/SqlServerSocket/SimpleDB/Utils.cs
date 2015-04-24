using System;
using System.Collections.Generic;
using System.Text;

namespace SimpleDB
{
   public class StringUtils
   {
      public static string CommaList(List<string> arr)
      {
         return CommaList(arr.ToArray());
      }

      public static string CommaList(params string[] arr)
      {
         StringBuilder sb = new StringBuilder();
         for(int t=0;t<arr.Length;t++)
         {
            sb.Append(arr[t]);
            if(t!=arr.Length-1) sb.Append(",");
         } 
         return sb.ToString();
      }

      public static string AndList(List<string> arr)
      {
         return AndList(arr.ToArray());
      }

      public static string AndList(params string[] arr)
      {
         StringBuilder sb = new StringBuilder();
         for(int t=0;t<arr.Length;t++)
         {
            sb.Append(arr[t]);
            if(t!=arr.Length-1) sb.Append(" AND ");
         } 
         return sb.ToString();
      }
   }
}

