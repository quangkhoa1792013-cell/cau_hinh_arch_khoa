import sys
import os
from PIL import Image

def convert_to_png(input_path):
    if not os.path.exists(input_path):
        print(f"❌ File không tồn tại: {input_path}")
        return

    # Lấy tên file cũ và thay đuôi thành .png
    base, _ = os.path.splitext(input_path)
    output_path = f"{base}.png"

    try:
        with Image.open(input_path) as img:
            # Chuyển đổi sang hệ màu RGBA trước khi lưu để giữ độ trong suốt (nếu có)
            if img.mode in ("CMYK", "P"):
                img = img.convert("RGBA")
            img.save(output_path, "PNG")
            print(f"✅ Đã chuyển đổi thành công: {output_path}")
    except Exception as e:
        print(f"❌ Lỗi khi chuyển đổi file {input_path}: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Cách dùng: python topng.py <đường_dẫn_đến_ảnh>")
    else:
        convert_to_png(sys.argv[1])
