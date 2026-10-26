# New-Users.ps1 - Create Active Directory users from a CSV file
#
# Usage   : .\New-Users.ps1
# CSV     : C:\Scripts\users.csv with columns FirstName,LastName,Department
#           Department must match an OU under OU=Utilisateurs and a GG_<Department> group.
#
# - The initial password is prompted at runtime and never stored.
# - Users must change it at first logon.
# - Idempotent: existing accounts are skipped.

$root     = "OU=COMPANY,DC=company,DC=local"
$csvPath  = "C:\Scripts\users.csv"
$password = Read-Host "Initial password" -AsSecureString

Import-Csv $csvPath | ForEach-Object {
    $sam = ($_.FirstName + "." + $_.LastName).ToLower()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Warning "$sam already exists, skipped"
        return
    }

    $params = @{
        Name                  = "$($_.FirstName) $($_.LastName)"
        GivenName             = $_.FirstName
        Surname               = $_.LastName
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@company.local"
        Path                  = "OU=$($_.Department),OU=Utilisateurs,$root"
        Department            = $_.Department
        AccountPassword       = $password
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    try {
        New-ADUser @params -ErrorAction Stop
        Add-ADGroupMember -Identity "GG_$($params.Department)" -Members $sam -ErrorAction Stop
        Write-Host "Created: $sam ($($params.Department))"
    }
    catch {
        Write-Warning "FAILED for $sam : $($_.Exception.Message)"
    }
}
