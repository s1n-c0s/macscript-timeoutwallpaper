#!/bin/bash

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run the GUI using osascript
osascript <<EOF
activate
set appName to "Smart Screensaver Guard"
set scriptDir to "$DIR/"

set choices to {"🔍 Check Status", "🛠 Check Access (Permissions)", "🚀 Install Service", "🗑 Uninstall Service"}

repeat
    set selected to choose from list choices with title appName with prompt "One-Click Setup:" OK button name "Select" cancel button name "Exit"
    
    if selected is false then
        -- User clicked Exit
        exit repeat
    end if
    
    set userAction to item 1 of selected
    
    if userAction contains "Check Status" then
        try
            set isRunning to do shell script "launchctl list | grep com.user.smartscreensaverguard || echo 'false'"
            if isRunning contains "false" then
                display dialog "Status: 🔴 Stopped
                
The background service is NOT running." with title "Service Status" buttons {"OK"} default button "OK"
            else
                display dialog "Status: 🟢 Running
                
The background service is active and monitoring." with title "Service Status" buttons {"OK"} default button "OK"
            end if
        on error
            display dialog "Status: 🔴 Not Installed" with title "Service Status" buttons {"OK"} default button "OK"
        end try
        
    else if userAction contains "Check Access" then
        display dialog "Please ensure Terminal/Script Editor has 'Accessibility' access in System Settings > Privacy & Security." with title "Access Check" buttons {"Open Settings", "Done"} default button "Done"
        if button returned of result is "Open Settings" then
            do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
        end if
        
    else if userAction contains "Uninstall" then
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
