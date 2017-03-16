function Expand-Account {
    [cmdletbinding()]
    param(
        $Identity,
        $Type,
        [switch]$Recurse,
        [switch]$Expand
    )
    if($Type -eq 'Group' -and $Expand)
    {
        $params = @{
            Identity = $Identity
        }
        if($Recurse)
        {
            $params.add('Recursive', $True)
        }
        (Get-ADGroupMember @params).samaccountname # TODO: Consider non-ActiveDirectory module implementation
    }
    else
    {
        $Identity
    }
}