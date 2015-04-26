
/// formats a [DateTime] to SQL Server format 
String sqlDate(DateTime date)
{
   return "CONVERT(DATETIME,'${date.toString()}',102)";
}

/// formats a [String] to SQL Server format
String sqlString(String s)
{
   return "'"+s.replaceAll(new RegExp("'"),"''")+"'";
}

/// formats a [bool] to SQL Server format
String sqlBool(bool b)
{
   return b ? "1" : "0";
}

