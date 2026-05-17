#!/bin/bash

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run the GUI using osascript
osascript <<EOF
activate
set appName to "Smart Screensaver Guard"
set scriptDir to "$DIR/"

set choices to {"🚀 Install Service", "🗑 Uninstall Service"}

repeat
    try
        set isRunning to do shell script "launchctl list | grep com.user.smartscreensaverguard || echo 'false'"
        if isRunning contains "false" then
            set statusMsg to "Status: 🔴 Stopped"
        else
            set statusMsg to "Status: 🟢 Running"
        end if
    on error
        set statusMsg to "Status: 🔴 Not Installed"
    end try

    set selected to choose from list choices with title appName with prompt statusMsg & "

One-Click Setup:" OK button name "Select" cancel button name "Exit"
    
    if selected is false then
        -- User clicked Exit
        exit repeat
    end if
    
    set userAction to item 1 of selected
    
    if userAction contains "Uninstall" then
        try
            do shell script "chmod +x '" & scriptDir & "uninstall.sh'"
            set uninstallLog to do shell script "'" & scriptDir & "uninstall.sh'"
            display dialog "Uninstallation Successful!
            
" & uninstallLog with title "Success" buttons {"OK"} default button "OK"
        on error errMsg
            display dialog "Uninstallation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
        end try
        
    else if userAction contains "Install" then
        try
            do shell script "chmod +x '" & scriptDir & "install.sh'"
            set installLog to do shell script "'" & scriptDir & "install.sh'"
            display dialog "Installation Successful!
            
" & installLog with title "Success" buttons {"OK"} default button "OK"
        on error errMsg
            display dialog "Installation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
        end try
    end if
end repeat
EOF
