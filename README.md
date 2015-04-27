# SqlServerSocket

Connects to **Microsoft SQL Server** from the [Dart](dartlang.org) language.

Connection to SQL Server is achieved by the use of a specific service (`SqlServerSocket.exe` -- included here) that runs in the background and has to be started before the Dart program.

With this library you can run SQL queries on the server and have them returned as native Dart objects (Lists, Maps) with the correct data types.

There is also a dedicated class `Table` that simplifies CRUD operations on datasets without the need to writw SQL queries for insert, update or delete. 

## How to install it

1. Install and execute `SqlServerSocket.exe` in the background on the server machine where SQL Server is installed. The program will listen for connection coming from Dart on the local port `10980`.

2. On the Dart side (server), install and reference the package `sql_server_socket`.

## Basic usage

Some Dart examples (using `async` and `await`): 

```Dart
// creates a connection 
var conn = new SqlConnection("SERVER=localhost;Database=mydb;Trusted_connection=yes");

// open connection
await conn.open();

// runs a query returning a single value
var howmany = await conn.queryValue("SELECT COUNT(*) FROM Customers");

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

## SQL string formatting

When writing SQL queries, strings, booleans and datetimes needs to be formatted according to the SQL Server syntax. You can use these helper functions in your string interpolations:

* sqlBool()
* sqlString()
* sqlDate()

Example:

```Dart
var custName = "J'EROME";
var accept = true;
var v = await conn.queryValue("""
                 SELECT COUNT(*) 
                 FROM Customers 
                 WHERE Name = ${sqlString(custName)} 
                       AND TimeStamp > ${sqlDate(new DateTime.now())}
                       AND AcceptFlag = ${sqlBool(accept)}
                """);
```

## Using the Table object

Complex datasets operations can be done by the use of the `Table` object. It handles row inserts, deletes and updates, sending to the database only the changed data and retrieving identity values after inserts.

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

// "Id" field, previously 0, has now the identity number assigned by the database
print("newly inserted customer has Id ${row['Id']}");

// update customers
cust.rows[0]["Age"] = 42;
await cust.post();

// delete customers
cust.rows.removeAt(0);
await cust.post();

await conn.close();
```

