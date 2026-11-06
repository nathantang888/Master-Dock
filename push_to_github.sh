#!/bin/bash
# Saves every change and uploads it to GitHub.
# Usage: ./push_to_github.sh            (uses a default message)
#        ./push_to_github.sh "message"  (your own message)
set -e
cd "$(dirname "$0")"

MESSAGE="${1:-Update Master Dock}"

git add -A
if git diff --cached --quiet; then
    echo "Nothing new to save. Pushing anything not uploaded yet..."
else
    git commit -m "$MESSAGE" \
        -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" \
        -m "Claude-Session: https://claude.ai/code/session_01RRUgbNrrTkFmo6N8zhDTVD"
fi
git push
echo "✅ Pushed to GitHub."
