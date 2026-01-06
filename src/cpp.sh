#!/bin/bash

# 1. Xác định đường dẫn file snippet
# Thử đường dẫn cho bản VS Code chính thức
SNIPPET_DIR="$HOME/.config/Code/User/snippets"

# Nếu không thấy, thử đường dẫn cho bản Code - OSS (phổ biến trên Arch)
if [ ! -d "$SNIPPET_DIR" ]; then
    SNIPPET_DIR="$HOME/.config/Code - OSS/User/snippets"
fi

# Tạo thư mục nếu chưa tồn tại
mkdir -p "$SNIPPET_DIR"

FILE_PATH="$SNIPPET_DIR/cpp.json"

echo "Đang cấu hình snippet tại: $FILE_PATH"

# 2. Ghi nội dung JSON vào file
# Sử dụng 'cat' để ghi đè nội dung một cách chính xác
cat <<EOF > "$FILE_PATH"
{
    "C++ Basic Structure": {
        "prefix": "!cpp",
        "body": [
            "#include <iostream>",
            "#include <string>",
	    "using namespace std;",
	    "",
            "int main() {",
            "\t\$0",
	    "\treturn 0;"
            "}"
        ],
        "description": "C++ basic main structure"
    }
}
EOF

# 3. Thông báo kết quả
if [ $? -eq 0 ]; then
    echo "------------------------------------------"
    echo "Thành công! Đã thêm lệnh tắt '!cpp'."
    echo "Bây giờ bạn hãy vào VS Code, mở file .cpp và gõ !cpp nhé."
    echo "------------------------------------------"
else
    echo "Có lỗi xảy ra trong quá trình ghi file."
fi
