# SqlServerSocket

This package is a library for the Dart language that allows to interact with **Microsoft SQL Server**  by the use of a socket-based service (`SqlServerSocket.exe`) that runs in the background. 

The service acts like a bridge between SQL Server and Dart. It's written in C# and uses native .NET drivers to interact with SQL Server. 

## How to install it

1) Install and execute `SqlServerSocket.exe` in the background on the server machine where SQL Server is installed. The program will listen for connection coming from Dart on the local port `10980`.
2) On the Dart side (server), install and reference the package `SqlServerSocket`.

## Usage

Some dart examples (using `async` and `await`): 

```
// create a database object 
var conn = new SqlConnection("SERVER=localhost;Database=mydb;Trusted_connection=yes");

// establish connection
await conn.open();

// runs a query returning a single value
var dbname = await db.queryValue("SELECT COUNT(*) FROM Customers");

// runs a query returning a single row
var myFirstCustomer = await db.querySingle("SELECT name,age FROM Custormers");
print(myFirstCustomer["name"]);

// runs a query returning all rows
var customers = await db.query("SELECT TOP 10 name,age FROM Custormers");
for(var customer in customers)
{
   print(customer["name"]);
}

// execute a command, returning the number of rows affected
var n = await db.execute("UPDATE Customers SET age=0");
print("zeroed $n customers");

// disconnect
await conn.close();
```
