Describe "Microsoft Tools" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    It "<_.DisplayName> is installed" -ForEach @(
        Show-Win11SDK
    ) {
        $_ | Should -Not -Be $null
    }

    It "<_.DisplayName> is 10.1.22621.5040" -ForEach @(
        Show-Win11SDK
    ) {
        $_.DisplayVersion | Should -Be "10.1.22621.5040"
    }
}
