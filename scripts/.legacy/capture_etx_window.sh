#!/bin/bash
# ETX Xtermウィンドウをキャプチャするスクリプト

set -e

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ETXウィンドウ名
ETX_WINDOW_NAME="${ETX_WINDOW_NAME:-ga53ut01}"

# 出力ファイル（デフォルト）
OUTPUT_FILE="${1:-/tmp/etx_capture_$(date +%s).png}"

echo -e "${GREEN}[INFO]${NC} Capturing ETX window..."

# ウィンドウIDを取得
WINDOW_ID=$(xdotool search --name "$ETX_WINDOW_NAME" 2>/dev/null | head -n 1)

if [ -z "$WINDOW_ID" ]; then
    echo -e "${RED}[ERROR]${NC} ETX window not found: $ETX_WINDOW_NAME"
    echo -e "${GREEN}[INFO]${NC} Available windows:"
    wmctrl -l | grep -i "ga53\|etx" || wmctrl -l | head -5
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Found ETX window (ID: $WINDOW_ID)"

# xwdでキャプチャ
XWD_FILE="${OUTPUT_FILE%.png}.xwd"
echo -e "${GREEN}[INFO]${NC} Capturing to XWD format..."
xwd -id "$WINDOW_ID" -out "$XWD_FILE"

if [ ! -f "$XWD_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Failed to capture window"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Captured: $XWD_FILE"

# XWDをPNGに変換
if command -v xwdtopnm &> /dev/null && command -v pnmtopng &> /dev/null; then
    echo -e "${GREEN}[INFO]${NC} Converting to PNG (using netpbm)..."
    xwdtopnm < "$XWD_FILE" | pnmtopng > "$OUTPUT_FILE" 2>/dev/null
    if [ -f "$OUTPUT_FILE" ]; then
        rm -f "$XWD_FILE"
        echo -e "${GREEN}[SUCCESS]${NC} Saved: $OUTPUT_FILE"
    else
        echo -e "${RED}[ERROR]${NC} PNG conversion failed, keeping XWD"
    fi
elif command -v convert &> /dev/null; then
    echo -e "${GREEN}[INFO]${NC} Converting to PNG (using ImageMagick)..."
    convert "$XWD_FILE" "$OUTPUT_FILE"
    rm -f "$XWD_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} Saved: $OUTPUT_FILE"
else
    echo -e "${GREEN}[INFO]${NC} No conversion tools available, keeping XWD format"
    echo -e "${GREEN}[INFO]${NC} You can view with: xwud -in $XWD_FILE"
fi

echo -e "${GREEN}[INFO]${NC} Done!"
