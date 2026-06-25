#!/bin/bash
# ZidStore Tunnel - Build Script
# Encodes zidstoretunnel.sh into a self-extracting obfuscated script
# The output script runs exactly the same but source is not human-readable
#
# Usage: ./build.sh [--update-url https://raw.githubusercontent.com/.../zidstoretunnel]
#
# This will produce 'zidstoretunnel' - the encoded version to upload to GitHub.
# Users install/update with: curl -sL <raw-url>/zidstoretunnel | sudo bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INPUT_FILE="zidstoretunnel.sh"
OUTPUT_FILE="zidstoretunnel"
UPDATE_URL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update-url)
            UPDATE_URL="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         ZidStore Tunnel - Build & Obfuscate                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: $INPUT_FILE not found${NC}"
    exit 1
fi

# Read version
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")

echo -e "${CYAN}[1/4]${NC} Reading source script..."
SOURCE_SIZE=$(wc -c < "$INPUT_FILE")
echo -e "  Source size: ${SOURCE_SIZE} bytes"

echo -e "${CYAN}[2/4]${NC} Compressing with gzip + base64..."
COMPRESSED=$(gzip -c "$INPUT_FILE" | base64 -w 0)
COMPRESSED_SIZE=${#COMPRESSED}
echo -e "  Compressed size: ${COMPRESSED_SIZE} characters"

echo -e "${CYAN}[3/4]${NC} Generating multi-layer obfuscated loader..."

# Generate random variable names (UUID-based)
UUID_BIN="cat /proc/sys/kernel/random/uuid"
command -v uuidgen &>/dev/null && UUID_BIN="uuidgen"

RAND_D1=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D2=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D3=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_D4=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)
RAND_F1=$($UUID_BIN 2>/dev/null | tr -d '-' | head -c 12)

# Split the base64 data into chunks across an array
# This scatters the data and makes simple regex extraction fail
CHUNK_SIZE=3072
NUM_CHUNKS=$(( (COMPRESSED_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Build variable assignment block with random names
VAR_DECLS=""
for ((i=0; i<NUM_CHUNKS; i++)); do
    START=$((i * CHUNK_SIZE))
    CHUNK="${COMPRESSED:$START:$CHUNK_SIZE}"
    # Use hex index in variable name for obscurity
    HEX_I=$(printf '%x' "$i")
    VAR_DECLS+="__${RAND_D1}_${HEX_I}=\"${CHUNK}\"
"
done

# Build the array assembly block
ASSEMBLY_BLOCK=""
for ((i=0; i<NUM_CHUNKS; i++)); do
    HEX_I=$(printf '%x' "$i")
    ASSEMBLY_BLOCK+="\${__${RAND_D1}_${HEX_I}}"
done

cat > "$OUTPUT_FILE" <<'LOADER_SHELL'
#!/bin/bash
# ZidStore Tunnel - Self-Extracting Installer
# Auto-generated - do not modify
# Install: curl -sL <url>/zidstoretunnel | sudo bash
# Update:  curl -sL <url>/zidstoretunnel | sudo bash
LOADER_SHELL

cat >> "$OUTPUT_FILE" <<LOADER_BODY

__${RAND_F1}() {
${VAR_DECLS}
    printf '%s' "${ASSEMBLY_BLOCK}" | base64 -d | gzip -d
}

__${RAND_D2}=\$(__${RAND_F1})

if [ -z "\${__${RAND_D2}}" ]; then
    echo "[!] Error: Failed to decode installer payload" >&2
    exit 1
fi

# Execute decoded script, forwarding all arguments
bash -c "\${__${RAND_D2}}" -- "\$@"
LOADER_BODY

chmod +x "$OUTPUT_FILE"

echo -e "${CYAN}[4/4]${NC} Finalizing..."

OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE")

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Build complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "  Source:     ${YELLOW}${INPUT_FILE}${NC}  (${SOURCE_SIZE} bytes)"
echo -e "  Output:     ${YELLOW}${OUTPUT_FILE}${NC}  (${OUTPUT_SIZE} bytes)"
echo -e "  Version:    ${YELLOW}v${VERSION}${NC}"
echo -e "  Chunks:     ${YELLOW}${NUM_CHUNKS}${NC}"
echo -e "  Encoding:   ${YELLOW}gzip → base64 → split array${NC}"
echo ""
echo -e "  ${BLUE}Next steps:${NC}"
echo -e "    1. Upload ${CYAN}${OUTPUT_FILE}${NC} to GitHub (NOT ${INPUT_FILE})"
echo -e "    2. Users install with:"
echo -e "       ${GREEN}curl -sL https://raw.githubusercontent.com/zidnyzd/ScriptTunnel/main/${OUTPUT_FILE} | sudo bash${NC}"
echo ""
if [[ -n "$UPDATE_URL" ]]; then
    echo -e "  ${BLUE}Auto-update URL:${NC} ${CYAN}${UPDATE_URL}${NC}"
fi
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"