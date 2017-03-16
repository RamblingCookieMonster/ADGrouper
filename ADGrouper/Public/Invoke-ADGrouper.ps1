Function Invoke-ADGrouper {
    <#
    .SYNOPSIS
	    Adjust AD group membership based on yaml config files

    .DESCRIPTION
	    Adjust AD group membership based on yaml config files

        YAML schema:

        'Target Group':        # Target security group we are populating
          Purge:               # If specified, remove existing accounts in the group not included in this definition.  Like robocopy...  Default is false.
          Recurse:             # If specified and a source is a group, recurse membership for that group.  Defaults to true.  Can be overriden at source level
          Expand:              # If specified and a source is a group, expand to individual accounts within the group.  Defaults to true.  Can be overriden at source level
          Exclude:             # Accounts to exclude from this group.  Overrides being included
            Account1:
            Account2:          # Exclude account with overriden Expand and Recurse
              - Expand: False
              - Recurse: False
          ExcludeQuery         # One or more LDAP queries whose resulting accounts are excluded from the target group
          IncludeQuery:        # One or more LDAP queries whose resulting accounts are included in the target group
            - '(a=b)'
            - '(c=d)'
          Account3             # Include account with global settings, or if not globally specified, Recurse=True, Expand=True
          Account4             # Include account with overriden Expand and Recurse
            - Expand: False
            - Recurse: False

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