# retrieve_ADUsers.ps1 README

## SYNOPSIS
retrieve_ADUsers.ps1 - Script to retrieve Active Directory user information and store it in a SQLite database.

## DESCRIPTION
This script connects to Active Directory, retrieves user information based on the last logon date, and saves the data to a SQLite database file. It also checks if the required table and columns exist in the database and adds them if necessary.

## NOTES
- Prerequisites: PowerShell, ActiveDirectory module, and SQLite module.
- The script does not assume the database file already exists and will create the database and tables if they do not already exist.
- The script assumes you have all of the prerequisite PowerShell Modules installed.

## PARAMETER
None: This script does not accept any parameters.

## EXAMPLE
```
PS C:> .\retrieve_ADUsers.ps1
```
Executes the script and retrieves AD user information, storing it in the specified SQLite database.

## DETAILS
The script performs the following steps:

1. Import the SQLite module:
- The script starts by importing the SQLite module, which provides the necessary functionality to interact with the SQLite database.

2. Set the days to mark a user as stale:
- You can configure the number of days after which a user is considered stale by modifying the value assigned to the `$staleDays` variable.

3. Set the stale date:
- The `$staleDate` variable is calculated by subtracting the specified number of stale days from the current date.

4. Define the properties to retrieve for each AD user:
- The `$properties` variable stores an array of property names that you want to retrieve for each Active Directory user.
- Modify the array to include the desired properties you want to retrieve. For example: `"Title"`, `"DisplayName"`, `"EmployeeID"`, etc.

5. Retrieve AD users based on the last logon date filter:
- The script uses the `Get-ADUser` cmdlet from the ActiveDirectory module to retrieve AD users based on the last logon date.
- It filters the users using the `$staleDate` to only retrieve users whose last logon date is greater than the stale date.
- The retrieved users are stored in the `$adUsers` variable.

6. Specify the path to the SQLite database file:
- Set the `$dbPath` variable to the file path of your SQLite database.
- If the file does not exist, the script will create it.
- Ensure that you have appropriate write permissions for the specified path.

7. Check if the ADUsers table exists in the SQLite database:
- The script checks if the ADUsers table exists in the SQLite database by executing a SELECT statement on the `sqlite_master` table.
- If the table does not exist, it proceeds to create it.

8. Check if each property column exists in the ADUsers table and add them if necessary:
- The script queries the ADUsers table's schema to retrieve the existing column names.
- It then compares the existing columns with the desired property names and adds any missing columns to the table.

9. Add the 'stale_user' column if it does not exist:
- The script checks if the 'stale_user' column exists in the ADUsers table.
- If it doesn't exist, it adds the column to the table.

10. Update the 'stale_user' column based on the last logon date:
- The script executes an UPDATE statement to set the 'stale_user' column value based on the last logon date.
- If the user's last logon date is greater than or equal to the stale date, the
