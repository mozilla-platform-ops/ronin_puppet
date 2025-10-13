function Set-WindowState {
    <#
    .SYNOPSIS
    Set the state of a window.

    .DESCRIPTION
    Set the state of a window using the `ShowWindowAsync` function from `user32.dll`.

    .PARAMETER InputObject
    The process object(s) to set the state of. Can be piped from `Get-Process`.

    .PARAMETER State
    The state to set the window to. Default is 'SHOW'.

    .PARAMETER SuppressErrors
    Suppress errors when the main window handle is '0'.

    .PARAMETER SetForegroundWindow
    Set the window to the foreground

    .PARAMETER ThresholdHours
    The number of hours to keep the window handle in memory. Default is 24.

    .EXAMPLE
    Get-Process notepad | Set-WindowState -State HIDE -SuppressErrors

    .EXAMPLE
    Get-Process notepad | Set-WindowState -State SHOW -SuppressErrors

    .LINK
    https://gist.github.com/lalibi/3762289efc5805f8cfcf

    .NOTES
    Original idea from https://gist.github.com/Nora-Ballard/11240204
    #>

    [CmdletBinding(DefaultParameterSetName = 'InputObject')]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [Object[]] $InputObject,

        [Parameter(Position = 1)]
        [ValidateSet(
            'FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE',
            'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED',
            'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL'
        )]
        [string] $State = 'SHOW',
        [switch] $SuppressErrors = $false,
        [switch] $SetForegroundWindow = $false,
        [int] $ThresholdHours = 24
    )

    Begin {
        $WindowStates = @{
            'FORCEMINIMIZE'   = 11
            'HIDE'            = 0
            'MAXIMIZE'        = 3
            'MINIMIZE'        = 6
            'RESTORE'         = 9
            'SHOW'            = 5
            'SHOWDEFAULT'     = 10
            'SHOWMAXIMIZED'   = 3
            'SHOWMINIMIZED'   = 2
            'SHOWMINNOACTIVE' = 7
            'SHOWNA'          = 8
            'SHOWNOACTIVATE'  = 4
            'SHOWNORMAL'      = 1
        }

        $Win32ShowWindowAsync = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
'@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

        $global:MainWindowHandles = @{}

    }

    Process {
        foreach ($process in $InputObject) {
            $handle = $process.MainWindowHandle

            if ($handle -eq 0 -and $global:MainWindowHandles.ContainsKey($process.Id)) {
                $handle = [int] $global:MainWindowHandles[$process.Id].Handle
            }

            if ($handle -eq 0) {
                if (-not $SuppressErrors) {
                    Write-Error "Main Window handle is '0'"
                }
                else {
                    Write-Verbose ("Skipping '{0}' with id '{1}', because Main Window handle is '0'" -f $process.ProcessName, $process.Id)
                }

                continue
            }

            Write-Verbose ("Processing '{0}' with id '{1}' and handle '{2}'" -f $process.ProcessName, $process.Id, $handle)

            $global:MainWindowHandles[$process.Id] = @{
                Handle    = $handle.ToString()
                Timestamp = (Get-Date).ToString("o")
            }

            $Win32ShowWindowAsync::ShowWindowAsync($handle, $WindowStates[$State]) | Out-Null

            if ($SetForegroundWindow) {
                $Win32ShowWindowAsync::SetForegroundWindow($handle) | Out-Null
            }

            Write-Verbose ("» Set Window State '{1}' on '{0}'" -f $handle, $State)
        }
    }

    End {
        $data = [ordered] @{}

        foreach ($key in $global:MainWindowHandles.Keys) {
            if ($global:MainWindowHandles[$key].Handle -ne 0) {
                $data["$key"] = $global:MainWindowHandles[$key]
            }
        }
    }
}

while ($true) {
    ## Minimize the cmd.exe window that pops up when running a task
    ## Check every 5 seconds for cmd.exe and suppress it
    
    $cmdproc = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "C:\windows\System32\cmd.exe" }
    #$explorerProc = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
    
    if ($null -ne $cmdproc) {
        Write-Log -Message ('{0} :: Found {1} cmd.exe process(es), hiding window(s)' -f $($MyInvocation.MyCommand.Name), $cmdproc.Count) -severity 'DEBUG'
        $cmdproc | Set-WindowState -State HIDE
    }

    # if ($null -ne $explorerProc) {
    #     Write-Log -Message ('{0} :: Found {1} explorer process(es), hiding window(s)' -f $($MyInvocation.MyCommand.Name), $explorerProc.Count) -severity 'DEBUG'
    #     $explorerProc | Set-WindowState -State HIDE
    # }

    # ## Now let's kill explorer while we're at it
    # $explorerProc = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
    # if ($null -ne $explorerProc) {
    #     Write-Log -Message ('{0} :: Stopping explorer process' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    #     $explorerProc | Stop-Process -Force
    # }
    
    Start-Sleep -Seconds 5
}