#!/bin/zsh

mkdir -p logos

echo "Starting download and Base64-embedding (Color-Safe)..."

# Process data.yml
grep -E "homepage_url:|logo:" data.yml | sed 'N;s/\n/ /' | while read -r line; do
    URL=$(echo $line | awk -F': ' '{print $2}' | awk '{print $1}' | sed "s/['\"]//g")
    FILENAME=$(echo $line | awk -F': ' '{print $3}' | sed "s/['\"]//g")

    if [[ -z "$URL" || -z "$FILENAME" ]]; then continue; fi

    CLEAN_URL=$(echo $URL | sed 's/\/$//')
    TEMP_PNG="logos/${FILENAME}.png"
    FINAL_SVG="logos/${FILENAME}"

    echo "Processing: $CLEAN_URL -> $FINAL_SVG"

    # 1. Download the high-res PNG favicon
    curl -L "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=${CLEAN_URL}&size=256" \
         --output "$TEMP_PNG" --silent

    if [[ -f "$TEMP_PNG" ]]; then
        # 2. Convert PNG to Base64 string
        B64_DATA=$(base64 -i "$TEMP_PNG")

        # 3. Create a wrapper SVG that embeds the PNG
        # This preserves every pixel and color exactly
        cat <<EOF > "$FINAL_SVG"
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <image width="256" height="256" href="data:image/png;base64,$B64_DATA" />
</svg>
EOF
        echo "  ✅ Embedded PNG into SVG (Colors Retained)"
        rm "$TEMP_PNG"
    else
        echo "  ❌ Failed download for $URL"
    fi
done

echo "\nDone! Your logos are now color-accurate SVGs."