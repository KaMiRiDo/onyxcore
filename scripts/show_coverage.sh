#!/bin/bash

echo "🌟💫 Opening the test coverage⏳⏳⏳"

genhtml coverage/lcov.info -o coverage/html && xdg-open coverage/html/index.html 

echo "✅ Coverage report is showing in your browser 🚀🚀🚀"
