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

# close server connection
$server.kill();