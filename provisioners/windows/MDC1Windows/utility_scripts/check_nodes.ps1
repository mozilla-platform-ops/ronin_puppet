param(
	[switch]$single,
    [switch]$range,
	[switch]$pool,
	[string]$node,
	[string]$hw_class,
	[string]$start,
	[string]$end,
	[string]$pool_name,
	[string]$domain_suffix = "wintest2.releng.mdc1.mozilla.com",
	[string]$local_script = "C:\management_scripts\force_pxe_install.ps1",
	[string]$yaml_url = "https://raw.githubusercontent.com/mozilla-platform-ops/ronin_puppet/win11hardware/provisioners/windows/MDC1Windows/pools.yml"
)



$singlePresent = -not [string]::IsNullOrWhiteSpace($single)
$rangePresent = -not [string]::IsNullOrWhiteSpace($range)
$poolPresent = -not [string]::IsNullOrWhiteSpace($pool)

if (-not $single -and -not $range -and -not $pool) {
    #$choice = Read-Host "No parameters were provided. Enter '1' for single, '2' for range, '3' for pool, or 'q' to quit"
	$choice = Read-Host "Neither single nor range parameters were provided. Enter `n'1' - for single node `n'2' - for range of nodes `n'3' - for entire pool `n'q' - to quit `n"

    switch ($choice) {
        '1' {
			"Will need a range of nodes."
            $single = [bool]($single -ne $null)
        }
        '2' {
			Write-Host "Will need a range of nodes."
            $range = [bool]($range -ne $null)
        }
		'3' {
			Write-Host "Will need pool name."
			$pool = [bool]($single -ne $null)
		}

        'q' {
            Write-Host "Exiting script."
            exit
        }
        default {
            Write-Host "Invalid choice. Exiting script."
            exit
        }
    }
}


Write-Host "Pulling pool data from $yaml_url"
$YAML = Invoke-WebRequest -Uri $yaml_url | ConvertFrom-YAML

if ($single) {
    if (-not [string]::IsNullOrWhiteSpace($node)) {
        Write-Host "Single parameter is present. Node value is: $node"
    }
    else {
        Write-Host "Error: Single parameter requires a non-empty value."
		$node = Read-Host "Enter a value for 'node'"
		if ([string]::IsNullOrWhiteSpace($node)) {
        Write-Host "No value provided for 'node'. Exiting script."
        exit
		}
    }

	$node_name = $node + "." + $domain_suffix
	Write-Host Connecting to $node_name

	ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no  $node_name 2> $Null "write-host GOOD; start-sleep 5; exit"


	switch ($LASTEXITCODE) {
		0 { Write-Host "Successfully connecntion." }
		255 { Write-Host "SSH connecttion failed"}
		Default { Write-Host "Unexpected exit code encountered: $($process.ExitCode)" }
	}
}
if ($range) {
    if ((-not [string]::IsNullOrWhiteSpace($start)) -or ((-not [string]::IsNullOrWhiteSpace($end)))) {
        Write-Host "Single parameter is present. Node value is: $node"
    }
    else {
        Write-Host "Error: hw class parameter requires a non-empty value."
		$hw_class = Read-Host "Enter hw class'"
		if ([string]::IsNullOrWhiteSpace($hw_class)) {
			Write-Host "No value provided for 'hw class'. Exiting script."
			exit
		}
		if (!($YAML.validate.hw_class -contains $hw_class)) {
			Write-Host "Value provided for 'hw class' is not valid. Exiting script."
			exit
		}
        Write-Host "Error: Start parameter requires a non-empty value."
		$start = Read-Host "Enter starting node'"
		if ([string]::IsNullOrWhiteSpace($start)) {
			Write-Host "No value provided for 'start'. Exiting script."
			exit
		}
        Write-Host "Error: End parameter requires a non-empty value."
		$end = Read-Host "Enter ending node'"
		if ([string]::IsNullOrWhiteSpace($end)) {
			Write-Host "No value provided for 'end'. Exiting script."
			exit
		}

    }

	$startInt = [int]$start
	$endInt = [int]$end
	$counter = 0

	for ($i = $startInt; $i -le $endInt; $i++) {
		$formattedNumber = "{0:D3}" -f $i
		$node_name = $hw_class + "-" + $formattedNumber + "." + $domain_suffix
		write-host Connecting to $node_name .
		ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no  $node_name 2> $Null "write-host GOOD; start-sleep 5; exit"

		switch ($LASTEXITCODE) {
			0 { Write-Host "Successfully connecntion." }
			255 { Write-Host "SSH connecttion failed"}
			Default { Write-Host "Unexpected exit code encountered: $($process.ExitCode)" }
		}
	}

}

if ($pool) {

    if (-not [string]::IsNullOrWhiteSpace($pool_name)) {
        Write-Host "Single parameter is present. Pool value is: $pool_name"
    }
	else {
        Write-Host "Error: Pool name parameter requires a non-empty value."
		Write-Host "Pool values can be:"
		$pool_array = @()
		foreach ($worker_pool in $YAML.pools) {
			Write-Host $worker_pool.name
			Write-Host Description: $worker_pool.Description
			write-host

		}
		$pool_name = Read-Host "Enter pool name:'"
		if ([string]::IsNullOrWhiteSpace($pool_name)) {
        Write-Host "No value provided for 'pool name'. Exiting script."
        exit
		}
	}
	$pool_array = @()
	foreach ($worker_pool in $YAML.pools) {
		$pool_array += $worker_pool.name
	}
	if ($pool_array -notcontains $pool_name) {
		Write-Host "$pool_name is not valid pool name. Exiting script."
			exit
	}

	$nodes = ($YAML.pools | Where-Object { $_.name -eq $pool_name }).nodes
	#$nodes | ForEach-Object { Write-Output "- $_" }

	$failed_nodes = @()

	foreach ($node in $nodes) {
		$node_name = $node + "." + $worker_pool.domain_suffix
		Write-Host Connecting to $node_name
		ssh -o ConnectTimeout=5  -o StrictHostKeyChecking=no  $node_name 2> $Null "exit"

		switch ($LASTEXITCODE) {
		    0 { Write-Host "Successfully connecntion." }
			255 {
				Write-Host "SSH connecttion failed" -ForegroundColor Red
				$failed_nodes += $node_name
			}
			Default {
				Write-Host "Unexpected exit code encountered: $($process.ExitCode)" -ForegroundColor Red
				$failed_nodes += $node_name
			}
		}
	}
	Write-Host "Nodes with failed connections:"
		foreach ($node in $failed_nodes) {
		Write-Host "- $node"
	}
}
