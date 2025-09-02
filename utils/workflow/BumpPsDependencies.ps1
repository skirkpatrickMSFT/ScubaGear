[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'moduleVersion')]
# Purpose: Called by ps_dependencies_requiredversionsfile.yaml to update the MaximumVersion sections in the RequiredVersions.ps1 file.
# This script respects the IsPinned property to exclude modules from version updates.

# Enable Information stream to display Write-Information output
$InformationPreference = 'Continue'

# Read and execute the RequiredVersions.ps1 file to get the module list
$scriptPath = './PowerShell/ScubaGear/RequiredVersions.ps1'
$originalContent = Get-Content -Path $scriptPath -Raw

# Execute the script to get the ModuleList variable
. $scriptPath

$updated = $false
$newModuleList = @()

# Process each module in the list
foreach ($module in $ModuleList) {
    $moduleName = $module.ModuleName
    $currentMaxVersion = $module.MaximumVersion
    $isPinned = $module.IsPinned -eq "True"
    
    # Create a copy of the module hashtable
    $newModule = $module.Clone()
    
    if ($isPinned) {
        Write-Information "Skipping version update for pinned module: $moduleName" -InformationAction Continue
        $newModuleList += $newModule
        continue
    }
    
    try {
        $latestVersion = Find-Module -Name $moduleName | Select-Object -ExpandProperty Version
        
        if ($null -ne $latestVersion -and $currentMaxVersion -ne $latestVersion) {
            $newModule.MaximumVersion = [version]$latestVersion
            Write-Information "Updated $moduleName from version $currentMaxVersion to $latestVersion" -InformationAction Continue
            $updated = $true
        }
        else {
            Write-Information "No update needed for $moduleName (current: $currentMaxVersion)" -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Failed to find latest version for module: $moduleName. Error: $($_.Exception.Message)"
    }
    
    $newModuleList += $newModule
}

if ($updated) {
    # Rebuild the file content with updated module list
    $newContent = @"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ModuleList')]
`$ModuleList = @(
"@
    
    for ($i = 0; $i -lt $newModuleList.Count; $i++) {
        $module = $newModuleList[$i]
        $newContent += "`n    @{`n"
        $newContent += "        ModuleName = '$($module.ModuleName)'"
        
        # Add comment if it exists in original
        if ($module.ModuleName -eq 'ExchangeOnlineManagement') {
            $newContent += " # includes Defender"
        }
        elseif ($module.ModuleName -eq 'Microsoft.Online.SharePoint.PowerShell') {
            $newContent += " # includes OneDrive"
        }
        elseif ($module.ModuleName -eq 'PnP.PowerShell') {
            $newContent += " # alternate for SharePoint PowerShell"
        }
        
        $newContent += "`n        ModuleVersion = [version] '$($module.ModuleVersion)'"
        $newContent += "`n        MaximumVersion = [version] '$($module.MaximumVersion)'"
        
        # Add IsPinned property if it exists
        if ($module.IsPinned) {
            $newContent += "`n        IsPinned = `"$($module.IsPinned)`""
        }
        
        if ($i -eq $newModuleList.Count - 1) {
            $newContent += "`n    }"
        } else {
            $newContent += "`n    },"
        }
    }
    
    $newContent += "`n)"
    
    # Write the updated content back to the file
    Set-Content -Path $scriptPath -Value $newContent
    Write-Information "RequiredVersions.ps1 file has been updated successfully." -InformationAction Continue
}
else {
    Write-Information "No updates were necessary. All modules are already at the latest version or pinned." -InformationAction Continue
}
