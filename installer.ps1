param (
    [switch] $RebuildServer,
    [switch] $RecompileEmulator
)

function Test-MissingPath {
    param ([string] $Path, [string] $Message, [switch] $NoExit)
    if (-not (Test-Path -Path $Path)) {
        Write-Host $message -ForegroundColor Red;
        exit 1;
    };
}

# Define path aliases
$dir = Split-Path ($MyInvocation.MyCommand.Path)
$sources = "$dir/scripts";
$sqldir = "$dir/build/mariadb/bin";
$rathena = "$dir/rathena";
$build = "$dir/build";
$3rd = "$dir/3rdparty";
$translation = "$dir/ROenglishRE";

$startTime = Get-Date;

Test-MissingPath -Path $sources -Message "Installation scripts not found. Exiting.";

if ((. "$sources/installer/validate-paths") -ne 0) { exit };

. "$sources/installer/logging.ps1";

if (-not (Test-Path -Path $build)) {
    New-Item -ItemType Directory -Path $dir -Name "build" | Out-Null;
}

. "$sources/installer/client.ps1";
. "$sources/installer/emulator.ps1";
. "$sources/installer/database.ps1";

Write-Bar "The instalation has been finished."
$runTime = New-TimeSpan -Start $startTime -End (Get-Date);
Write-Host ("Total elapsed time was: {0}h, {1}min and {2}s." -f 
    $RunTime.Hours, $RunTime.Minutes, $RunTime.Seconds);
