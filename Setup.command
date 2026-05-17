#!/bin/bash

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run the GUI using osascript with the directory passed in
osascript <<EOF
activate
set appName to "Smart Screensaver Guard"
set scriptDir to "$DIR/"

-- Main Wizard Loop
repeat
    try
        -- Step 1: Access & Entry
        set step1 to button returned of (display dialog "Welcome to " & appName & " Setup.
        
Please ensure you have granted Accessibility access before installing." with title appName buttons {"Exit", "Check Access", "Next >"} default button "Next >" cancel button "Exit")
        
        if step1 is "Check Access" then
            display dialog "Please ensure Terminal/Script Editor has 'Accessibility' access in System Settings > Privacy & Security." with title "Access Check" buttons {"Open Settings", "Done"} default button "Done"
            if button returned of result is "Open Settings" then
                do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
            end if
            
        else if step1 is "Next >" then
            -- Step 2: Install & Uninstall
            set step2 to button returned of (display dialog "Ready to manage the background service?" with title appName buttons {"< Back", "Uninstall", "Install"} default button "Install" cancel button "< Back")
            
            if step2 is "Install" then
                try
                    do shell script "chmod +x '" & scriptDir & "install.sh'"
                    set installLog to do shell script "'" & scriptDir & "install.sh'"
                    display dialog "Installation Successful!
                    
" & installLog with title "Success" buttons {"OK"} default button "OK"
                on error errMsg
                    display dialog "Installation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
                end try
                
            else if step2 is "Uninstall" then
                try
                    do shell script "chmod +x '" & scriptDir & "uninstall.sh'"
                    set uninstallLog to do shell script "'" & scriptDir & "uninstall.sh'"
                    display dialog "Uninstallation Successful!
                    
" & uninstallLog with title "Success" buttons {"OK"} default button "OK"
                on error errMsg
                    display dialog "Uninstallation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
                end try
            end if
        end if
        
    on error number -128
        -- User clicked 'Exit' (Cancel button) or closed window
        exit repeat
    end try
end repeat
EOF
