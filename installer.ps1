param (
    #when using this flag, you must add MSBuild.exe to your path
    [Switch] $recompile = $false,
    [Switch] $rebuildServer = $false
)

$onError = {
    $server.kill();
    exit;
};

function Write-Log {
    param ($message)

    Write-Host "[$(Get-Date -UFormat "%Y-%m-%d %T")]:" -NoNewLine -BackgroundColor DarkMagenta;
    Write-Host " $message";
}

function Write-Bar { 
    param ($after, $before, $separator = '=')

    if ($before.Length -gt 0) {
        Write-Log $before;
    }
    Write-Host $($separator * 80);
    if ($after.Length -gt 0) {
        Write-Log $after;
    }
};

function Write-ProgressBar {
    param ($message, $percent)
    Write-Progress -Activity $message -Status "Progress -> " `
        -PercentComplete $percent;
}

# Define path aliases
$dir = Split-Path ($MyInvocation.MyCommand.Path)
$sqldir = "$dir/build/mariadb/bin";
$rathena = "$dir/rathena";
$build = "$dir/build";
$3rd = "$dir/3rdparty";
$translation = "$dir/ROenglishRE";

# Compile Server
if ($recompile -or $rebuildServer) {
    Set-Location $rathena;
    MSBuild.exe -m;
    Set-Location $dir;
}

# Copy compiled files to server folder
if (Test-Path "$build/server") {
    # remove previous instalation
    Remove-Item -Path "$build/server" -Recurse -Force;
}

New-Item -Path $build -Name "server" -ItemType "directory" | Out-Null;
New-Item -Path "$build/server" -Name "conf" -ItemType "directory" | Out-Null;
New-Item -Path "$build/server" -Name "db" -ItemType "directory" | Out-Null;
New-Item -Path "$build/server" -Name "npc" -ItemType "directory" | Out-Null;

Write-Bar "Starting server files copy...";
$i = 0;
Write-ProgressBar "Copying CORE files..." 0;
($items = Get-Content "$rathena/server-files") | ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path "$rathena/$_"  -Destination "$build/server";
    Write-ProgressBar "Copying CORE files..." $($i/($items.Length));
};
Write-Log "CORE files have been copied.";

$i = 0;
Write-ProgressBar "Copying CONF files..." 0;
($items = Get-ChildItem "$rathena/conf" -Recurse ) | 
ForEach-Object {
    $i = $i + 100;
    if ($_ -is [System.IO.DirectoryInfo]) {
        $relPath = $($_.Parent.FullName.Substring("$rathena".Length));
        New-Item -Path "$build/server/$relpath" -Name $_.Name -ItemType "directory" | 
            Out-Null;
    } else {
        $relPath = $($_.Directory.FullName.Substring("$rathena".Length));
        Copy-Item -Path $_.FullName -Destination "$build/server/$relPath";
        Write-ProgressBar "Copying CONF files..."  $($i/($items.Length));
    }
};
Write-Log "CONF files have been copied.";

$i = 0;
Write-ProgressBar "Copying DATABASE files..." 0;
($items = Get-ChildItem "$rathena/db" -Recurse ) |
ForEach-Object {
    $i = $i + 100;
    if ($_ -is [System.IO.DirectoryInfo]) {
        $relPath = $($_.Parent.FullName.Substring("$rathena".Length));
        New-Item -Path "$build/server/$relpath" -Name $_.Name -ItemType "directory" | 
            Out-Null;
    } else {
        $relPath = $($_.Directory.FullName.Substring("$rathena".Length));
        Copy-Item -Path $_.FullName -Destination "$build/server/$relPath";
        Write-ProgressBar "Copying DATABASE files..."  $($i/($items.Length));
    }
};
Write-Log "DATABASE files have been copied.";

$i = 0;
Write-ProgressBar "Copying NPC files..." 0;
($items = Get-ChildItem "$rathena/npc" -Recurse ) |
ForEach-Object {
    $i = $i + 100;
    if ($_ -is [System.IO.DirectoryInfo]) {
        $relPath = $($_.Parent.FullName.Substring("$rathena".Length));
        New-Item -Path "$build/server/$relpath" -Name $_.Name -ItemType "directory" | 
            Out-Null;
    } else {
        $relPath = $($_.Directory.FullName.Substring("$rathena".Length));
        Copy-Item -Path $_.FullName -Destination "$build/server/$relPath";
        Write-ProgressBar "Copying NPC files..."  $($i/($items.Length));
    }
};
Write-Log "NPC files have been copied.";
Write-Log "Server files have been copied successfully.";

if ($rebuildServer) {
    Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
    return;
}

# unzip the sql client
Write-Bar "Deploying database..."
Expand-Archive "$3rd/mariadb.zip" -Destination $build;
Remove-Item "$build/mysqld-helper.txt";
# Install db
Write-Log "Starting database instalation...";
try {
    & $sqldir/mysql_install_db.exe;
} catch {
    Write-Log "The instalation has failed.";
    exit;
};
Write-Log "The instalation has been completed";

# start server
Write-Bar "Initializing Server...";
$server = Start-Process -passThru -WindowStyle hidden "$sqldir/mysqld.exe" `
    -ArgumentList "--console";

# wait server isAlive
Do {
    $code = start-process -passThru "$sqldir/mysqladmin.exe" -ArgumentList "ping";
    $code.WaitForExit();
} Until ($code.ExitCode -eq 0);

# Apply sql files
Write-Log "Server has been initialized.";
Write-Log "Start user creation.";
try {
    Get-Content "$dir/scripts/create-user.sql" | & $sqldir/mysql.exe -u root;
} catch { 
    &$onError;
}
Write-Log "User has been created.";
Write-Log "Querying script files...";

$main_files = Get-ChildItem "$rathena/sql-files/*.sql";
$total = $main_files.Length + 1
Write-Log "$total found file(s) will be applied.";
$index = 1;
foreach ($file in $main_files) {
    try {
        Get-Content $file | & $sqldir/mysql.exe -u root ragnarok;
    } catch {
        &$onError;
    }
    Write-Log "($index of $total) - File ``$($file.Name)`` has been applied.";   
    $index++;
}

try {
    Get-Content "$dir/scripts/update-login.sql" | & $sqldir/mysql.exe -u root ragnarok;
} catch {
    &$onError;
};
Write-Log "($total of $total) - File ``update-login.sql`` has been applied.";

# close server connection
$server.kill();

# Extract client
Write-Bar "Starting client unpacking...";
try {
    Expand-Archive "$3rd/client/kRO_FullClient_20210406.zip" -Destination $build;
} catch {
    &$onError;
}
Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
Write-Log "Ragnarok Client has been unpacked.";

#[Console]::ReadKey() | Out-Null;

# Apply translation
Write-Bar "Initializing translation...";
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

# Expand ConEmu for handy console display
Write-Log "Unpacking 'ConEmu'...";
Expand-Archive "$3rd/ConEmu.zip" -DestinationPath "$build/console";
Write-Log "'ConEmu' has been unpacked.";

Copy-Item "$3rd/ConEmu.xml" -Destination "$build/console";
Write-Log "'ConEmu' default theme has been copied.";

Copy-Item "$dir/dev/run-server.bat" -Destination "$build" -Force;
$shortcut = (New-Object -comObject WScript.Shell).CreateShortcut("$build/Ragnarok.lnk");
$shortcut.TargetPath = "$build/client/Ragexe.exe";
$shortcut.WorkingDirectory = "$build/client";
$shortcut.Save();

Write-Bar "The instalation has been finished."
