#!/bin/bash

LOG_FILE="scripts/logs/test_output.txt"

mkdir -p scripts/logs

# Clear previous log
: > "$LOG_FILE"

if [ -z "$1" ]; then
    echo "🚀 Starting entire Flutter test suite with coverage..."
    TEST_COMMAND="flutter test --coverage --reporter expanded --concurrency=1 --no-color"
else
    echo "🚀 Starting Flutter tests for $1 with coverage..."
    TEST_COMMAND="flutter test --coverage --reporter expanded --concurrency=1 --no-color \"$1\""
fi

echo "📂 Output will be streamed here and saved to $LOG_FILE"
echo "---------------------------------------------------"

script -q -e -c "$TEST_COMMAND" "$LOG_FILE"

TEST_EXIT_CODE=$?

echo "---------------------------------------------------"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed! Coverage report generated in coverage/lcov.info"
else
    echo "❌ Some tests failed. Review $LOG_FILE."
fi

exit $TEST_EXIT_CODE