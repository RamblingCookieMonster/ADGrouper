$PSVersion = $PSVersionTable.PSVersion.Major
if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    {
        $Verbose.add("Verbose",$True)
    }

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = Get-Module $ENV:BHProjectName 
            $Module.Name | Should be $ENV:BHProjectName
            $Module.ExportedCommands.Keys -contains 'Invoke-ADGrouper' | Should Be $True
        }
    }
}

Describe "Get-ADDynamicGroup PS$PSVersion" {

    It 'Should parse a simple yaml file with expected defaults' {
        $Simple = Get-ADDynamicGroup -Path (Join-Path $ENV:BHProjectPath 'Tests/Data/simple.yaml')
        $Simple.TargetGroup | Should Be 'target_group'
        $Simple.Recurse | Should Be $True
        $Simple.Purge | Should Be $False
        $Simple.Expand | Should Be $True
        $Simple.IncludeQuery | Should Be '(a=b)'
        $Simple.ExcludeQuery | Should Be '(b=a)'
        $Simple.Exclude.Account | Should Be 'bad_account'
        $Simple.Include.Account -Contains 'source group' | should be $True
        $Simple.Include.Account -Contains 'good_account' | should be $True
        $include = $Simple.Include | Where {$_.Account -eq 'source group'}
        $include.Recurse | Should Be $True
        $include.Purge | Should Be $False
        $include.Expand | Should Be $True
    }

    It 'Should allow overrides of options' {
        $override = Get-ADDynamicGroup -Path (Join-Path $ENV:BHProjectPath 'Tests/Data/override.yaml')
        $override.TargetGroup | Should Be 'target_group2'
        $override.Recurse | Should Be $False
        $override.Purge | Should Be $True
        $override.Expand | Should Be $False
        $override.IncludeQuery | Should Be '(c=d)'
        $override.ExcludeQuery | Should Be '(d=c)'
        $override.Exclude.Account | Should Be 'bad_account2'
        $override.Include.Account -Contains 'source group2' | should be $True
        $override.Include.Account -Contains 'source group3' | should be $True
        $override.Include.Account -Contains 'good_account2' | should be $True
        $includeoverride = $override.Include | Where {$_.Account -eq 'source group2'}
        $includeoverride.Recurse | Should Be $True
        $includeoverride.Purge | Should Be $False
        $includeoverride.Expand | Should Be $True    
        $includeglobal = $override.Include | Where {$_.Account -eq 'source group3'}
        $includeglobal.Recurse | Should Be $False
        $includeglobal.Purge | Should Be $True
        $includeglobal.Expand | Should Be $False  
    }

    It "Should handle multiple files" {
        $Files = (Join-Path $ENV:BHProjectPath 'Tests/Data/simple.yaml'),
                 (Join-Path $ENV:BHProjectPath 'Tests/Data/override.yaml')
        $multiple = Get-ADDynamicGroup -Path $Files
        $multiple.count | Should Be 2

        $simple = $multiple | Where {$_.targetgroup -like 'target_group'}
        $Simple.TargetGroup | Should Be 'target_group'
        $Simple.Recurse | Should Be $True
        $Simple.Purge | Should Be $False
        $Simple.Expand | Should Be $True
        $Simple.IncludeQuery | Should Be '(a=b)'
        $Simple.ExcludeQuery | Should Be '(b=a)'
        $Simple.Exclude.Account | Should Be 'bad_account'
        $Simple.Include.Account -Contains 'source group' | should be $True
        $Simple.Include.Account -Contains 'good_account' | should be $True
        $include = $Simple.Include | Where {$_.Account -eq 'source group'}
        $include.Recurse | Should Be $True
        $include.Purge | Should Be $False
        $include.Expand | Should Be $True

        $override = $multiple | Where {$_.targetgroup -like 'target_group2'}
        $override.TargetGroup | Should Be 'target_group2'
        $override.Recurse | Should Be $False
        $override.Purge | Should Be $True
        $override.Expand | Should Be $False
        $override.IncludeQuery | Should Be '(c=d)'
        $override.ExcludeQuery | Should Be '(d=c)'
        $override.Exclude.Account | Should Be 'bad_account2'
        $override.Include.Account -Contains 'source group2' | should be $True
        $override.Include.Account -Contains 'source group3' | should be $True
        $override.Include.Account -Contains 'good_account2' | should be $True
        $includeoverride = $override.Include | Where {$_.Account -eq 'source group2'}
        $includeoverride.Recurse | Should Be $True
        $includeoverride.Purge | Should Be $False
        $includeoverride.Expand | Should Be $True    
        $includeglobal = $override.Include | Where {$_.Account -eq 'source group3'}
        $includeglobal.Recurse | Should Be $False
        $includeglobal.Purge | Should Be $True
        $includeglobal.Expand | Should Be $False  

    }

    It 'Supports yaml input' {
        $Files = (Join-Path $ENV:BHProjectPath 'Tests/Data/simple.yaml'),
                 (Join-Path $ENV:BHProjectPath 'Tests/Data/override.yaml')
        $multiple = $Files | Foreach {Get-Content $_ -Raw} | Get-ADDynamicGroup
        $multiple.count | Should Be 2

        $simple = $multiple | Where {$_.targetgroup -like 'target_group'}
        $Simple.TargetGroup | Should Be 'target_group'
        $Simple.Recurse | Should Be $True
        $Simple.Purge | Should Be $False
        $Simple.Expand | Should Be $True
        $Simple.IncludeQuery | Should Be '(a=b)'
        $Simple.ExcludeQuery | Should Be '(b=a)'
        $Simple.Exclude.Account | Should Be 'bad_account'
        $Simple.Include.Account -Contains 'source group' | should be $True
        $Simple.Include.Account -Contains 'good_account' | should be $True
        $include = $Simple.Include | Where {$_.Account -eq 'source group'}
        $include.Recurse | Should Be $True
        $include.Purge | Should Be $False
        $include.Expand | Should Be $True

        $override = $multiple | Where {$_.targetgroup -like 'target_group2'}
        $override.TargetGroup | Should Be 'target_group2'
        $override.Recurse | Should Be $False
        $override.Purge | Should Be $True
        $override.Expand | Should Be $False
        $override.IncludeQuery | Should Be '(c=d)'
        $override.ExcludeQuery | Should Be '(d=c)'
        $override.Exclude.Account | Should Be 'bad_account2'
        $override.Include.Account -Contains 'source group2' | should be $True
        $override.Include.Account -Contains 'source group3' | should be $True
        $override.Include.Account -Contains 'good_account2' | should be $True
        $includeoverride = $override.Include | Where {$_.Account -eq 'source group2'}
        $includeoverride.Recurse | Should Be $True
        $includeoverride.Purge | Should Be $False
        $includeoverride.Expand | Should Be $True    
        $includeglobal = $override.Include | Where {$_.Account -eq 'source group3'}
        $includeglobal.Recurse | Should Be $False
        $includeglobal.Purge | Should Be $True
        $includeglobal.Expand | Should Be $False  
    }
}

