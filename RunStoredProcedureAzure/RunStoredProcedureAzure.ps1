[CmdletBinding(DefaultParameterSetName = 'None')]
Param
(
	[String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,
	[String] $ConnectedServiceName,
	[String] $ConnectedServiceNameARM,
	[String] [Parameter(Mandatory = $true)] $serverName,
	[String] [Parameter(Mandatory = $true)] $databaseName,
	[String] [Parameter(Mandatory = $true)] $sprocName,
	[String] [Parameter(Mandatory = $true)] $sprocParameters,
	[String] [Parameter(Mandatory = $true)] $userName,
	[String] [Parameter(Mandatory = $true)] $userPassword,
	[int] [Parameter(Mandatory = $true)] $queryTimeout
)

Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Try
{
	Write-Host "Running Stored Procedure"

	#Create Firewall rule
	$ipAddress = (Invoke-WebRequest 'http://myexternalip.com/raw' -UseBasicParsing).Content -replace "`n"
	if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
	{
	    #Get resource group name
	    $resources = Find-AzureRmResource -ResourceNameContains $serverName
	    [string]$resourcegroupname = $resources.ResourceGroupName[0]

	    New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $serverName -FirewallRuleName 'TFSAgent' -StartIpAddress $ipAddress -EndIpAddress $ipAddress -ErrorAction SilentlyContinue
	}
	else
	{
	    New-AzureSqlDatabaseServerFirewallRule  -ServerName $serverName -RuleName 'TFSAgent' -StartIpAddress $ipAddress -EndIpAddress $ipAddress -ErrorAction SilentlyContinue
	}

	#Construct to the SQL to run
	[string]$sqlQuery = "EXEC " + $sprocName + " " + $sprocParameters
		
	#Execute the query
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$userName;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
	$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message -ForegroundColor DarkBlue} 
    $SqlConnection.add_InfoMessage($handler) 
	$SqlConnection.FireInfoMessageEventOnUserErrors=$true
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlQuery
	$SqlCmd.Connection = $SqlConnection
	$SqlCmd.CommandTimeout = $queryTimeout
	$reader = $SqlCmd.ExecuteNonQuery()
	#Invoke-Sqlcmd -ServerInstance "$serverName.database.windows.net" -Database $databaseName -Query $sqlQuery -Username $userName -Password $userPassword

	#Remove Firewall rule
	if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
	{
	    Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $servername -FirewallRuleName 'TFSAgent' -Force -ErrorAction SilentlyContinue
	}
	else
	{
	    Remove-AzureSqlDatabaseServerFirewallRule -ServerName $servername -RuleName 'TFSAgent' -Force -ErrorAction SilentlyContinue
	}

	Write-Host "Finished"
}

Catch
{
	Write-Host "Error running SQL script: $_" -ForegroundColor Red
	throw $_
}

