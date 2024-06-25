git -C ~/Desktop/scripts/ add ~/Desktop/scripts/
read -p "Enter Commit Message: " msg
git -C ~/Desktop/scripts/ commit -m "$msg"
git -C ~/Desktop/scripts/ push -u origin main
