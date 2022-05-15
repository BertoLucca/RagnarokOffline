if (Test-Path -Path './build') {
    Remove-Item './build/*' -Recurse -Force -Confirm:$false
}