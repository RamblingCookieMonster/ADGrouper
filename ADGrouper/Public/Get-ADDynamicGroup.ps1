Function Get-ADDynamicGroup {
    <#
    .SYNOPSIS
	    Parse yaml describing dynamic security groups

    .DESCRIPTION
	    Parse yaml describing dynamic security groups

        This parses the yaml without hitting Active Directory

    .FUNCTIONALITY
        Active Directory

    .PARAMETER InputObject
        Yaml dynamic group definition

    .PARAMETER Path
        Path to yaml containing dynamic group definition

    .EXAMPLE
        Get-ADDynamicGroup $Yaml

    .LINK
        https://github.com/RamblingCookieMonster/ADGrouper

    .LINK
        Expand-ADDynamicGroup

    .LINK
        Invoke-ADGrouper

    .LINK
        about_ADGrouper
    #>
    [cmdletbinding( DefaultParameterSetName = 'yaml' )]
    param(
        [parameter(ParameterSetName = 'yaml',
                   ValueFromPipeline = $True)]
        [string]$InputObject,

        [parameter(ParameterSetName = 'file',
                   ValueFromPipelineByPropertyName = $True)]
        [Alias('FullName')]
        [string[]]$Path
    )
    begin
    {
        function Parse-Option {
            param($Target, $Name, $Type)
            $ThisItem = $Target.$Type.get_item($Name)
            $ThisRecurse = if($ThisItem -is [hashtable] -and $ThisItem.ContainsKey('Recurse')) {$ThisItem.Recurse} else {$Recurse}
            $ThisPurge = if($ThisItem -is [hashtable] -and $ThisItem.ContainsKey('Purge')) {$ThisItem.Purge} else {$Purge}
            $ThisExpand = if($ThisItem -is [hashtable] -and $ThisItem.ContainsKey('Expand')) {$ThisItem.Expand} else {$Expand}
            [pscustomobject]@{
                Account = $Name
                Recurse = $ThisRecurse
                Purge = $ThisPurge
                Expand = $ThisExpand
            }
        }
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
    
        $ValuesForTrue = '1', 'True', 'Yes', $True
        foreach($Yaml in $ToProcess)
        {
            $Groups = ConvertFrom-Yaml -Yaml $Yaml
            foreach($GroupName in $Groups.keys)
            {
                $Group = $Groups[$GroupName]

                # Parse global options
                $Recurse = $False
                if($null -eq $Group.Recurse -or $ValuesForTrue -contains $Group.Recurse)
                {
                    $Recurse = $True
                }
                $Expand = $False
                if($null -eq $Group.Expand -or $ValuesForTrue -contains $Group.Expand)
                {
                    $Expand = $True
                }
                $Purge = $False
                if($ValuesForTrue -contains $Group.Purge)
                {
                    $Purge = $True
                }
                $IncludeQuery = $null
                if($Group.IncludeQuery)
                {
                    $IncludeQuery = $Group.IncludeQuery
                }
                $ExcludeQuery = $null
                if($Group.ExcludeQuery)
                {
                    $ExcludeQuery = $Group.ExcludeQuery
                }

                [pscustomobject]@{
                    PSTypeName = 'adgrouper.group'
                    TargetGroup = $GroupName
                    Recurse = $Recurse
                    Purge = $Purge
                    Expand = $Expand
                    IncludeQuery = $IncludeQuery
                    Include = $Group.Include.keys | Foreach {
                        Parse-Option -Target $Group -Name $_ -Type Include
                    }
                    Exclude = $Group.Exclude.keys | Foreach {
                        Parse-Option -Target $Group -Name $_ -Type Exclude
                    }
                    ExcludeQuery = $ExcludeQuery
                }
            }
        }
    }
}
