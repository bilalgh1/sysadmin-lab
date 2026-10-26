# New-Users.ps1 - Creation d'utilisateurs AD a partir d'un CSV
#
# Usage : .\New-Users.ps1
# CSV attendu (C:\Scripts\users.csv) : Prenom,Nom,Service
# Le service doit correspondre a une OU sous OU=Utilisateurs et a un groupe GG_<Service>.
#
# - Le mot de passe initial est demande a l'execution, jamais stocke.
# - L'utilisateur doit le changer a sa premiere connexion.
# - Idempotent : un compte existant est ignore.

$root     = "OU=COMPANY,DC=company,DC=local"
$csvPath  = "C:\Scripts\users.csv"
$password = Read-Host "Mot de passe initial" -AsSecureString

Import-Csv $csvPath | ForEach-Object {
    $sam = ($_.Prenom + "." + $_.Nom).ToLower()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Warning "$sam existe deja, ignore"
        return
    }

    $params = @{
        Name                  = "$($_.Prenom) $($_.Nom)"
        GivenName             = $_.Prenom
        Surname               = $_.Nom
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@company.local"
        Path                  = "OU=$($_.Service),OU=Utilisateurs,$root"
        Department            = $_.Service
        AccountPassword       = $password
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    try {
        New-ADUser @params -ErrorAction Stop
        Add-ADGroupMember -Identity "GG_$($params.Department)" -Members $sam -ErrorAction Stop
        Write-Host "Cree : $sam ($($params.Department))"
    }
    catch {
        Write-Warning "ECHEC pour $sam : $($_.Exception.Message)"
    }
}
