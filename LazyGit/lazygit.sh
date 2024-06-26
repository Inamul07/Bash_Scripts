repo=~/Desktop/scripts/
git -C $repo add ~/Desktop/scripts/
read -p "Enter Commit Message: " msg
git -C $repo commit -m "$msg"
git -C $repo push -u origin main
