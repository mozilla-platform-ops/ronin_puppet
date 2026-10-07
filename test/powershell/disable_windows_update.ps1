param(
    [string]$ScriptPath = "$PSScriptRoot/../../modules/win_disable_services/files/disable_wu_task.ps1"
)

$ErrorActionPreference = 'Stop'
$global:testEvents = [System.Collections.Generic.List[string]]::new()
$global:testServices = foreach ($name in @('wuauserv', 'usosvc', 'WaaSMedicSvc')) {
    $service = [pscustomobject]@{
        Name = $name
        Status = $(if ($name -eq 'WaaSMedicSvc') { 'Stopped' } else { 'Running' })
        StartType = 'Manual'
    }
    $service | Add-Member ScriptMethod WaitForStatus {
        param($status, $timeout)
        if ($this.Status -ne $status) { throw "Waited on an unstopped service: $($this.Name)" }
        $global:testEvents.Add("wait:$($this.Name)")
    }
    $service
}

function Get-Service {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][string]$Name)
    process { $global:testServices | Where-Object Name -EQ $Name }
}
function Set-Service {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject, [string]$StartupType)
    process {
        $InputObject.StartType = $StartupType
        $global:testEvents.Add("disable:$($InputObject.Name)")
    }
}
function Stop-Service {
    [CmdletBinding()]
    param($InputObject, [switch]$Force)
    if (@($global:testServices | Where-Object StartType -NE 'Disabled').Count) {
        throw 'Disable every update service before stopping or waiting on any service.'
    }
    $InputObject.Status = 'Stopped'
    $global:testEvents.Add("stop:$($InputObject.Name)")
}
function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskPath)
}
function Disable-ScheduledTask {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject)
}

& $ScriptPath
if (@($global:testServices | Where-Object StartType -NE 'Disabled').Count) {
    throw 'An update service remains enabled.'
}
if (($global:testEvents -join ',') -ne 'disable:wuauserv,disable:usosvc,disable:WaaSMedicSvc,stop:wuauserv,wait:wuauserv,stop:usosvc,wait:usosvc') {
    throw "Unexpected service operation order: $($global:testEvents -join ',')"
}
if ($ErrorActionPreference -ne 'Stop') { throw 'The script did not restore ErrorActionPreference.' }
Write-Output 'PASS: disable all update services first and wait only on the stopped service'
