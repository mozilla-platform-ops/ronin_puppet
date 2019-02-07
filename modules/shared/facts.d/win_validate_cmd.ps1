function Validate_CMD {
	param (
		[string] $title,
		[string] $test_command,
		[string] $match_result
	)
	process {
		$title_result = $title+"_validate"
		$result = Invoke-Expression $test_command

		if ($result -eq $match_result) {
			write-host "$title_result=true"
		} else {
			write-host "$title_result=false"
		}
	}
}

Validate_CMD -title "FsutilDisableLastAccess" -test_command "fsutil.exe behavior query disablelastaccess" -match_result "DisableLastAccess = 1"

Validate_CMD -title "FsutilDisable8Dot3" -test_command "fsutil.exe behavior query disable8dot3" -match_result "The registry state is: 1 (Disable 8dot3 name creation on all volumes)."
