#!/bin/bash

# Define the log file name
LOG_FILE="scripts/logs/test_output.txt"

# Create output folder 
mkdir -p scripts/logs

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "🚀 Starting entire Flutter test suite with coverage..."
    TEST_COMMAND="flutter test --coverage"
else
    echo "🚀 Starting Flutter tests for $1 with coverage..."
    TEST_COMMAND="flutter test --coverage $1"
fi

echo "📂 Output will be streamed here and saved to $LOG_FILE with colors intact."
echo "---------------------------------------------------"

# Run the tests using 'script' to preserve ANSI colors and stream in real-time.
# -q: quiet (hides the "Script started/done" system messages)
# -e: returns the exit code of the Flutter test
# -c: the exact command to execute
script -q -e -c "$TEST_COMMAND" "$LOG_FILE"

# Capture the exit code from the script command
TEST_EXIT_CODE=$?

echo "---------------------------------------------------"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed! Coverage report generated in coverage/lcov.info"
else
    echo "❌ Some tests failed. Open $LOG_FILE in VS Code (with your ANSI extension) to review the colored stack traces."
fi