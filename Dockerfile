# escape=`
FROM mcr.microsoft.com/windows/servercore:ltsc2019
WORKDIR C:\ragnarok
COPY . .
ENTRYPOINT powershell
