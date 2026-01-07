#!/bin/bash

# Fast verification for batch processing
# Author: z4lthor <z4lthor@gmail.com>

quick_verify() {
    local file="$1"
    local errors=0
    
    # Basic checks
    [ ! -f "$file" ] && { echo "✗ $file: File not found"; return 1; }
    [ ! -r "$file" ] && { echo "✗ $file: Not readable"; return 1; }
    [ ! -s "$file" ] && { echo "✗ $file: Empty file"; return 1; }
    
    # Can ffprobe read it?
    if ! ffprobe -v error "$file" >/dev/null 2>&1; then
        echo "✗ $file: Cannot read format"
        return 1
    fi
    
    # Has duration?
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    if [ -z "$duration" ] || [ "$duration" = "N/A" ] || (( $(echo "$duration <= 0" | bc -l) )); then
        echo "✗ $file: Invalid duration"
        ((errors++))
    fi
    
    # Has video?
    local video_streams=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$file" | wc -l)
    if [ "$video_streams" -eq 0 ]; then
        echo "⚠ $file: No video streams"
        ((errors++))
    fi
    
    # Quick decode test (first 10 seconds only)
    if ! ffmpeg -v error -t 10 -i "$file" -f null - 2>/dev/null; then
        echo "✗ $file: Decoding errors in first 10 seconds"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        echo "✓ $file: OK"
        return 0
    else
        echo "⚠ $file: $errors issue(s) found"
        return 1
    fi
}

# Process all files
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1> [file2] [file3] ..."
    exit 1
fi

TOTAL=0
PASSED=0
FAILED=0

for file in "$@"; do
    ((TOTAL++))
    if quick_verify "$file"; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
done

echo ""
echo "=== SUMMARY ==="
echo "Total files: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ $FAILED -eq 0 ] && exit 0 || exit 1
