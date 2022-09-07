@echo off
cd %~dp0
..\mariadb\bin\mysqlcheck.exe -u root --auto-repair --check --all-databases
pause