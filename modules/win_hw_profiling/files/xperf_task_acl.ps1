$ErrorActionPreference = 'Stop'

# Allow BUILTIN\Users to read + run the task
# SDDL notes:
# - SY = Local System full
# - BA = Built-in Administrators full
# - BU = Built-in Users: GR (read) + GX (execute)
# This is the key bit: (A;;GRGX;;;BU)
$Sddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;BU)'

$Tasks = @(
  'xperf_kernel_trace_start',
  'xperf_kernel_trace_stop'
)

$tmp = Join-Path $env:TEMP ("xperf_task_acl_{0}" -f (Get-Random))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

foreach ($t in $Tasks) {
  $xml = Join-Path $tmp "$t.xml"

  # Export existing task XML
  $raw = & schtasks /query /tn $t /xml 2>&1
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    throw "Failed to export task XML for '$t': $raw"
  }
  Set-Content -Path $xml -Value ($raw | Out-String) -Encoding Unicode

  # Load XML, set/replace SecurityDescriptor
  [xml]$doc = Get-Content -Path $xml

  $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  $ns.AddNamespace('t', $doc.DocumentElement.NamespaceURI)

  $sdNode = $doc.SelectSingleNode('//t:SecurityDescriptor', $ns)
  if ($sdNode) {
    $sdNode.InnerText = $Sddl
  } else {
    # Insert under <Principal>’s parent section (RegistrationInfo/Triggers/Principals/Settings…)
    # SecurityDescriptor is a direct child of <Task>
    $new = $doc.CreateElement('SecurityDescriptor', $doc.DocumentElement.NamespaceURI)
    $new.InnerText = $Sddl
    $null = $doc.DocumentElement.AppendChild($new)
  }

  $doc.Save($xml)

  # Re-import task (keeps everything else the same but applies the new SDDL)
  $out = & schtasks /create /tn $t /xml $xml /f 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to import task '$t' with updated SDDL: $out"
  }
}

Write-Host "Updated task ACLs: granted BUILTIN\Users read/run for: $($Tasks -join ', ')"
