# Define path aliases
$dir = Split-Path ($MyInvocation.MyCommand.Path)
$sqldir = "$dir/build/mariadb/bin";
$rathena = "$dir/rathena";
$build = "$dir/build";
$3rd = "$dir/3rdparty";

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
$items = (Get-Content "$rathena/server-files") | ForEach-Object { "$rathena/$_" };
Copy-Item -Path $items -Destination "$build/server" -Recurse;
Copy-Item -Path "$rathena/conf/*" -Destination "$build/server/conf" -Recurse;
Copy-Item -Path "$rathena/db/*" -Destination "$build/server/db" -Recurse;
Copy-Item -Path "$rathena/npc/*" -Destination "$build/server/npc" -Recurse;

# unzip the sql client
Expand-Archive "$3rd/mariadb.zip" -Destination './build';
# Install db
& $sqldir/mysql_install_db.exe;

# start server
$server = Start-Process -passThru -WindowStyle hidden "$sqldir/mysqld.exe" -ArgumentList "--console";

# wait server isAlive
Do {
    $code = start-process -passThru "$sqldir/mysqladmin.exe" -ArgumentList "ping";
    $code.WaitForExit();
} Until ($code.ExitCode -eq 0);

# Apply sql files
$instructions = (Get-Content "$dir/scripts/create-user.sql" -Raw) -f ($username, $password);
$instructions | & $sqldir/mysql.exe -u root;
Write-Host "User has been created.";

Write-Host "==================================================================="
$main_files = Get-ChildItem "$rathena/sql-files/*.sql";
Write-Host "$($main_files.Length) file(s) will be applied.";
$index = 1;
foreach ($file in $main_files) {
    Get-Content $file | & $sqldir/mysql.exe -u $username --password=$password ragnarok;
    Write-Host "($index of $($main_files.Length))" -NoNewLine -BackgroundColor DarkMagenta;
    Write-Host " - File ``$($file.Name)`` has been applied.";
    $index++;
}

Get-Content "$dir/scripts/update-login.sql" | & $sqldir/mysql.exe -u $username --password=$password ragnarok;

# close server connection
$server.kill();

# Extract client
Expand-Archive "$3rd/client/kRO_FullClient_20210406.zip" -Destination $build;
Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";

# Write utility scripts
"`"mariadb/bin/mysqld.exe`" --console" | Out-File "$build/start_db.bat" -Encoding ASCII;
