function Get-ADObjectClass {
    [cmdletbinding()]
    param(
        $sAMAccountName,
        $IncludeType = $True
    )
    if($IncludeType)
    {
        $Type = ( Get-ADSIObject $sAMAccountName -Property objectClass ).objectClass
        if($Type.count -gt 0)
        {
            switch ($Type[-1])
            {
                'user'  {'User'}
                'group' {'Group'}
                Default { Write-Warning "sAMAccountName [$sAMAccountName] is an unsupported type, [$($Type -join ', ')]"}
            }
        }
    }
}