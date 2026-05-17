#!/usr/bin/osascript

set appName to "Smart Screensaver Guard"
set scriptDir to POSIX path of (container of (path to me) as text)

repeat
    set userAction to button returned of (display dialog "Welcome to " & appName & " Setup" with title appName buttons {"Check Access", "Install", "Uninstall"} default button "Install" cancel button "Uninstall")
    
    if userAction is "Check Access" then
        -- Check for Accessibility access (required for some osascript functions and monitoring)
        display dialog "Please ensure Terminal/Script Editor has 'Accessibility' access in System Settings > Privacy & Security." with title "Access Check" buttons {"Open Settings", "Done"} default button "Done"
        if button returned of result is "Open Settings" then
            do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
        end if
        
    else if userAction is "Install" then
        try
            do shell script "chmod +x '" & scriptDir & "install.sh'"
            set installLog to do shell script "'" & scriptDir & "install.sh'"
            display dialog "Installation Successful!
            
" & installLog with title "Success" buttons {"OK"} default button "OK"
        on error errMsg
            display dialog "Installation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
        end try
        
    else if userAction is "Uninstall" then
        try
            do shell script "chmod +x '" & scriptDir & "uninstall.sh'"
            set uninstallLog to do shell script "'" & scriptDir & "uninstall.sh'"
            display dialog "Uninstallation Successful!
            
" & uninstallLog with title "Success" buttons {"OK"} default button "OK"
        on error errMsg
            display dialog "Uninstallation Failed: " & errMsg with title "Error" buttons {"OK"} default button "OK"
        end try
    end if
end repeat
