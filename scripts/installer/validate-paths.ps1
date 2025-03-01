Test-MissingPath -Path $rathena -Message "Missing server emulator source data. Exiting.";
Test-MissingPath -Path $translation -Message "Missing translation source data. Exiting.";
Test-MissingPath -Path $3rd -Message "Missing 3rd party programs. Exiting.";

@(
    ,"$sources/installer/logging.ps1"
    ,"$sources/installer/emulator.ps1"
    ,"$sources/installer/database.ps1"
    ,"$sources/installer/client.ps1"
    ,"$rathena/project-builder.ps1"
) | ForEach-Object {
    Test-MissingPath -Path $_ -Message "Missing configuration file ``$($_.Replace("$dir/", ''))``. Exiting."
}
return 0;