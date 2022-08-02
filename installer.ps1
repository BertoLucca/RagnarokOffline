param ([Switch] $rebuildServer = $false);
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
function Copy-ServerFiles {
    param ($src, $message, $dest);
    $i = 0;
    Write-ProgressBar $message 0;
    ($items = Get-ChildItem "$rathena/$src" -Recurse ) | ForEach-Object {
        $i = $i + 100;
        if ($_ -is [System.IO.DirectoryInfo]) {
            $relPath = $($_.Parent.FullName.Substring("$rathena".Length));
            New-Item -Path "$build/server/$relpath" -Name $_.Name -ItemType "directory" | Out-Null; 
        } else {
            $relPath = $(If($null -eq $dest) {$_.Directory.FullName.Substring("$rathena".Length)});
            Copy-Item -Path $_.FullName -Destination "$build/server/$relPath";
        }
        Write-ProgressBar $message  $($i/($items.Length));
    };
}

################################################################################
############################### Script Start ###################################
################################################################################

$startTime = Get-Date;
# Define path aliases
$dir = Split-Path ($MyInvocation.MyCommand.Path)
$sqldir = "$dir/build/mariadb/bin";
$rathena = "$dir/rathena";
$build = "$dir/build";
$3rd = "$dir/3rdparty";
$translation = "$dir/ROenglishRE";

# Copy compiled files to server folder
if ($rebuildServer -and (Test-Path "$build/server")) {
    Remove-Item "$build/server" -Recurse -Force
}
if (Test-Path "$build/server") {
    Write-Bar "Server instalation already found. Skipping 'Server configuration' step.";
} else {
    # Create destination folders
    Write-Bar "Initializing 'Server configuration' step.";
    New-Item -Path $build -Name "server" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "conf" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "db" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "npc" -ItemType "directory" | Out-Null;
    Write-Log "Starting server files copy.";
    Copy-ServerFiles "build" "Copying CORE files." '';
    Write-Log "CORE files have been copied.";
    Copy-ServerFiles "conf" "Copying CONF files.";
    Write-Log "CONF files have been copied.";
    Copy-ServerFiles "db" "Copying DATABASE files.";
    Write-Log "DATABASE files have been copied.";
    Copy-ServerFiles "npc" "Copying NPC files.";
    Write-Log "NPC files have been copied.";
    Write-Log "Server files have been copied successfully.";
    # Expand ConEmu for handy console display
    Write-Log "Unpacking 'ConEmu'.";
    Expand-Archive "$3rd/ConEmu.zip" -DestinationPath "$build/server/console";
    Write-Log "'ConEmu' has been unpacked.";
    Copy-Item "$3rd/ConEmu.xml" -Destination "$build/server/console";
    Write-Log "'ConEmu' default theme has been copied.";
    # Copy Server runner
    Copy-Item "$dir/dev/run-server.bat" -Destination "$build" -Force;
    if ($rebuildServer) {
        Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
        exit;
    }
}

if (Test-Path "$build/mariadb") {
    Write-Bar "Database installation already found. Skipping the 'Database deployment' step.";
} else {
    # unzip the sql client
    Write-Bar "Stating 'Database deployment'."
    Expand-Archive "$3rd/mariadb.zip" -Destination $build;
    Remove-Item "$build/mysqld-helper.txt";
    # Install db
    Write-Log "Starting database instalation.";
    try {
        & $sqldir/mysql_install_db.exe;
    } catch {
        Write-Log "The instalation has failed.";
        exit;
    };
    Write-Log "The instalation has been completed";
    # start server
    Write-Log "Initializing Server.";
    $server = Start-Process -passThru -WindowStyle hidden "$sqldir/mysqld.exe" -ArgumentList "--console";
    # wait server isAlive
    Do {
        $code = start-process -passThru "$sqldir/mysqladmin.exe" -ArgumentList "ping";
        $code.WaitForExit();
    } Until ($code.ExitCode -eq 0);
    # Apply sql files
    Write-Log "Server has been initialized.";
    Write-Log "Start user creation.";
    Get-Content "$dir/scripts/create-user.sql" | & $sqldir/mysql.exe -u root;
    Write-Log "User has been created.";
    Write-Log "Querying script files.";
    $main_files = Get-ChildItem "$rathena/sql-files/*.sql";
    $total = $main_files.Length + 1;
    Write-Log "$total found file(s) will be applied.";
    $index = 1;
    foreach ($file in $main_files) {
        Get-Content $file | & $sqldir/mysql.exe -u root ragnarok;
        Write-Log "($index of $total) - File ``$($file.Name)`` has been applied.";   
        $index++;
    }
    Get-Content "$dir/scripts/update-login.sql" | & $sqldir/mysql.exe -u root ragnarok;
    Write-Log "($total of $total) - File ``update-login.sql`` has been applied.";
    # close server connection
    $server.kill();
}

# Extract client
if (Test-Path "$build/client") {
    Write-Bar "Client destination already exists, skipping the 'Client setup' step.";
} else {
    Write-Bar "Starting 'Client setup'.";
    Expand-Archive "$3rd/client/kRO_FullClient_20210406.zip" -Destination $build;
    Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
    Write-Log "Ragnarok Client has been unpacked.";
    # Apply translation
    Write-Log "Applying translation.";
    $i = 0;
    Write-ProgressBar "Copying translation files..." 0;
    ($items = Get-ChildItem "$translation/Renewal" -Recurse ) | ForEach-Object {
        $i = $i + 100;
        if ($_ -is [System.IO.DirectoryInfo]) {
            $relPath = $($_.Parent.FullName.Substring("$translation/Renewal".Length));
            if (Test-Path "$build/client/$relpath/$($_.Name)") { return; }
            New-Item -Path "$build/client/$relpath" -Name $_.Name -ItemType "directory" | 
                Out-Null;
        } else {
            $relPath = $($_.Directory.FullName.Substring("$translation/Renewal".Length));
            Copy-Item -Path $_.FullName -Destination "$build/client/$relPath" -Recurse -Force;
            Write-ProgressBar "Copying translation files..."  $($i/($items.Length));
        }
    }
    Write-Log "Translation has been applied.";
    # Remove unnecessary files
    $items = Get-Content "$3rd/client/cleanup" |
        ForEach-Object { "$build/client/$_" } |
            Where-Object { Test-Path $_ };
    $i = 0;
    Write-ProgressBar "Cleanup..." 0;
    $items | ForEach-Object {
        $i = $i + 100;
        Remove-Item $_ -Recurse -Force;
        Write-ProgressBar "Cleanup..." $($i/($items.Length));
    }
    # Copy pre-patched exe and clientinfo
    Copy-Item "$dir/dev/Ragexe.exe" -Destination "$build/client" -Force;
    Copy-Item "$3rd/client/clientinfo.xml" -Destination "$build/client/data" -Recurse -Force;
    $shortcut = (New-Object -comObject WScript.Shell).CreateShortcut("$build/Ragnarok.lnk");
    $shortcut.TargetPath = "$build/client/Ragexe.exe";
    $shortcut.WorkingDirectory = "$build/client";
    $shortcut.Save();
}

Write-Bar "The instalation has been finished."
$runTime = New-TimeSpan $startTime -End (Get-Date);
Write-Host ("Total elapsed time was: {0}h, {1}min and {2}s." -f 
    $RunTime.Hours, $RunTime.Minutes, $RunTime.Seconds);
