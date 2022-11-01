Function Invoke-RoninTest {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Test,

        [String[]]
        $Tags,

        [String[]]
        $ExcludeTag,

        [Switch]
        $PassThru
    )
    $Container = New-PesterContainer -Path $test
    $config = New-PesterConfiguration
    $config.Run.Container = $Container
    $config.Filter.Tag = $Tags
    $config.TestResult.Enabled = $true
    $config.Output.Verbosity = "Detailed"
    if ($ExcludeTag) {
        $config.Filter.ExcludeTag = $ExcludeTag
    }
    if ($PassThru) {
        $config.Run.Passthru = $true
    }
    Invoke-Pester -Configuration $config
}
