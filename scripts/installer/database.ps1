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
    $main_files = @("main", "logs", "item_db", "item_db2")
    $data_files = Get-ChildItem "$rathena/sql-files/*.sql" -Exclude *_re* |
        Where-Object { $_.BaseName -notin $main_files };
    $total = $data_files.Length + $main_files.Length;
    Write-Log "$total found file(s) will be applied.";
    $index = 1;
    foreach ($file in $main_files) {
        Get-Content "$rathena/sql-files/$file.sql" | & $sqldir/mysql.exe -u root ragnarok;
        Write-Log "($index of $total) - File ``$($file)`` has been applied.";   
        $index++;
    }    
    foreach ($file in $data_files) {
        Get-Content $file | & $sqldir/mysql.exe -u root ragnarok;
        Write-Log "($index of $total) - File ``$($file.BaseName)`` has been applied.";   
        $index++;
    }
    Get-Content "$dir/scripts/update-login.sql" | & $sqldir/mysql.exe -u root ragnarok;
    Write-Log "($total of $total) - File ``update-login.sql`` has been applied.";
    
    # close server connection
    $server.kill();
}