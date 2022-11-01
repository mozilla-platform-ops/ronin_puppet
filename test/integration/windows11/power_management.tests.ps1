Describe "Power Plan" {
    It "Windows Power plan set to high performance" {
        ((Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan) |
        Where-Object { $PSItem.ElementName -eq "High performance" }).IsActive |
        Should -BeTrue
    }
}
