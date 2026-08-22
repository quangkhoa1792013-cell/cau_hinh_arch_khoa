#!/bin/bash

# Đường dẫn đến file cấu hình
CONFIG_FILE="$HOME/.config/hypr/hypridle.conf"

# --- KIỂM TRA VÀ CÀI ĐẶT CÔNG CỤ ---
CHECK_PACKAGES=("bc" "gum")
MISSING_PACKAGES=()

for pkg in "${CHECK_PACKAGES[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "Phát hiện thiếu công cụ: ${MISSING_PACKAGES[*]}"
    read -p "Bạn có muốn cài đặt tự động không? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        sudo pacman -S --noconfirm "${MISSING_PACKAGES[@]}"
        echo "-------------------------------------------------------"
        echo "Đã cài đặt xong! Vui lòng chạy lại script để sử dụng."
        echo "-------------------------------------------------------"
        exit 0
    else
        echo "Script yêu cầu các công cụ này để hoạt động. Thoát."
        exit 1
    fi
fi

# --- PHẦN LOGIC CHÍNH (ĐÃ CÓ GUM & BC) ---

convert_to_seconds() {
    local input=$1
    local value=$(echo $input | grep -oE '^[0-9.]+')
    local unit=$(echo $input | grep -oE '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')

    case $unit in
        ms) echo "scale=3; $value / 1000" | bc ;;
        s|"") echo "$value" ;; 
        m) echo "scale=0; $value * 60 / 1" | bc ;;
        h) echo "scale=0; $value * 3600 / 1" | bc ;;
        *) echo "$value" ;; 
    esac
}

generate_config() {
    cat <<EOF > "$CONFIG_FILE"
general {
    lock_cmd = omarchy-lock-screen
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    inhibit_sleep = 3
}

listener {
    timeout = $1                                             
    on-timeout = pidof hyprlock || omarchy-launch-screensaver 
}

listener {
    timeout = $2                      
    on-timeout = loginctl lock-session 
}

listener {
    timeout = $3                                            
    on-timeout = hyprctl dispatch dpms off                   
    on-resume = hyprctl dispatch dpms on && brightnessctl -r 
}
EOF
}

CHOICE=$(gum choose "1. Bình thường (5p Lock)" "2. Tập trung học (Always ON)" "3. Chill chill (10p Lock)" "4. Tùy chỉnh")

case "$CHOICE" in
    "1. Bình thường (5p Lock)")
        generate_config 150 300 330
        gum style --foreground 212 "󰈈 Đã chuyển sang chế độ: Bình thường"
        ;;
    "2. Tập trung học (Always ON)")
        generate_config 9999999 9999999 9999999
        gum style --foreground 226 "󰑮 Đã chuyển sang chế độ: Tập trung học"
        ;;
    "3. Chill chill (10p Lock)")
        generate_config 480 600 660
        gum style --foreground 81 "󰋊 Đã chuyển sang chế độ: Chill chill"
        ;;
    "4. Tùy chỉnh")
        USER_INPUT=$(gum input --placeholder "Nhập thời gian (VD: 500ms, 30s, 15m, 2h)..." \
            --header "Đơn vị: ms=mili giây, s=giây, m=phút, h=giờ")
        
        if [ -z "$USER_INPUT" ]; then exit 0; fi

        lock_sec=$(convert_to_seconds "$USER_INPUT")
        ss_sec=$(echo "$lock_sec - 30" | bc)
        dpms_sec=$(echo "$lock_sec + 30" | bc)
        
        generate_config $ss_sec $lock_sec $dpms_sec
        gum style --foreground 46 "󰄬 Đã áp dụng: $lock_sec giây"
        ;;
esac

pkill hypridle
hypridle > /dev/null 2>&1 &
disown

gum spin --spinner dot --title "Đang nạp cấu hình..." sleep 0.5