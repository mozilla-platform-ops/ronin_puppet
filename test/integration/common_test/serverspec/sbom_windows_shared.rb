sbom_dir = 'C:\\sbom'
sbom_base = "#{sbom_dir}\\ronin-sbom"
sbom_paths = {
  cyclonedx: "#{sbom_base}.cdx.json",
  inventory: "#{sbom_base}.inventory.json",
  markdown: "#{sbom_base}.md",
}

sbom_paths.each_value do |path|
  describe file(path) do
    it { should exist }
  end

  describe powershell_command("if ((Get-Item '#{path}' -ErrorAction Stop).Length -gt 0) { exit 0 } else { exit 1 }") do
    its(:exit_status) { should eq 0 }
  end
end

describe powershell_command(<<~POWERSHELL) do
  $bom = Get-Content -Raw -Path '#{sbom_paths[:cyclonedx]}' | ConvertFrom-Json
  if ($bom.bomFormat -ne 'CycloneDX') { exit 1 }
  if ($bom.specVersion -ne '1.5') { exit 1 }
  if (@($bom.components).Count -lt 1) { exit 1 }

  $sources = @(
    foreach ($component in @($bom.components)) {
      foreach ($property in @($component.properties)) {
        if ($property.name -eq 'ronin:source') {
          $property.value
        }
      }
    }
  )

  foreach ($source in @('windows-installed-program', 'puppet-ral-service', 'windows-driver')) {
    if ($sources -notcontains $source) { exit 1 }
  }

  '{0} {1} {2}' -f $bom.bomFormat, $bom.specVersion, @($bom.components).Count
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^CycloneDX 1\.5 \d+\s*$/) }
end

describe powershell_command(<<~POWERSHELL) do
  $inventory = Get-Content -Raw -Path '#{sbom_paths[:inventory]}' | ConvertFrom-Json
  if ($inventory.schema_version -ne 2) { exit 1 }
  if (@($inventory.components).Count -lt 1) { exit 1 }
  if ($inventory.metadata.generator -ne 'ronin_sbom') { exit 1 }
  if ($inventory.metadata.host_os -notmatch '(?i)(mswin|mingw|windows)') { exit 1 }
  if ($inventory.metadata.puppet_version -notmatch '^8\\.') { exit 1 }

  '{0} {1} {2}' -f $inventory.schema_version, $inventory.metadata.generator, @($inventory.components).Count
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^2 ronin_sbom \d+\s*$/) }
end

describe powershell_command(<<~POWERSHELL) do
  $markdown = Get-Content -Raw -Path '#{sbom_paths[:markdown]}'
  foreach ($needle in @('# Ronin Puppet SBOM', '## Summary', '## Components: windows-installed-program', '## Components: windows-driver')) {
    if (-not $markdown.Contains($needle)) { exit 1 }
  }
POWERSHELL
  its(:exit_status) { should eq 0 }
end
