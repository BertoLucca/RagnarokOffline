# unzip the sql client
Expand-Archive "./3rdparty/mariadb.zip" -Destination './build';

# Default rAthena connection user
$username = "ragnarok";
$password = "password";

# ==============================================================================

$sqldir = "build/mariadb/bin";
$rathena = "rathena/sql-files";

# Install db
& ./$sqldir/mysql_install_db.exe;

# start server
$server = Start-Process -passThru -WindowStyle hidden "./$sqldir/mysqld.exe" -ArgumentList "--console";

# wait server isAlive
Do {
    $code = start-process -passThru "./build/mariadb/bin/mysqladmin.exe" -ArgumentList "ping";
    $code.WaitForExit();
} Until ($code.ExitCode -eq 0);

# Apply sql files
$instructions = (Get-Content "./scripts/create-user.sql" -Raw) -f ($username, $password);
$instructions | & ./$sqldir/mysql.exe -u root;
Write-Host "User has been created.";

Get-Content "./$rathena/main.sql" | & ./$sqldir/mysql.exe -u $username --password=$password rAthena;
Write-Host "Main sql has been applied.";

Get-Content "./$rathena/logs.sql" | & ./$sqldir/mysql.exe -u $username --password=$password rAthena_log;
Write-Host "Log sql has been applied.";

Write-Host "==================================================================="
$exclude = @("*_re*", "main.sql", "logs.sql");
$main_files = Get-ChildItem "./$rathena/*.sql" -Exclude $exclude;
Write-Host "$($main_files.Length) file(s) will be applied.";
$index = 1;
foreach ($file in $main_files) {
    Get-Content $file | & ./$sqldir/mysql.exe -u $username --password=$password rAthena;
    Write-Host "($index of $($main_files.Length))" -NoNewLine -BackgroundColor DarkMagenta
    Write-Host " - File ``$($file.Name)`` has been applied."
    $index++;
}

$upgrade_files = Get-ChildItem "./$rathena/upgrades/*.sql";
if ($upgrade_files.Length -gt 0) {
    Write-Host "$($upgrade_files.Length) upgrade file(s) will be applied.";
}
$index = 1;
foreach ($file in $upgrade_files) {
    if ($file.Name -like "*_logs.sql") {
        $db = "rAthena_log";
    } else {
        $db = "rAthena";
    }
    Get-Content $file | & ./$sqldir/mysql.exe -u $username --password=$password -f -D $db;
    Write-Host "($index of $($upgrade_files.Length))" -NoNewLine -BackgroundColor DarkMagenta
    Write-Host " - File ``$($file.Name)`` has been applied."
    $index++;
}

# close server connection
$server.kill();