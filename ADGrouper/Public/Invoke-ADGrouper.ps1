Function Invoke-ADGrouper {
    <#
    .SYNOPSIS
	    Adjust AD group membership based on yaml config files

    .DESCRIPTION
	    Adjust AD group membership based on yaml config files

        YAML schema:

        'Target Group':        # Target security group we are populating
          Purge:               # Whether to remove existing accounts in the groupthat aren't included in this definition. Defaults to false
          Recurse:             # Whether to recurse membership when source is a group. Defaults to true
          Expand:              # Whether to expand to individual accounts within the group, or use the group explicitly. Defaults to true
          Exclude:             # Accounts to exclude from this group
            BadUser:           # Exclude account
            BadGroup:          # Exclude account with overriden Recurse
              - Recurse: False
          ExcludeQuery:        # One or more LDAP queries whose resulting accounts are excluded from the target group
            - '(b=a)'
          Include:             # Accounts to include in this group
            GoodGroup:         # Include account with global settings
            GoodGroup2:        # Include account with overriden Expand and Recurse
            - Expand: False
            - Recurse: False
          IncludeQuery:        # One or more LDAP queries whose resulting accounts are included in the target group
            - '(a=b)'
            - '(c=d)'

    .FUNCTIONALITY
        Active Directory

    .PARAMETER InputObject
        Yaml dynamic group definition

    .PARAMETER Path
        Path to yaml containing dynamic group definition

    .EXAMPLE
        Invoke-ADGrouper $Yaml -Whatif

        # See what Invoke-ADGrouper would do with yaml, without doing it

    .Example
        Invoke-ADGrouper -Path \\Path\To\example.yaml -Confirm:$False -Force

        # Run example.yaml through Invoke-ADGrouper without confirmation

    .LINK
        Get-ADDynamicGroup

    .LINK
        Expand-ADDynamicGroup

    .LINK
        about_ADGrouper
    #>
    [cmdletbinding( DefaultParameterSetName = 'yaml',
                    SupportsShouldProcess=$True,
                    ConfirmImpact='High')]
    param(
        [parameter(ParameterSetName = 'yaml',
                   ValueFromPipeline = $True)]
        [string]$InputObject,

        [parameter(ParameterSetName = 'file',
                   ValueFromPipelineByPropertyName = $True)]
        [Alias('FullName')]
        [string[]]$Path,

        [switch]$Force
    )
    begin
    {
        $RejectAll = $false
        $ConfirmAll = $false
    }
    process
    {
        $ToProcess = [System.Collections.ArrayList]@()
        if($PSCmdlet.ParameterSetName -eq 'file')
        {
            foreach($File in $Path)
            {
                $ToProcess.AddRange( @(Get-Content $File -Raw) )
            }
        }
        else
        {
            [void]$ToProcess.Add($InputObject)
        }
        Write-Verbose ($ToProcess | Out-String)
        $ToExpand = $ToProcess | Get-ADDynamicGroup
        $ToChange = Expand-ADDynamicGroup -InputObject $ToExpand
        foreach($Change in $ToChange)
        {
            $Todo = "[{0}] [{1}] to/from [{2}]" -f $Change.Action, $Change.Account, $Change.Group
            if($PSCmdlet.ShouldProcess( "Group changed '$Todo'",  "Group change '$Todo'?", "Changing group membership" ))
            {    
                if($Force -or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change '$Todo'?", "Removing '$Todo'", [ref]$ConfirmAll, [ref]$RejectAll))
                {
                    switch ($Change.Action)
                    {
                        'Add' {
                            Add-ADGroupMember -Identity $Change.Group -Members $Change.Account
                        }
                        'Remove' {
                            Remove-ADGroupMember -Identity $Change.Group -Members $Change.Account
                        }
                    }
                }
            }
        }
    }
}