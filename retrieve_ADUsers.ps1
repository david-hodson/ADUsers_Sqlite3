<#
.SYNOPSIS
    retrieve_ADUsers.ps1 - Script to retrieve Active Directory user information and store it in a SQLite database.

.DESCRIPTION
    This script connects to Active Directory, retrieves user information based on the last logon date,
    and saves the data to a SQLite database file. It also checks if the required table and columns exist in the database
    and adds them if necessary.

    The script uses the SQLite module to interact with the database and the ActiveDirectory module to query Active Directory.

.NOTES
    - Prerequisites: PowerShell, ActiveDirectory module, and SQLite module.
    - The script does not assume the database file already exists and will create the database and tables if they do not already exist.
    - The script assumes you have all of the prerequisite PowerShell Modules installed.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    PS C:\> .\retrieve_ADUsers.ps1
    Executes the script and retrieves AD user information, storing it in the specified SQLite database.

#>

# Import the SQLite module
Import-Module -Name SQLite

# Set the days to mark a user as stale
$staleDays = <Number of days>

# Set the stale date to $staleDays
$staleDate = (Get-Date).AddDays($staleDays).ToString('yyyy-MM-dd')

# Define the properties to retrieve for each AD user
$properties = "Foo", "bar"

# Retrieve AD users based on the last logon date filter
$adUsers = Get-ADUser -Filter {LastLogonDate -gt $staleDate} -Properties $properties | Select-Object -Property $properties

# Specify the path to the SQLite database file
$dbPath = "<SQLite3 Database filepath>"
$connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath")
$connection.Open()

# Check if the ADUsers table exists in the SQLite database
$tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='ADUsers'"
$tableExistsCommand = $connection.CreateCommand()
$tableExistsCommand.CommandText = $tableExistsQuery
$tableExists = $tableExistsCommand.ExecuteScalar()

# If the ADUsers table does not exist, create it with the necessary columns
if ($null -eq $tableExists) {
    $createTableQuery = @"
    CREATE TABLE ADUsers (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Title TEXT,
        DisplayName TEXT,
        EmployeeID TEXT,
        Enabled INTEGER,
        LockedOut INTEGER,
        Manager TEXT,
        SamAccountName TEXT UNIQUE,
        PasswordExpired INTEGER,
        PasswordLastSet TEXT,
        LastLogonDate TEXT,
        UserPrincipalName TEXT,
        info TEXT,
        Company TEXT,
        MobilePhone TEXT,
        description TEXT,
        stale_user INTEGER
    );
"@
    $createTableCommand = $connection.CreateCommand()
    $createTableCommand.CommandText = $createTableQuery
    $createTableCommand.ExecuteNonQuery()
}

# Check if each property column exists in the ADUsers table and add them if necessary
$existingColumnsQuery = "PRAGMA table_info(ADUsers)"
$existingColumnsCommand = $connection.CreateCommand()
$existingColumnsCommand.CommandText = $existingColumnsQuery
$existingColumns = $existingColumnsCommand.ExecuteReader()

$existingColumnNames = @()

while ($existingColumns.Read()) {
    $columnName = $existingColumns.GetString(1)
    $existingColumnNames += $columnName
}

$existingColumns.Close()

$addColumnCommand = $connection.CreateCommand()

foreach ($property in $adUsers[0].PSObject.Properties.Name) {
    if (-not ($existingColumnNames -contains $property)) {
        $addColumnQuery = "ALTER TABLE ADUsers ADD COLUMN $property TEXT"
        $addColumnCommand.CommandText = $addColumnQuery
        $addColumnCommand.ExecuteNonQuery()
    }
}

# Add the 'stale_user' column if it does not exist
$staleUserColumnName = 'stale_user'
if (-not ($existingColumnNames -contains $staleUserColumnName)) {
    $addColumnQuery = "ALTER TABLE ADUsers ADD COLUMN $staleUserColumnName INTEGER"
    $addColumnCommand.CommandText = $addColumnQuery
    $addColumnCommand.ExecuteNonQuery()
}

# Update the 'stale_user' column based on the last logon date
$updateStaleUserQuery = @"
UPDATE ADUsers
SET stale_user = CASE WHEN LastLogonDate >= '$staleDate' THEN 0 ELSE 1 END
"@
$updateStaleUserCommand = $connection.CreateCommand()
$updateStaleUserCommand.CommandText = $updateStaleUserQuery
$updateStaleUserCommand.ExecuteNonQuery()

# Insert or replace user information into the SQLite database
$insertQuery = @"
INSERT OR REPLACE INTO ADUsers (
    Title, DisplayName, EmployeeID, Enabled, LockedOut, Manager, SamAccountName, PasswordExpired,
    PasswordLastSet, LastLogonDate, UserPrincipalName, info, Company, MobilePhone, description, stale_user
) VALUES (
    @Title, @DisplayName, @EmployeeID, @Enabled, @LockedOut, @Manager, @SamAccountName, @PasswordExpired,
    @PasswordLastSet, @LastLogonDate, @UserPrincipalName, @info, @Company, @MobilePhone, @description, @stale_user
)
"@
$insertCommand = $connection.CreateCommand()
$insertCommand.CommandText = $insertQuery

foreach ($user in $adUsers) {
    # Set the parameter values for the insert command
    $insertCommand.Parameters.AddWithValue("@Title", $user.Title)
    $insertCommand.Parameters.AddWithValue("@DisplayName", $user.DisplayName)
    $insertCommand.Parameters.AddWithValue("@EmployeeID", $user.EmployeeID)
    $insertCommand.Parameters.AddWithValue("@Enabled", $user.Enabled)
    $insertCommand.Parameters.AddWithValue("@LockedOut", $user.LockedOut)
    $insertCommand.Parameters.AddWithValue("@Manager", $user.Manager)
    $insertCommand.Parameters.AddWithValue("@SamAccountName", $user.SamAccountName)
    $insertCommand.Parameters.AddWithValue("@PasswordExpired", $user.PasswordExpired)
    $insertCommand.Parameters.AddWithValue("@PasswordLastSet", (Get-Date $user.PasswordLastSet).ToString("MM/dd/yyyy"))
    $insertCommand.Parameters.AddWithValue("@LastLogonDate", (Get-Date $user.LastLogonDate).ToString("MM/dd/yyyy"))
    $insertCommand.Parameters.AddWithValue("@UserPrincipalName", $user.UserPrincipalName)
    $insertCommand.Parameters.AddWithValue("@info", $user.info)
    $insertCommand.Parameters.AddWithValue("@Company", $user.Company)
    $insertCommand.Parameters.AddWithValue("@MobilePhone", $user.MobilePhone)
    $insertCommand.Parameters.AddWithValue("@description", $user.description)
    
    # Determine the 'stale_user' value based on the last logon date
    $staleUser = $user.LastLogonDate -lt $staleDate
    $insertCommand.Parameters.AddWithValue("@stale_user", [int]$staleUser)

    # Execute the insert command
    $insertCommand.ExecuteNonQuery()
}

# Close the database connection
$connection.Close()
