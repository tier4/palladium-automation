#!/usr/bin/env python3
"""
XWDファイルをPNGに変換するスクリプト
"""
import sys
import subprocess
import os

def xwd_to_png(xwd_file, png_file):
    """XWDファイルをPNGに変換"""
    if not os.path.exists(xwd_file):
        print(f"Error: File not found: {xwd_file}")
        return False

    try:
        # xwdtopnm と pnmtopng を使用（netpbm）
        with open(xwd_file, 'rb') as xwd_in:
            # xwdtopnm がない場合のエラー処理
            try:
                pnm_proc = subprocess.Popen(['xwdtopnm'], stdin=xwd_in, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                pnm_data, pnm_err = pnm_proc.communicate()

                if pnm_proc.returncode != 0:
                    print(f"xwdtopnm failed: {pnm_err.decode()}")
                    return False

                # pnmtopng
                png_proc = subprocess.Popen(['pnmtopng'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                png_data, png_err = png_proc.communicate(input=pnm_data)

                if png_proc.returncode != 0:
                    print(f"pnmtopng failed: {png_err.decode()}")
                    return False

                # PNG保存
                with open(png_file, 'wb') as png_out:
                    png_out.write(png_data)

                print(f"Success: Converted {xwd_file} -> {png_file}")
                return True

            except FileNotFoundError:
                print("Error: netpbm tools (xwdtopnm, pnmtopng) not found")
                print("Try: sudo dnf install netpbm-progs")
                return False

    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: xwd_to_png.py <input.xwd> <output.png>")
        sys.exit(1)

    xwd_file = sys.argv[1]
    png_file = sys.argv[2]

    success = xwd_to_png(xwd_file, png_file)
    sys.exit(0 if success else 1)
