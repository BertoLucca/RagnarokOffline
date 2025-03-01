function Write-Log {
    param ($message);
    Write-Host "[$(Get-Date -UFormat "%Y-%m-%d %T")]" -NoNewLine -BackgroundColor DarkMagenta;
    Write-Host ": $message";
}

function Write-Bar {
    param ($after, $before, $separator = '=');
    if ($before.Length -gt 0) {
        Write-Log $before;
    }
    Write-Host $($separator * 80);
    if ($after.Length -gt 0) {
        Write-Log $after;
    }
};

function Write-ProgressBar {
    param ($message, $percent);
    Write-Progress -Activity $message -Status "Progress -> " -PercentComplete $percent;
}