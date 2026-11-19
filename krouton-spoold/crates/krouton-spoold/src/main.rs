#![forbid(unsafe_code)]

// MARK: - krouton-spoold Headless Cross-Platform Optical Burn & Rescue Daemon CLI

use std::env;

use spoold_crypto::{PairingHello, commitment};
use spoold_hal::{OpticalDrive, VirtualMmcOpticalDrive};
use spoold_mmc::ScsiCdb;
use spoold_proto::frame::HEADER_LEN;
use spoold_store::is_raspberry_pi_sdcard_device;
use spoold_proto::identity;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let cmd = args.first().map(String::as_str).unwrap_or("version");

    match cmd {
        "version" | "--version" | "-V" => {
            println!(
                "krouton-spoold {} (KRSP v1, header={}B, arch={}, os={})",
                env!("CARGO_PKG_VERSION"),
                HEADER_LEN,
                env::consts::ARCH,
                env::consts::OS
            );
        }
        "drives" => {
            let mut vdrive = VirtualMmcOpticalDrive::new("virtual-sr0", "usb-bus-1", 2048, 2_295_104);
            let mut fifo = [0u8; 12];
            let _ = vdrive.execute(&ScsiCdb::read_buffer_capacity(), &mut fifo);
            let total_buf = u32::from_be_bytes([fifo[4], fifo[5], fifo[6], fifo[7]]);
            let free_buf = u32::from_be_bytes([fifo[8], fifo[9], fifo[10], fifo[11]]);
            let desc = vdrive.descriptor();
            let sd_guard = !is_raspberry_pi_sdcard_device(&desc.id);
            println!(
                "DRIVE id={} model=\"{}\" bus={} max_current={}mA fifo_total={}B fifo_free={}B sdcard_safe={}",
                desc.id, desc.vendor_model, desc.usb_bus_id, desc.max_current_ma, total_buf, free_buf, sd_guard
            );
            vdrive.reclaim_unused_resources();
        }
        "pair" => {
            let id_seed = [0x42u8; 32];
            let eph_seed = [0x24u8; 32];
            let hello = PairingHello::from_seeds(&id_seed, &eph_seed, [0xA5; 16]);
            let node = identity::node_id(&hello.identity_key);
            let commit = commitment(&hello);
            let mut commit_hex = String::with_capacity(64);
            for b in commit {
                use std::fmt::Write as _;
                let _ = write!(&mut commit_hex, "{b:02x}");
            }
            println!("NODE_ID={node}");
            println!("PAIR_URI=krouton-pair://{node}?c={commit_hex}&p=7420");
        }
        "service" => {
            let os_target = args.get(2).map(String::as_str).unwrap_or(env::consts::OS);
            print_service_template(os_target);
        }
        _ => {
            println!("Usage: krouton-spoold <version | drives [--virtual] | pair | service print <macos|linux|windows>>");
        }
    }
}

// MARK: - Hardened OS Service Templates (launchd, systemd + udev, Windows SCM)

fn print_service_template(os_target: &str) {
    match os_target {
        "macos" => {
            println!(
                r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0"><dict>
  <key>Label</key><string>com.krouton.spoold</string>
  <key>ProgramArguments</key><array><string>/usr/local/libexec/krouton-spoold</string><string>run</string></array>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>"#
            );
        }
        "linux" => {
            println!(
                r#"[Unit]
Description=Krouton Optical Spool Daemon (KRSP v1)
After=network-online.target

[Service]
Type=simple
User=_krouton
Group=cdrom
ExecStart=/usr/libexec/krouton-spoold run
ProtectSystem=strict
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target"#
            );
        }
        "windows" => {
            println!(
                r#"ServiceName: KroutonSpoold
DisplayName: Krouton Optical Spool Service (KRSP v1)
BinaryPath: C:\Program Files\Krouton\krouton-spoold.exe run
StartType: Automatic (Delayed Start)
Account: NT AUTHORITY\LocalSystem (SPTI \\.\CdRomN raw CDB access)"#
            );
        }
        _ => println!("Unsupported OS template: {os_target} (expected macos, linux, or windows)"),
    }
}
