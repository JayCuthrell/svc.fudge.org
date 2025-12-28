#!/bin/zsh

mkdir -p logos

# Initialize Stats Counters & Lists
COUNT_GOOGLE=0
COUNT_DDG=0
COUNT_MANUAL=0
COUNT_FAILED=0
FAILED_ITEMS=()
MANUAL_ITEMS=()

# -----------------------------------------------------------------------------
# 0. SETUP: Define Manual Fallbacks for Difficult Companies
# -----------------------------------------------------------------------------
typeset -A MANUAL_LOGOS
MANUAL_LOGOS=(
  [aac-clyde]="https://unavatar.io/twitter/AACClydeSpace"
  [helicity-space]="https://unavatar.io/twitter/HelicitySpace"
  [lonestar]="https://unavatar.io/twitter/Lonestar_Space"
  [optimum-tech]="https://unavatar.io/twitter/OpTechSpace"
  [skycorp]="https://unavatar.io/twitter/SkycorpInc"
  [transastra]="https://unavatar.io/twitter/TransAstra"
  [ula]="https://unavatar.io/twitter/ulalaunch"
  [xiomas]="https://unavatar.io/twitter/XiomasTech"
  [york-space]="https://unavatar.io/twitter/YorkSpaceSystem"
)

# -----------------------------------------------------------------------------
# 1. SETUP: Fingerprint Google's "No Logo Found" Globe
# -----------------------------------------------------------------------------
echo "🔍  Fingerprinting Google's default 'no-logo' icon..."
GENERIC_ICON="/tmp/google_generic_globe.png"
curl -L "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=http://this-domain-does-not-exist-12345.com&size=256" \
     --output "$GENERIC_ICON" --silent

echo "🚀  Starting download (Google -> DuckDuckGo -> Manual Fallback)..."

# Process data.yml
grep -E "homepage_url:|logo:" data.yml | sed 'N;s/\n/ /' | while read -r line; do
    URL=$(echo $line | awk -F': ' '{print $2}' | awk '{print $1}' | sed "s/['\"]//g")
    FILENAME=$(echo $line | awk -F': ' '{print $3}' | sed "s/['\"]//g")
    BASENAME=${FILENAME%.*}

    if [[ -z "$URL" || -z "$FILENAME" ]]; then continue; fi

    CLEAN_URL=$(echo $URL | sed 's/\/$//')
    TEMP_IMG="logos/${FILENAME}.tmp"
    FINAL_SVG="logos/${FILENAME}"

    echo "Processing: $BASENAME ($CLEAN_URL)"

    # --- ATTEMPT 1: Google Favicon Service ---
    curl -L -f "https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=${CLEAN_URL}&size=256" \
         --output "$TEMP_IMG" --silent

    IS_VALID="false"
    if [[ -s "$TEMP_IMG" ]]; then
        if cmp -s "$TEMP_IMG" "$GENERIC_ICON"; then
            IS_VALID="false"
        elif [[ $(file -b "$TEMP_IMG") == *"text"* || $(file -b "$TEMP_IMG") == *"JSON"* ]]; then
            IS_VALID="false"
        else
            IS_VALID="true"
            ((COUNT_GOOGLE++))
            echo "  🔹 Used Google"
        fi
    fi

    # --- ATTEMPT 2: DuckDuckGo (If Google Failed) ---
    if [[ "$IS_VALID" == "false" ]]; then
        curl -L -f "https://icons.duckduckgo.com/ip3/${CLEAN_URL}.ico" \
             --output "$TEMP_IMG" --silent
        
        if [[ -s "$TEMP_IMG" ]] && [[ $(file -b "$TEMP_IMG") != *"text"* ]]; then
             if command -v sips >/dev/null; then
                sips -s format png "$TEMP_IMG" --out "${TEMP_IMG}.png" >/dev/null 2>&1
                mv "${TEMP_IMG}.png" "$TEMP_IMG"
             fi
             IS_VALID="true"
             ((COUNT_DDG++))
             echo "  🔹 Used DuckDuckGo"
        fi
    fi

    # --- ATTEMPT 3: Manual Social Fallback (If both Failed) ---
    if [[ "$IS_VALID" != "true" ]]; then
        MANUAL_URL="${MANUAL_LOGOS[$BASENAME]}"
        
        if [[ -n "$MANUAL_URL" ]]; then
            echo "  ⚠️  Auto-fetch failed. Trying Manual Social URL: $MANUAL_URL"
            curl -L -f "$MANUAL_URL" --output "$TEMP_IMG" --silent
            
            if [[ -s "$TEMP_IMG" ]] && [[ $(file -b "$TEMP_IMG") != *"text"* && $(file -b "$TEMP_IMG") != *"JSON"* ]]; then
                IS_VALID="true"
                ((COUNT_MANUAL++))
                MANUAL_ITEMS+=("$BASENAME")
                echo "  ✅ Retrieved Social Logo"
            else
                echo "  ❌ Manual URL failed."
            fi
        fi
    fi

    # --- FINAL PROCESSING ---
    if [[ "$IS_VALID" == "true" ]]; then
        # Get MIME Type
        if [[ "$OSTYPE" == "darwin"* ]]; then
            MIME_TYPE=$(file -b --mime-type "$TEMP_IMG")
        else
            MIME_TYPE=$(file --mime-type -b "$TEMP_IMG")
        fi

        # Wrap if not already SVG
        if [[ "$MIME_TYPE" == "image/svg+xml" ]]; then
            mv "$TEMP_IMG" "$FINAL_SVG"
        else
            B64_DATA=$(base64 -i "$TEMP_IMG")
            cat <<EOF > "$FINAL_SVG"
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <image width="256" height="256" href="data:$MIME_TYPE;base64,$B64_DATA" />
</svg>
EOF
            rm "$TEMP_IMG"
        fi
    else
        echo "  ❌ SKIPPING: Could not find any valid logo."
        ((COUNT_FAILED++))
        FAILED_ITEMS+=("$BASENAME")
        rm -f "$TEMP_IMG"
    fi
done

# Cleanup
rm -f "$GENERIC_ICON"

# -----------------------------------------------------------------------------
# FINAL STATS REPORT
# -----------------------------------------------------------------------------
echo "\n========================================================"
echo "📊  LOGO DOWNLOAD STATS"
echo "========================================================"
echo "  🔹 Google (Preferred):     $COUNT_GOOGLE"
echo "  🔹 DuckDuckGo (Backup):    $COUNT_DDG"
echo "  ✅ Manual (Social):        $COUNT_MANUAL"
echo "  ❌ Failed / Incomplete:    $COUNT_FAILED"
echo "========================================================"

if [[ ${#MANUAL_ITEMS[@]} -gt 0 ]]; then
    echo "✅  MANUAL FALLBACK USED FOR:"
    for item in "${MANUAL_ITEMS[@]}"; do
        echo "   - $item"
    done
    echo "--------------------------------------------------------"
fi

if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
    echo "❌  THE FOLLOWING LOGOS COULD NOT BE FOUND:"
    for item in "${FAILED_ITEMS[@]}"; do
        echo "   - $item"
    done
    echo "   (Tip: Add these to the MANUAL_LOGOS list in the script)"
else
    echo "🎉  All logos retrieved successfully!"
fi
echo "========================================================"