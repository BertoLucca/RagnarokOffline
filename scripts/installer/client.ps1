if (Test-Path "$build/client") {
    Write-Bar "Client destination already exists, skipping the 'Client setup' step.";
} else {
    Write-Bar "Starting 'Client setup'.";
    Expand-Archive "$3rd/client/kRO_FullClient_20210406.zip" -Destination $build;
    Copy-Item -Path "$build/client/msvcr110.dll" -Destination "$build/server";
    Write-Log "Ragnarok Client has been unpacked.";
    
    # Add OpenSetup
    Write-Log "Adding 'OpenSetup'.";
    Expand-Archive "$3rd/OpenSetup.zip" -Destination "$build/client";
    Write-Log "Added 'OpenSetup'.";
    
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
    $shortcut.TargetPath = "$build/hta/main.hta";
    $shortcut.WorkingDirectory = "$build/hta";
    $shortcut.IconLocation = "$build/client/ragnarok.ico";
    $shortcut.Save();
    
    # Misc
    Rename-Item -Path "$build/client/opensetup.exe" -NewName "setup.exe";
}