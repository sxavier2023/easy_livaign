@echo off
cd /d "C:\Users\HOME\Desktop\easy_livaign"

call flutter clean
call flutter pub get
call flutter run -d web-server

pause