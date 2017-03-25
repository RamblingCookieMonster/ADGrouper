# ADGrouper

This is a module to define and populate dynamic AD security groups based on a yaml config file.

Certain solutions don't support nested security groups, or perform better without nested security groups. ADGrouper allows you to define expected group membership based on groups or users to include, recursion, LDAP queries, and more.

This is a work in progress; it's not fully featured or tested, and there may be breaking changes.  Silly blog post pending.

Pull requests and other contributions would be welcome!

## Instructions

```powershell
# Install with PowerShell 5 or PowerShellGet module
    Install-Module ADGrouper

# Instaell via GitHub
    # Download the repository
    # Unblock the zip
    # Extract the ADGrouper folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

# Import the module.
    Import-Module ADGrouper
    #Alternatively, Import-Module \\Path\To\ADGrouper

# Get commands in the module
    Get-Command -Module ADGrouper

# Get help
    Get-Help Invoke-ADGrouper -Full
    Get-Help about_ADGrouper
```

### Prerequisites

* PowerShell 3 or later
* ActiveDirectory module ([#1](https://github.com/RamblingCookieMonster/ADGrouper/issues/1))
* Target groups already exist ([#4](https://github.com/RamblingCookieMonster/ADGrouper/issues/4))
* These yaml files are locked down, ideally in source control, and your team members know which groups are affected (maybe they have a clear OU or description)

## ADGrouper Yaml Schema

ADGrouper uses yaml.  We read yaml files with the following expected syntax:
    
 ```yaml
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
```

## Example

Here are some groups and their users that we have in AD:

* TargetGroup
   * ManualAccount1
   * Account1
   * AccountX
* SourceGroup1
   * Account1
   * Account2
   * Account3
 * SourceGroup2
   * AccountX
 * SourceGroupRaw
 * RestrictedUsers
   * Account2

And here's what we actually want:

* TargetGroup to include anyone who is ever added to SourceGroup1 and SourceGroup2
* To ensure no users from RestrictedUsers are in TargetGroup
* To add SourceGroupRaw to TargetGroup as a nested group
* To remove any accounts manually added to TargetGroup (i.e. mirror/purge)

So!  Here's what we want to actually happen:

* Remove ManualAccount1 from TargetGroup (purge, and account is not in any include definition)
* Add Account3 to TargetGroup (in SourceGroup1, not in TargetGroup)
* Add SourceGroupRaw to TargetGroup (set to not expand, not in TargetGroup)

Here's some yaml we'll use to accomplish this:

```yaml
TargetGroup:
  Purge: True
  Exclude:
    RestrictedUsers:
  Include:
    SourceGroup1:
    SourceGroup2:
    SourceGroupRaw:
      Expand: False
```

Let's see how this works!

```powershell
# Assuming example yaml has content above
# Review info before querying AD:
Get-ADDynamicGroup \\Path\To\Example.yaml

    # TargetGroup  : TargetGroup
    # Recurse      : True
    # Purge        : True
    # Expand       : True
    # IncludeQuery : 
    # Include      : {@{Account=SourceGroup1; Recurse=True; Purge=True; Expand=True},
    #                @{Account=SourceGroup2; Recurse=True; Purge=True; Expand=True},
    #                @{Account=SourceGroupRaw; Recurse=True; Purge=True; Expand=False}}
    # Exclude      : @{Account=RestrictedUsers; Recurse=True; Purge=True; Expand=True}
    # ExcludeQuery : 

# Now, let's see what would actually change
$Yaml | Get-ADDynamicGroup | Expand-ADDynamicGroup

    # Group      : TargetGroup
    # Account    : ManualAccount1
    # Action     : Remove
    # Type       : 

    # Group      : TargetGroup
    # Account    : Account3
    # Action     : Add
    # Type       : 

    # Group      : TargetGroup
    # Account    : SourceGroupRaw
    # Action     : Add
    # Type       : 

# Perfect, this is exactly what I want!  Let's whatif, just in case.
$Yaml | Invoke-ADGrouper -WhatIf

    # What if: Group changed '[Remove] [ManualAccount1] to/from [TargetGroup]'
    # What if: Group changed '[Add] [Account3] to/from [TargetGroup]'
    # What if: Group changed '[Add] [SourceGroupRaw] to/from [TargetGroup]'

# Let's make the change!  You might schedule this to run on some interval
# In case it isn't obvious, keep your yaml files very secure, and use source control : )
$Yaml | Invoke-ADGrouper -Confirm:$False -Force

# And did it work?
Get-ADGroupMember TargetGroup | Select -ExpandProperty SamAccountName

    # SourceGroupRaw
    # Account1
    # Account3
    # AccountX

# Yep!
```

## Notes

A huge thanks to cloudbase for open sourcing their [PowerShell-Yaml module](https://github.com/cloudbase/powershell-yaml).  This is the only yaml module that (1) is in the PowerShell Gallery, and (2) converts to and from yaml.
