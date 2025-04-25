# Script to push only essential files without large binaries

Write-Host "Creating a new branch with only essential files..." -ForegroundColor Yellow

# Create a new orphan branch (no history)
git checkout --orphan lightweight-main

# Add all files except large binaries
git add --all
git reset -- AzureCLI.msi frontend.zip tools/AzureCLI.msi

# Commit the changes
git commit -m "Add all essential files without large binaries"

# Force push the new branch
Write-Host "Pushing lightweight branch to GitHub..." -ForegroundColor Yellow
git push -f origin lightweight-main

Write-Host "`nInstructions for GitHub:" -ForegroundColor Cyan
Write-Host "1. Go to your GitHub repository" -ForegroundColor White
Write-Host "2. Set 'lightweight-main' as the default branch" -ForegroundColor White
Write-Host "3. Delete the 'main' branch that contains the large files" -ForegroundColor White

Write-Host "`nTo continue working locally:" -ForegroundColor Cyan
Write-Host "1. Delete the local 'main' branch: git branch -D main" -ForegroundColor White
Write-Host "2. Rename 'lightweight-main' to 'main': git branch -m lightweight-main main" -ForegroundColor White