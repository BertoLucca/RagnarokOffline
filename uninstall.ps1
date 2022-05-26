param ([Switch] $purgeDB = $false)

$dir = Split-Path ($MyInvocation.MyCommand.Path)
$build = "$dir/build";

$exclude = New-Object System.Collections.ArrayList;

if (-Not $purgeDB) {
    $exclude.Add("mariadb") | Out-Null;
}

if (Test-Path -Path $build) {
    Get-ChildItem $build -Exclude $exclude | Remove-Item -Recurse -Force;
}
