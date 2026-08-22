#!/bin/bash
set -o pipefail  # Phát hiện lỗi trong pipe

# Ép script nhận diện terminal để dùng gum mượt mà
exec < /dev/tty

# --- CẤU HÌNH BAN ĐẦU ---
BLUE='\033[0;34m'
NC='\033[0m'
REPO_URL="https://github.com/quangkhoa1792013-cell/cau_hinh_arch_khoa"
TEMP_DIR="/tmp/arch_config_khoa"
CURRENT_USER="$(whoami)"  # Cache whoami

# --- CÁC MẢNG GÓI (Dễ bảo trì hơn) ---
PACMAN_KHOA=(
    "zip" "7zip" "python" "dhcp" "steam" "os-prober" "efibootmgr"
    "limine" "cava" "cmatrix" "btop" "tar" "gcc" "cargo" "python-pip"
    "curl" "automake" "make" "wine" "nano" "nvim" "vim" "mkinitcpio"
    "limine-mkinitcpio-hook" "git" "flatpak" "bc" "gum" "fakeroot"
    "file" "direnv" "javac"
)

AUR_KHOA=(
    "zalo-macos" "tty-clock" "github-desktop-bin" "spicetify-cli"
    "google-chrome" "visual-studio-code-bin" "warp-cli" "windsurf"
    "tlauncher-installer"
)

UNIKEY_PKGS=("fcitx5" "fcitx5-unikey" "fcitx5-im" "fcitx5-configtool")

# --- CLEANUP TRAP ---
cleanup() {
    echo -e "\n\033[0;33m[*] Đã huỷ script. Dọn dẹp...\033[0m"
    rm -rf "$TEMP_DIR"
    exit 130
}
trap cleanup INT TERM

# --- CÁC HÀM TIỆN ÍCH ---

wait_and_clear() {
    echo -e "\n"
    gum style --foreground 212 "✔ Tác vụ đã hoàn tất!"
    echo -e "Nhấn ${BLUE}phím bất kỳ${NC} để quay lại menu."
    
    for i in {5..1}; do
        echo -ne "Quay lại menu trong $i giây... \r"
        if read -t 1 -n 1 -s 2>/dev/null; then
            break
        fi
    done
    clear
}

pause_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n\033[0;31m[!] Lỗi (exit code: $exit_code)!\033[0m"
        read -p "Nhấn Enter để tiếp tục..."
        return 1
    fi
    return 0
}

check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        gum style --foreground 196 "❌ Không có kết nối Internet!"
        return 1
    fi
    return 0
}

install_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Đang cài đặt gum..."
        sudo pacman -S --needed --noconfirm gum git base-devel || return 1
    fi
}

setup_path() {
    # Tối ưu: kiểm tra chính xác hơn
    if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
}

# --- CÁC HÀM XỬ LÝ CHỨC NĂNG ---

menu_driver() {
    local GPU_TYPE
    clear
    echo "Đang phát hiện GPU..."
    
    # Phát hiện GPU (NVIDIA/AMD/Intel)
    if lspci 2>/dev/null | grep -qi nvidia; then
        GPU_TYPE="nvidia"
        echo "✓ Phát hiện NVIDIA GPU"
    elif lspci 2>/dev/null | grep -qi amd; then
        GPU_TYPE="amd"
        echo "✓ Phát hiện AMD GPU"
    else
        GPU_TYPE="intel"
        echo "✓ Sử dụng Intel GPU (mặc định)"
    fi
    
    echo ""
    echo "Đang cài đặt Driver Linux (loại: $GPU_TYPE)..."
    
    case $GPU_TYPE in
        nvidia)
            sudo pacman -S --needed --noconfirm nvidia nvidia-utils lib32-nvidia-utils
            ;;
        amd)
            sudo pacman -S --needed --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
            ;;
        *)
            sudo pacman -S --needed --noconfirm mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel intel-ucode
            ;;
    esac
    
    sudo pacman -S --needed --noconfirm linux linux-headers linux-firmware base mkinitcpio
    
    if pause_on_error; then wait_and_clear; fi
}

