@echo off
set GOOS=linux
set GOARCH=amd64
set GOEXPERIMENT=jsonv2
set GOPROXY=https://goproxy.cn,direct
echo [xiaov2bXray] Building Linux amd64 release binary...
go build -v -tags "sing xray" -trimpath -ldflags "-s -w -buildid=" -o xiaov2bXray .
if %errorlevel% equ 0 (
    echo [xiaov2bXray] Build success: xiaov2bXray
) else (
    echo [xiaov2bXray] Build failed!
)
pause
