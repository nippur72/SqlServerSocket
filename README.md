# SqlServerSocket

This package is a library for the Dart language that allows to interact with **Microsoft SQL Server**  by the use of a socket-based service (`SqlServerSocket.exe`) that runs in the background. 

The service acts like a bridge between SQL Server and Dart. It's written in C# and uses native .NET drivers to interact with SQL Server. 

## How to install it

1. Install and execute `SqlServerSocket.exe` in the background on the server machine where SQL Server is installed. The program will listen for connection coming from Dart on the local port `10980`.

2. On the Dart side (server), install and reference the package `SqlServerSocket`.

## Usage

Some dart examples (using `async` and `await`): 

```Dart
// creates a connection 
var conn = new SqlConnection("SERVER=localhost;Database=mydb;Trusted_connection=yes");

// open connection
await conn.open();

// runs a query returning a single value
var dbname = await conn.queryValue("SELECT COUNT(*) FROM Customers");

// runs a query returning a single row
var myFirstCustomer = await conn.querySingle("SELECT name,age FROM Custormers");
print(myFirstCustomer["name"]);

// runs a query returning all rows
var customers = await conn.query("SELECT TOP 10 name,age FROM Custormers");
for(var customer in customers)
{
   print(customer["name"]);
}

// execute a command, returning the number of rows affected
var n = await conn.execute("UPDATE Customers SET age=0");
print("zeroed $n customers");

// disconnect
await conn.close();
```

## Managing Table objects

Complex datasets operations can be done by the use of the `Table` object that handles inserts, deletes and updates, sending to the database only the changed data and retrieving identity values after inserts.

Example:

```Dart
var conn = new SqlConnection("SERVER=localhost;Database=mydb;Trusted_connection=yes");

await conn.open();

// populates a table
Table cust = await conn.queryTable("SELECT Id, Name, Age FROM Customers");

// add a new customer to table
var row = cust.newRow();
row["Name"] = "Steve";
row["Age"] = 33;
cust.rows.add(row);

// save changes to databases
await cust.post();

// Id field, previously 0, has now the idenity number assigned by the DB
print("last inserted customer = ${row['Id']}");

// update customers
cust.rows[0]["Age"] = 42;
await cust.post();

// delete customers
cust.rows.removeAt(0);
await cust.post();

await conn.close();
```