menu_packages() {
    local CHOICE
    local SELECTED
    local CHOSEN_PKGS
    
    while true; do
        clear
        CHOICE=$(gum choose \
            "1. Cài đặt toàn bộ (Khoa)" \
            "2. Tùy chỉnh (chọn gói)" \
            "3. Quay lại")
        
        case $CHOICE in
            "1. Cài đặt toàn bộ (Khoa)")
                echo "Đang cài đặt gói Pacman..."
                sudo pacman -S --needed --noconfirm "${PACMAN_KHOA[@]}" || { pause_on_error; continue; }
                
                if ! command -v yay &> /dev/null; then
                    echo "Đang cài yay..."
                    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay" && \
                    cd "$TEMP_DIR/yay" && makepkg -si --noconfirm && cd - || \
                    { pause_on_error; continue; }
                fi
                
                echo "Đang cài gói AUR..."
                yay -S --needed --noconfirm "${AUR_KHOA[@]}"
                if pause_on_error; then wait_and_clear; fi
                ;;
            
            "2. Tùy chỉnh (chọn gói)")
                SELECTED=$(printf '%s\n' "${PACMAN_KHOA[@]}" | \
                    gum choose --no-limit --header "Space: chọn/bỏ | Enter: xác nhận")
                
                if [ -n "$SELECTED" ]; then
                    mapfile -t CHOSEN_PKGS <<< "$SELECTED"
                    sudo pacman -S --needed --noconfirm "${CHOSEN_PKGS[@]}"
                    if pause_on_error; then wait_and_clear; fi
                fi
                ;;
            
            "3. Quay lại") 
                clear; break 
                ;;
        esac
    done
}

menu_config() {
    check_internet || return
    
    local TEMP_CONFIG="$TEMP_DIR"
    clear
    echo "Đang tải cấu hình từ GitHub..."
    
    rm -rf "$TEMP_CONFIG"
    git clone "$REPO_URL" "$TEMP_CONFIG" || { pause_on_error; return; }
    
    mkdir -p ~/.config
    echo "Đang sao chép .config..."
    
    # Copy bao gồm cả file ẩn
    shopt -s dotglob
    cp -rf "$TEMP_CONFIG"/* ~/.config/ 2>/dev/null
    shopt -u dotglob
    
    rm -rf "$TEMP_CONFIG"
    if pause_on_error; then wait_and_clear; fi
}

menu_lat_vat() {
    local CHOICE
    
    while true; do
        clear
        CHOICE=$(gum choose \
            "1. Cài momoisay" \
            "2. Cài Sober (Flatpak)" \
            "3. Cài Spicetify" \
            "4. Cài Unikey (Fcitx5)" \
            "5. Quay lại")
        
        case $CHOICE in
            "1. Cài momoisay")
                echo "Đang cài momoisay từ Cargo..."
                cargo install momoisay
                if pause_on_error; then wait_and_clear; fi
                ;;
            
            "2. Cài Sober (Flatpak)")
                if ! command -v flatpak &> /dev/null; then
                    sudo pacman -S --noconfirm flatpak || { pause_on_error; continue; }
                fi
                flatpak install flathub org.vinegarhq.Sober -y
                if pause_on_error; then wait_and_clear; fi
                ;;
            
            "3. Cài Spicetify")
                if [ ! -d "/opt/spotify" ]; then
                    gum style --foreground 196 "❌ Spotify chưa được cài đặt!"
                    read -p "Nhấn Enter để tiếp tục..."
                    continue
                fi
                sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R
                spicetify backup apply
                if pause_on_error; then wait_and_clear; fi
                ;;
            
            "4. Cài Unikey (Fcitx5)")
                clear
                echo "Đang cài đặt Fcitx5 và Unikey..."
                sudo pacman -S --needed --noconfirm "${UNIKEY_PKGS[@]}" || { pause_on_error; continue; }
                
                # Thêm vào bashrc nếu chưa có
                if ! grep -q "GTK_IM_MODULE=fcitx" ~/.bashrc; then
                    cat >> ~/.bashrc << 'EOF'

# Fcitx5 Config
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
                fi
                
                gum style --foreground 226 "✔ Cài đặt hoàn tất!"
                echo "⚠️  Vui lòng logout/reboot để Unikey hoạt động."
                read -p "Nhấn Enter để tiếp tục..."
                wait_and_clear
                ;;
            
            "5. Quay lại") 
                clear; break 
                ;;
        esac
    done
}

# --- VÒNG LẶP MENU CHÍNH ---
install_gum || exit 1
setup_path

clear
while true; do
    gum style \
        --border double --align center --width 50 \
        --margin "1 2" --padding "1 1" --foreground 99 \
        "ARCH LINUX SETUP" "User: $CURRENT_USER"

    local MAIN_CHOICE
    MAIN_CHOICE=$(gum choose \
        "1. Cài driver Linux" \
        "2. Cài gói" \
        "3. Cài .config (GitHub)" \
        "4. Cài 'lát vặt'" \
        "5. Thoát")

    case $MAIN_CHOICE in
        "1. Cài driver Linux") 
            menu_driver 
            ;;
        "2. Cài gói") 
            menu_packages 
            ;;
        "3. Cài .config (GitHub)") 
            menu_config 
            ;;
        "4. Cài 'lát vặt'") 
            menu_lat_vat 
            ;;
        "5. Thoát") 
            gum style --foreground 212 "👋 Tạm biệt!"
            exit 0 
            ;;
    esac
done
