$ErrorActionPreference = 'Stop'

$LogDir  = 'C:\ProgramData\xperf'
$LogFile = Join-Path $LogDir 'xperf_task_acl.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Log([string]$m) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  try { Add-Content -Path $LogFile -Value "$ts $m" -Encoding UTF8 } catch { }
}

# Allow BUILTIN\Users to read + run; keep SYSTEM/Admin full control
$Sddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;BU)'

$Tasks = @(
  'xperf_kernel_trace_start',
  'xperf_kernel_trace_stop'
)

$tmp = Join-Path $env:TEMP ("xperf_task_acl_{0}" -f (Get-Random))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
  foreach ($t in $Tasks) {
    Log "BEGIN task=$t"

    # Export XML
    $raw = & schtasks /query /tn $t /xml 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
      Log "ERROR export failed task=$t rc=$LASTEXITCODE out=$raw"
      throw "Failed to export task XML for '$t'"
    }

    $xmlPath = Join-Path $tmp "$t.xml"

    # schtasks output can be array; normalize to string with newlines
    $xmlText = ($raw | Out-String)

    # Parse XML
    [xml]$doc = $xmlText

    $nsUri = $doc.DocumentElement.NamespaceURI
    $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('t', $nsUri)

    $sdNode = $doc.SelectSingleNode('/t:Task/t:SecurityDescriptor', $ns)
    if (-not $sdNode) {
      $sdNode = $doc.CreateElement('SecurityDescriptor', $nsUri)
      $null = $doc.DocumentElement.AppendChild($sdNode)
      Log "INFO created SecurityDescriptor node task=$t"
    }

    $current = $sdNode.InnerText
    if ($current -eq $Sddl) {
      Log "INFO already set task=$t"
      continue
    }

    $sdNode.InnerText = $Sddl
    $doc.Save($xmlPath)

    # Re-import XML (forces updated SDDL)
    $out = & schtasks /create /tn $t /xml $xmlPath /f 2>&1
    if ($LASTEXITCODE -ne 0) {
      Log "ERROR import failed task=$t rc=$LASTEXITCODE out=$out"
      throw "Failed to import task '$t' with updated SDDL"
    }

    Log "OK updated task=$t"
  }

  Log "DONE all tasks updated/verified"
  exit 0
}
catch {
  Log ("FATAL {0}" -f $_.Exception.ToString())
  exit 0
}
finally {
  try { Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } catch { }
}
