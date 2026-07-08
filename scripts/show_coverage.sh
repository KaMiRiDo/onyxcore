#!/bin/bash

echo "🌟💫 Opening the test coverage⏳⏳⏳"
# Run the tests using 'script' to preserve ANSI colors and stream in real-time.
# -q: quiet (hides the "Script started/done" system messages)
# -e: returns the exit code of the Flutter test
# -c: the exact command to execute
genhtml coverage/lcov.info -o coverage/html && xdg-open coverage/html/index.html 

echo "✅ Coverage report is showing in your browser 🚀🚀🚀"
