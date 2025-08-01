#!/usr/bin/env sh

# Function to display usage information
usage() {
    echo "Usage: $0 --path <file_path> --hash <sha256_hash>"
    echo
    echo "Options:"
    echo "  --path    Path to the file to be hashed."
    echo "  --hash    The expected SHA256 hash."
    echo "  --help    Display this help message."
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --path)
            FILE_PATH="$2"
            shift
            ;;
        --hash)
            EXPECTED_HASH="$2"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Check if both file path and hash are provided
if [ -z "${FILE_PATH}" ] || [ -z "${EXPECTED_HASH}" ]; then
    echo "Error: Both --path and --hash arguments are required."
    usage
fi

# Check if the file exists
if [ ! -f "${FILE_PATH}" ]; then
    echo "Error: File not found at '${FILE_PATH}'"
    exit 1
fi

# Calculate the SHA256 hash of the file
CALCULATED_HASH=$(sha256sum "${FILE_PATH}" | awk '{print $1}')

# Compare the calculated hash with the expected hash
if [ "${CALCULATED_HASH}" == "${EXPECTED_HASH}" ]; then
    echo "✅ Success: Hashes match."
    echo "File: ${FILE_PATH}"
    echo "Hash: ${CALCULATED_HASH}"
else
    echo "❌ Error: Hashes do not match."
    echo "File:            ${FILE_PATH}"
    echo "Expected Hash:   ${EXPECTED_HASH}"
    echo "Calculated Hash: ${CALCULATED_HASH}"
    exit 1
fi

exit 0
