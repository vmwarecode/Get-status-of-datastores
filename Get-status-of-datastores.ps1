# Track Datastore Space script                    #
#												  #
###################################################

# Variables #
#############

$VIServer = Read-Host "Enter IP or Hostname for your VI Server"
$digits = 2
$Folder = 'C:\Scripts'
$currentFile = 'Datastores_Current.xml'
$previousFile = 'Datastores_Previous.xml'
$differenceFile = 'Datastores_Difference.txt'

# Script #
##########

# First, if a Current file exists, rename this Current file to Previous

If (Test-Path "$Folder\$currentFile")
{
	Remove-Item -Path "$Folder\$currentFile" -Force
	Remove-Item -Path "$Folder\$previousFile" -Force
	Rename-Item -Path "$Folder\$currentFile" -NewName $previousFile
}

# Next, let's measure and save current datastore sizes

# Connect to Virtual Center
$VC = Connect-VIServer $VIServer

# Get all datastores and put them in alphabetical order
$datastores = Get-Datastore | Sort-Object Name

# Create an array to hold the output
$myColCurrent = @()

# Loop through datastores
ForEach ($store in $datastores)
{
	# Create a custom object and define its properties
	$myObj = "" | Select-Object Name, CapacityGB, UsedGB, PercFree
	# Set the values of each property
	$myObj.Name = $store.name
	$myObj.CapacityGB = [math]::Round($store.capacityMB/1024,$digits)
	$myObj.UsedGB = [math]::Round(($store.CapacityMB - $store.FreeSpaceMB)/1024,$digits)
	$myObj.PercFree = [math]::Round(100*$store.FreeSpaceMB/$store.CapacityMB,$digits)
	# Add the object to the output array
	$myColCurrent += $myObj
}

# Export the output to an xml file; the new Current file
$myColCurrent | Export-Clixml -Path "$Folder\$currentFile"

# Disconnect from Virtual Center
Disconnect-VIServer -Confirm:$False

# Finally, let's compare the Current information to that in the Previous file

# Check if a Previous file exists
If (Test-Path "$Folder\$previousFile")
{
	# Import the Previous file
	$myColPrevious = Import-Clixml "$Folder\$previousFile"
	# Create an array to hold the differences
	$myColDiff = @()
	# Loop through the current datastores
	ForEach ($myObjCurrent in $myColCurrent)
	{
		# The actual compare command
		$diff = Compare-Object ($myColPrevious | Where { $_.Name -eq $myObjCurrent.Name }) $myObjCurrent -Property PercFree
		# In case of any differences, try to get specifics
		If ($diff)
		{
			# Again, a custom object and properties for outputting results
			$myObjDiff = "" | Select-Object Name, PercentFree, Diff
			# Again, setting the values of each property
			$myObjDiff.Name = $myObjCurrent.Name
			$myObjDiff.PercentFree = $myObjCurrent.PercFree
			# The most important property is the calculated difference between the current and previous values of PercFree. You can substitute it for UsedGB if you like.
			$myObjDiff.Diff = ($diff | Where { $_.SideIndicator -eq '=>' }).PercFree - ($diff | Where { $_.SideIndicator -eq '<=' }).PercFree
			# And agin, adding it to the output array
			$myColDiff += $myObjDiff
		}
		# Clearing the variable used inside the loop to prevent incorrect output in case of problems setting the variable!
		Clear-Variable diff -ErrorAction "SilentlyContinue"
	}
	# If nothing changed, we don't want an empty file.
	If ($myColDiff.Length -eq 0)
	{
		$myColDiff = "No changes since last check."
	}
	# And we conclude by outputting the results to a text file, which can be emailed or printed.
	$myColDiff | Format-Table -AutoSize | Out-File "$Folder\$differenceFile" -Force
}