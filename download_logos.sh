#!/bin/zsh

# Ensure you are in the svc directory
# Usage: ./download_logos.sh

# 1. Create logos directory if it doesn't exist
mkdir -p logos

# 2. Extract homepage URLs and their corresponding logo filenames from data.yml
# This uses grep and sed for basic parsing. 
# It looks for lines containing 'homepage_url:' and 'logo:'
# and pairs them together.
grep -E "homepage_url:|logo:" data.yml | sed 'N;s/\n/ /' | while read -r line; do
    # Extract the URL and filename
    URL=$(echo $line | awk -F': ' '{print $2}' | awk '{print $1}')
    FILENAME=$(echo $line | awk -F': ' '{print $3}')

    # Skip if either value is empty
    if [[ -z "$URL" || -z "$FILENAME" ]]; then
        continue
    fi

    echo "Processing $URL -> logos/$FILENAME..."

    # 3. Download using the high-res favicon utility
    # We remove trailing slashes from the URL and encode it for the query
    CLEAN_URL=$(echo $URL | sed 's/\/$//')
    
    curl -L "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=${CLEAN_URL}&size=256" \
         --output "logos/$FILENAME" \
         --silent

    if [[ -f "logos/$FILENAME" ]]; then
        echo "✅ Successfully downloaded $FILENAME"
    else
        echo "❌ Failed to download $FILENAME"
    fi
done

echo "\nDone! Check your 'logos' directory."
