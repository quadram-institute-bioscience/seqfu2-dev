#!/bin/bash
# Main test script for Seqfu2

set -e  # Exit on any error

# Set environment variables
SEQFU="./bin/seqfu"
TEST_DIR="./test"
DATA_DIR="./data"
TMP_DIR="$TEST_DIR/tmp"

# Create temporary directory
mkdir -p "$TMP_DIR"

# Export variables for submodule tests
export SEQFU
export DATA_DIR
export TMP_DIR

# Display test banner
echo "====================================="
echo "   SeqFu2 Test Suite                 "
echo "====================================="

# Check if the binary exists and is executable
if [ ! -x "$SEQFU" ]; then
    echo "ERROR: $SEQFU does not exist or is not executable."
    exit 1
fi

# Test 1: Check if the binary works
echo "Testing if SeqFu2 binary works..."
$SEQFU > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: $SEQFU failed to run."
    exit 1
fi
echo "✓ Binary test passed."

# Test 2: Check version format
echo "Testing 'seqfu version'..."
VERSION=$($SEQFU version)
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Version string '$VERSION' does not match semver format."
    exit 1
fi
echo "✓ Version test passed: $VERSION"

# Run each submodule test
echo -e "\nRunning submodule tests..."
SUBMODULES=("bases" "cat" "count" "deinterleave" "derep" "grep" "head" 
           "interleave" "lanes" "list" "metadata" "rc" "sort" "stats" 
           "tab" "tail" "view")

PASSED=0
FAILED=0
SKIPPED=0

for submodule in "${SUBMODULES[@]}"; do
    SUBMODULE_TEST="$TEST_DIR/test_${submodule}.sh"
    
    if [ -f "$SUBMODULE_TEST" ]; then
        echo -e "\n----- Testing '$submodule' -----"
        bash "$SUBMODULE_TEST"
        
        if [ $? -ne 0 ]; then
            echo "✗ Test for '$submodule' failed."
            ((FAILED++))
        else
            echo "✓ Test for '$submodule' passed."
            ((PASSED++))
        fi
    else
        echo "⚠ Test file for '$submodule' not found at $SUBMODULE_TEST."
        ((SKIPPED++))
    fi
done

# Display test summary
echo -e "\n====================================="
echo "Test Summary:"
echo "  Passed:  $PASSED"
echo "  Failed:  $FAILED"
echo "  Skipped: $SKIPPED"
echo "====================================="

if [ $FAILED -eq 0 ]; then
    echo "All tests completed successfully."
    exit 0
else
    echo "Some tests failed."
    exit 1
fi