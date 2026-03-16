Describe "Cache VCS Checkout" {
    It "Mozilla Unified Directory" {
        Test-Path "C:\vcs-checkout" | Should -Be True
    }
    It "Mozilla Unified contains revision" {
        (Get-ChildItem "C:\vcs-checkout\*").Name | Should -Not -BeNullOrEmpty
    }
}
