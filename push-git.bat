@echo off
cd /d "C:\Users\HOME\Desktop\easy_livaign"

git status
git add .
git commit -m "MVP stable: auth, RBAC, chat, tasks, house system working"
git push origin main

pause