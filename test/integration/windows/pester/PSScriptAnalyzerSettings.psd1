@{
    IncludeDefaultRules = $true
    # Pester setup and dot-sourced settings define variables read in other scopes.
    ExcludeRules        = @('PSUseDeclaredVarsMoreThanAssignments')
    Rules               = @{
        PSUseCompatibleSyntax      = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseConsistentWhitespace  = @{
            Enable          = $true
            CheckInnerBrace = $true
            CheckOpenBrace  = $false
            CheckOpenParen  = $true
            CheckOperator   = $false
            CheckPipe       = $true
            CheckSeparator  = $true
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSAvoidTrailingWhitespace  = @{ Enable = $true }
    }
}
