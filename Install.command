#!/bin/bash
# Move to the directory where this script is located
cd "$(dirname "$0")"

# Ensure the installer is executable and run it
chmod +x install.sh
./install.sh

echo ""
echo "------------------------------------------------"
echo "Done! You can close this window now."
echo "Press any key to exit..."
read -n 1 -s
