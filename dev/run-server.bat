@echo off
cd %~dp0
start server/console/ConEmu64.exe -cmdlist ^
    cmd /k "@echo off & cls & .\mariadb\bin\mysqld.exe --console" -cur_console:fn ^|^|^| ^
    cmd /k "@echo off & cls & cd server & CALL serv.bat char-server.exe Char-Server %*" -cur_console:s1TVn ^|^|^| ^
    cmd /k "@echo off & cls & cd server & CALL serv.bat login-server.exe Login-Server %*" -cur_console:s1THn ^|^|^| ^
    cmd /k "@echo off & cls & cd server & CALL serv.bat map-server.exe Map-Server %*" -cur_console:s2THn