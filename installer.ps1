$onError = {
    $server.kill();
    exit;
};

function Write-Bar { 
    param ($after, $before, $separator = '=')

    if ($before.Length -gt 0) {
        Write-Host $before;
    }
    Write-Host $($separator * 80);
    if ($after.Length -gt 0) {
        Write-Host $after;
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

# Default rAthena connection user
$username = "ragnarok";
$password = "ragnarok";

# Compile Server
Set-Location $rathena;
MSBuild.exe -m;
Set-Location $dir;

# Copy compiled files to server folder
if (-Not (Test-Path "$build/server")) {
    New-Item -Path $build -Name "server" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "conf" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "db" -ItemType "directory" | Out-Null;
    New-Item -Path "$build/server" -Name "npc" -ItemType "directory" | Out-Null;
}

Write-Bar -before "Starting server files copy...";
$i = 0;
Write-ProgressBar "Copying CORE files..." 0;
($items = Get-Content "$rathena/server-files") | ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path "$rathena/$_"  -Destination "$build/server";
    Write-ProgressBar "Copying CORE files..." $($i/($items.Length));
};
Write-Host "CORE files have been copied.";

$i = 0;
Write-ProgressBar "Copying CONF files..." 0;
($items = (Get-ChildItem "$rathena/conf" -Recurse -File).FullName ) | 
ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path $_ -Destination "$build/server/conf";
    Write-ProgressBar "Copying CONF files..."  $($i/($items.Length));
};
Write-Host "CONF files have been copied.";

$i = 0;
Write-ProgressBar "Copying DATABASE files..." 0;
($items = (Get-ChildItem "$rathena/db" -Recurse -File).FullName ) |
ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path $_ -Destination "$build/server/db";
    Write-ProgressBar "Copying DATABASE files..." $($i/($items.Length));
};
Write-Host "DATABASE files have been copied.";

$i = 0;
Write-ProgressBar "Copying NPC files..." 0;
($items = (Get-ChildItem "$rathena/npc" -Recurse -File).FullName ) |
ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path $_ -Destination "$build/server/npc";
    Write-ProgressBar "Copying NPC files..." $($i/($items.Length));
};
Write-Host "NPC files have been copied.";
Write-Bar "Server files have been copied successfully.";

# unzip the sql client
Expand-Archive "$3rd/mariadb.zip" -Destination './build';
# Install db
Write-Bar -before "Starting database instalation...";
try {
    & $sqldir/mysql_install_db.exe;
} catch {
    Write-Bar "The instalation has failed.";
    exit;
};
Write-Bar "The instalation has been completed";

# start server
$server = Start-Process -passThru -WindowStyle hidden "$sqldir/mysqld.exe" `
    -ArgumentList "--console";

# wait server isAlive
Do {
    $code = start-process -passThru "$sqldir/mysqladmin.exe" -ArgumentList "ping";
    $code.WaitForExit();
} Until ($code.ExitCode -eq 0);

# Apply sql files
try {
    (Get-Content "$dir/scripts/create-user.sql" -Raw) -f ($username, $password) |
        & $sqldir/mysql.exe -u root;
} catch { 
    &$onError;
}
Write-Host "User has been created.";

$main_files = Get-ChildItem "$rathena/sql-files/*.sql";
$total = $main_files.Length + 1
Write-Host "$total file(s) will be applied.";
$index = 1;
foreach ($file in $main_files) {
    try {
        Get-Content $file | & $sqldir/mysql.exe -u $username --password=$password ragnarok;
    } catch {
        &$onError;
    }
    Write-Host "($index of $total)" -NoNewLine -BackgroundColor DarkMagenta;
    Write-Host " - File ``$($file.Name)`` has been applied.";   
    $index++;
}

try {
    Get-Content "$dir/scripts/update-login.sql" | 
        & $sqldir/mysql.exe -u $username --password=$password ragnarok;
} catch {
    &$onError;
};
Write-Host "($total of $total)" -NoNewLine -BackgroundColor DarkMagenta;
Write-Host " - File ``update-login.sql`` has been applied.";

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
Write-Bar -before "Ragnarok Client has been unpacked.";

# Apply translation
$i = 0;
Write-ProgressBar "Copying translation files..." 0;
($items = (Get-ChildItem "$translation/Renewal" -Recurse -File).FullName ) | 
ForEach-Object {
    $i = $i + 100;
    Copy-Item -Path $_ -Destination "$build/client" -Recurse -Force;
    Write-ProgressBar "Copying translation files..." $($i/($items.Length));
}
Write-Host "Translation has been applied.";

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

# Write utility scripts
"`"mariadb/bin/mysqld.exe`" --console" | Out-File "$build/start_db.bat" -Encoding ASCII;
