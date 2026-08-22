import customtkinter as ctk
import subprocess
import re
import threading
import time

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

SUDO_PASSWORD = "1792013"

class WarpUltimate(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("WARP Ultimate Control - Arch Linux")
        self.geometry("600x850")

        # --- MONITOR PANEL ---
        self.label_title = ctk.CTkLabel(self, text="WARP SYSTEM MONITOR", font=("Roboto", 22, "bold"))
        self.label_title.pack(pady=15)

        self.status_frame = ctk.CTkFrame(self, fg_color="#1a1a1a", border_width=1)
        self.status_frame.pack(pady=10, padx=20, fill="x")

        self.labels = {}
        # Các trường thông tin hiển thị
        fields = [
            ("Daemon", "Hệ thống (Daemon)"),
            ("Status", "Kết nối (Status)"),
            ("Account", "Tài khoản (Account)"),
            ("Mode", "Chế độ (Mode)"),
            ("IP", "Địa chỉ IP WARP")
        ]

        for key, text in fields:
            row = ctk.CTkFrame(self.status_frame, fg_color="transparent")
            row.pack(fill="x", padx=15, pady=4)
            ctk.CTkLabel(row, text=f"{text}:", font=("Roboto", 13, "bold"), width=150, anchor="w").pack(side="left")
            self.labels[key] = ctk.CTkLabel(row, text="---", text_color="gray", font=("Monospace", 13))
            self.labels[key].pack(side="right")

        # --- CONTROL SECTION ---
        self.scroll_frame = ctk.CTkScrollableFrame(self, fg_color="transparent")
        self.scroll_frame.pack(pady=10, padx=20, fill="both", expand=True)

        self.create_group_label("ĐIỀU KHIỂN DAEMON (HỆ THỐNG)")
        self.btn_row1 = self.create_button_row(self.scroll_frame)
        ctk.CTkButton(self.btn_row1, text="BẬT DAEMON", fg_color="#2E7D32", command=lambda: self.run_async(self.daemon_start)).pack(side="left", padx=5, expand=True, fill="x")
        ctk.CTkButton(self.btn_row1, text="TẮT DAEMON", fg_color="#C62828", command=lambda: self.run_async(self.daemon_stop)).pack(side="left", padx=5, expand=True, fill="x")
        ctk.CTkButton(self.scroll_frame, text="RESTART DAEMON (SỬA LỖI)", fg_color="#546E7A", command=lambda: self.run_async(self.daemon_restart)).pack(pady=5, fill="x")

        self.create_group_label("ĐIỀU KHIỂN KẾT NỐI (VPN)")
        self.btn_row2 = self.create_button_row(self.scroll_frame)
        ctk.CTkButton(self.btn_row2, text="KẾT NỐI", fg_color="#1565C0", command=lambda: self.run_async(self.conn_connect)).pack(side="left", padx=5, expand=True, fill="x")
        ctk.CTkButton(self.btn_row2, text="NGẮT KẾT NỐI", fg_color="#E65100", command=lambda: self.run_async(self.conn_disconnect)).pack(side="left", padx=5, expand=True, fill="x")

        self.create_group_label("CẤU HÌNH")
        self.mode_menu = ctk.CTkOptionMenu(self.scroll_frame, values=["warp", "doh", "dot", "proxy"], command=lambda m: self.run_async(lambda: self.change_mode(m)))
        self.mode_menu.pack(pady=5, fill="x")
        ctk.CTkButton(self.scroll_frame, text="ĐĂNG KÝ DỊCH VỤ / ACCEPT TOS", fg_color="#6A1B9A", command=lambda: self.run_async(self.register_tos)).pack(pady=5, fill="x")

        # --- LOG CONSOLE ---
        self.console = ctk.CTkTextbox(self, height=180, font=("Monospace", 12), fg_color="#000", text_color="#00FF00")
        self.console.pack(pady=15, padx=20, fill="x")

        self.update_thread = threading.Thread(target=self.monitor_loop, daemon=True)
        self.update_thread.start()

    def create_group_label(self, text):
        lbl = ctk.CTkLabel(self.scroll_frame, text=text, font=("Roboto", 11, "bold"), text_color="#555")
        lbl.pack(pady=(15, 5), anchor="w")

    def create_button_row(self, master):
        frame = ctk.CTkFrame(master, fg_color="transparent")
        frame.pack(fill="x", pady=2)
        return frame

    def log(self, text):
        icon = "✅ " if "Thành công" in text else ("❌ " if "Lỗi" in text else "> ")
        self.console.insert("end", f"[{time.strftime('%H:%M:%S')}] {icon}{text}\n")
        self.console.see("end")

    def run_async(self, func):
        threading.Thread(target=func, daemon=True).start()

    def run_sudo(self, cmd):
        full_cmd = f"echo '{SUDO_PASSWORD}' | sudo -S {cmd}"
        return subprocess.run(full_cmd, shell=True, capture_output=True, text=True)

    def monitor_loop(self):
        while True:
            # 1. Kiểm tra Daemon
            d_check = subprocess.run(["systemctl", "is-active", "warp-svc"], capture_output=True, text=True)
            is_active = d_check.stdout.strip() == "active"
            self.labels["Daemon"].configure(text="ONLINE" if is_active else "OFFLINE", text_color="#4CAF50" if is_active else "#F44336")

            if is_active:
                # 2. Lấy Status tổng quát
                st_res = subprocess.run(["warp-cli", "--accept-tos", "status"], capture_output=True, text=True).stdout
                
                # Tìm trạng thái kết nối
                status = "Disconnected"
                if "Status update: Connected" in st_res: status = "Connected"
                elif "Status update: Connecting" in st_res: status = "Connecting..."
                self.labels["Status"].configure(text=status.upper(), text_color="#4CAF50" if status == "Connected" else "#FF5252")

                # Tìm IP (Quét dòng có chứa IPv4)
                ip_match = re.search(r"IPv4:\s+([0-9\.]+)", st_res)
                self.labels["IP"].configure(text=ip_match.group(1) if ip_match else "None", text_color="#42A5F5")

                # 3. Lấy Account & Mode từ lệnh settings
                set_res = subprocess.run(["warp-cli", "--accept-tos", "settings"], capture_output=True, text=True).stdout
                
                # Tìm Mode
                mode_match = re.search(r"Mode:\s+(.*)", set_res)
                self.labels["Mode"].configure(text=mode_match.group(1).strip() if mode_match else "---", text_color="#BA68C8")

                # 4. Kiểm tra đăng ký (Registration)
                reg_res = subprocess.run(["warp-cli", "--accept-tos", "registration", "show"], capture_output=True, text=True).stdout
                is_reg = "Registration ID" in reg_res
                self.labels["Account"].configure(text="REGISTERED" if is_reg else "NOT REGISTERED", text_color="#4CAF50" if is_reg else "#FF9800")
            else:
                for k in ["Status", "IP", "Mode", "Account"]: self.labels[k].configure(text="---", text_color="gray")
            
            time.sleep(1)

    # --- ACTIONS ---
    def daemon_start(self):
        self.log("Đang bật Daemon...")
        res = self.run_sudo("systemctl start warp-svc")
        self.log("Thành công: Daemon đã bật" if res.returncode == 0 else f"Lỗi: {res.stderr}")

    def daemon_stop(self):
        self.log("Đang tắt Daemon...")
        res = self.run_sudo("systemctl stop warp-svc")
        self.log("Thành công: Daemon đã tắt" if res.returncode == 0 else f"Lỗi: {res.stderr}")

    def daemon_restart(self):
        self.log("Đang khởi động lại Daemon (Sửa lỗi kết nối)...")
        res = self.run_sudo("systemctl restart warp-svc")
        self.log("Thành công: Daemon đã khởi động lại" if res.returncode == 0 else "Lỗi hệ thống")

    def conn_connect(self):
        self.log("Đang thực hiện kết nối VPN...")
        subprocess.run(["warp-cli", "--accept-tos", "connect"])
        self.log("Lệnh kết nối đã được gửi đi.")

    def conn_disconnect(self):
        self.log("Đang ngắt kết nối VPN...")
        subprocess.run(["warp-cli", "--accept-tos", "disconnect"])
        self.log("Đã ngắt kết nối thành công.")

    def change_mode(self, mode):
        self.log(f"Chuyển chế độ sang: {mode}")
        subprocess.run(["warp-cli", "--accept-tos", "mode", mode])
        self.log(f"Thành công: Đã chuyển sang {mode}")

    def register_tos(self):
        self.log("Đang đăng ký dịch vụ với Cloudflare...")
        res = subprocess.run(["warp-cli", "--accept-tos", "register"], capture_output=True, text=True)
        if res.returncode == 0 or "Success" in res.stdout:
            self.log("Thành công: Đã đăng ký/Chấp nhận TOS")
        else:
            self.log(f"Thông báo: {res.stdout.strip()}")

if __name__ == "__main__":
    app = WarpUltimate()
    app.mainloop()
