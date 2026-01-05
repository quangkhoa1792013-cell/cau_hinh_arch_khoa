#!/bin/bash

# Ép script nhận diện terminal để dùng gum mượt mà
exec < /dev/tty

# --- CẤU HÌNH BAN ĐẦU ---

wait_and_clear() {
    echo -e "\n"
    gum style --foreground 212 "✔ Tác vụ đã hoàn tất!"
    echo -e "Nhấn ${BLUE}phím bất kỳ${NC} để quay lại menu ngay lập tức."
    
    for i in {5..1}; do
        echo -ne "Quay lại menu trong $i giây... \r"
        if read -t 1 -n 1 -s; then
            break
        fi
    done
    clear
}

pause_on_error() {
    if [ $? -ne 0 ]; then
        echo -e "\n\033[0;31m[!] Đã có lỗi xảy ra!\033[0m"
        read -p "Nhấn Enter để kiểm tra lỗi rồi mới quay lại..."
        return 1
    fi
    return 0
}

install_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Đang cài đặt gum để chạy giao diện..."
        sudo pacman -Sy --needed --noconfirm gum git base-devel
    fi
}

setup_path() {
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    fi
}

BLUE='\033[0;34m'
NC='\033[0m'

install_gum
setup_path

# --- DANH SÁCH GÓI ---
# Danh sách mặc định của Khoa
PACMAN_KHOA="zip 7zip python dhcp steam os-prober efibootmgr limine cava cmatrix btop tar gcc cargo python-pip curl automake make wine nano nvim vim mkinitcpio limine-mkinitcpio-hook git flatpak bc gum"
AUR_KHOA="zalo-macos tty-clock github-desktop-bin spicetify-cli google-chrome visual-studio-code-bin"

# Các gói cần cho Unikey/Tiếng Việt
UNIKEY_PKGS="fcitx5 fcitx5-unikey fcitx5-im fcitx5-configtool"

REPO_URL="https://github.com/quangkhoa1792013-cell/cau_hinh_arch_khoa"

# --- CÁC HÀM XỬ LÝ ---

menu_driver() {
    echo "Đang cài đặt Driver Linux..."
    sudo pacman -S --needed --noconfirm linux linux-headers linux-firmware base intel-ucode mesa vulkan-intel lib32-vulkan-intel xf86-video-intel
    if pause_on_error; then wait_and_clear; fi
}

menu_packages() {
    while true; do
        clear
        CHOICE=$(gum choose "1. Cai dat rieng cho Khoa (Mac dinh)" "2. Tuy ban (Chon goi muon tai)" "3. Quay lai")
        
        case $CHOICE in
            "1. Cai dat rieng cho Khoa (Mac dinh)")
                echo "Đang cài đặt toàn bộ gói của Khoa..."
                sudo pacman -S --needed $PACMAN_KHOA
                if ! command -v yay &> /dev/null; then
                    git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && cd -
                fi
                yay -S --needed $AUR_KHOA
                if pause_on_error; then wait_and_clear; fi
                ;;
            "2. Tuy ban (Chon goi muon tai)")
                # Cho phép chọn nhiều gói từ danh sách bằng phím Space
                SELECTED=$(echo "$PACMAN_KHOA" | tr ' ' '\n' | gum choose --no-limit --header "Dùng Space để chọn/bỏ chọn, Enter để xác nhận")
                if [ -n "$SELECTED" ]; then
                    sudo pacman -S --needed $(echo $SELECTED | xargs)
                    if pause_on_error; then wait_and_clear; fi
                fi
                ;;
            "3. Quay lai") clear; break ;;
        esac
    done
}

menu_config() {
    TEMP_DIR="/tmp/arch_config_khoa"
    echo "Đang tải cấu hình từ GitHub..."
    rm -rf $TEMP_DIR && git clone $REPO_URL $TEMP_DIR
    
    mkdir -p ~/.config
    echo "Đang ghi đè .config..."
    cp -rf $TEMP_DIR/* ~/.config/
    
    if pause_on_error; then wait_and_clear; fi
}

menu_lat_vat() {
    while true; do
        clear
        CHOICE=$(gum choose "1. cai momoisay" "2. cai sober" "3. cai spicetify" "4. cai unikey (fcitx5)" "5. Quay lai")
        
        case $CHOICE in
            "1. cai momoisay")
                cargo install momoisay
                if pause_on_error; then wait_and_clear; fi
                ;;
            "2. cai sober")
                if ! command -v flatpak &> /dev/null; then sudo pacman -S --noconfirm flatpak; fi
                flatpak install flathub org.vinegarhq.Sober -y
                if pause_on_error; then wait_and_clear; fi
                ;;
            "3. cai spicetify")
                sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R
                spicetify backup apply
                if pause_on_error; then wait_and_clear; fi
                ;;
            "4. cai unikey (fcitx5)")
                echo "Đang cài đặt Fcitx5 và Unikey..."
                sudo pacman -S --needed --noconfirm $UNIKEY_PKGS
                # Thiết lập biến môi trường cơ bản cho fcitx5
                if ! grep -q "GTK_IM_MODULE" ~/.bashrc; then
                    echo -e "\n# Fcitx5 Config\nexport GTK_IM_MODULE=fcitx\nexport QT_IM_MODULE=fcitx\nexport XMODIFIERS=@im=fcitx" >> ~/.bashrc
                fi
                echo "Hãy khởi động lại máy hoặc logout để Unikey có hiệu lực."
                if pause_on_error; then wait_and_clear; fi
                ;;
            "5. Quay lai") clear; break ;;
        esac
    done
}

# --- VÒNG LẶP MENU CHÍNH ---
clear
while true; do
    gum style \
        --border double --align center --width 50 --margin "1 2" --padding "1 1" --foreground 99 \
        "ARCH LINUX SETUP" "User: $(whoami)"

    MAIN_CHOICE=$(gum choose \
        "1. cai driver linux" \
        "2. cai goi" \
        "3. cai .config (github)" \
        "4. cai lat vat" \
        "5. exit")

    case $MAIN_CHOICE in
        "1. cai driver linux") menu_driver ;;
        "2. cai goi") menu_packages ;;
        "3. cai .config (github)") menu_config ;;
        "4. cai lat vat") menu_lat_vat ;;
        "5. exit") 
            gum style --foreground 212 "Tạm biệt!"
            exit 0 ;;
    esac
done