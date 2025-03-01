$serverExists = Test-Path "$build/server";

if ($serverExists -and -not ($RecompileEmulator -or $RebuildServer)) {
    Write-Bar "Server instalation already found. Skipping 'Server configuration' step.";
} else {
    # Cleanup
    Remove-Item -Path "$build/server" -Force -Recurse -Verbose;

    # Create destination folders
    Write-Bar "Initializing 'Server configuration' step.";
    New-Item -Path $build -Name "server" -ItemType "directory" | Out-Null;

    if ($RecompileEmulator -or
        -not (Test-Path -Path "$rathena/build") -or
        (($server_items = Get-ChildItem -Path "$rathena/build").Count -eq 0)
    ) {
        . "$rathena/project-builder.ps1";
        $server_items = Get-ChildItem -Path "$rathena/build"
    }

    $i = 0;
    Write-Log "Starting server files copy.";
    Write-ProgressBar "Copying server files..." 0;

    $server_items | ForEach-Object {
        $i = $i + 100;
        Copy-Item -Path $_.FullName -Destination "$build/server" -Recurse -Container;
        Write-ProgressBar "Copying server files..." $($i/($server_items.Length));
    }
    Write-Log "Server files have been copied successfully.";

    # Expand ConEmu for handy console display
    Write-Log "Unpacking 'ConEmu'.";
    Expand-Archive "$3rd/ConEmu.zip" -DestinationPath "$build/server/console";
    Write-Log "'ConEmu' has been unpacked.";
    Copy-Item "$3rd/ConEmu.xml" -Destination "$build/server/console";
    Write-Log "'ConEmu' default theme has been copied.";

    # Copy Server runner
    if ($RebuildServer) {
        Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
    }

    # Copy misc files
    Copy-Item "$dir/scripts/hta" -Destination "$build" -Force -Recurse;
}