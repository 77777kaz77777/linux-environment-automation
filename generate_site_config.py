#!/usr/bin/env python3
import yaml
from pathlib import Path
from collections import defaultdict

EXCLUDED_DIRS = {'.git', '.github', '.obsidian', 'site', 'assets', 'venv', '__pycache__', '.venv', 'stylesheets'}

ACRONYMS = {
    "cli": "CLI",
    "lxc": "LXC",
    "ssh": "SSH",
    "dns": "DNS",
    "kde": "KDE",
    "gpu": "GPU",
    "amdgpu": "AMDGPU",
    "nvidia": "NVIDIA",
    "grub": "GRUB",
    "ssd": "SSD",
    "nvme": "NVMe",
    "btrfs": "BTRFS",
    "rog": "ROG",
    "asus": "ASUS",
    "vm": "VM",
    "vms": "VMs",
    "kvm": "KVM",
    "qemu": "QEMU",
    "proxmox": "Proxmox",
    "macos": "macOS",
    "ios": "iOS",
    "ip": "IP",
    "ufw": "UFW",
    "vpn": "VPN",
    "usb": "USB",
    "cpu": "CPU",
    "ram": "RAM",
    "bios": "BIOS",
    "uefi": "UEFI",
    "lvm": "LVM",
    "zfs": "ZFS",
    "smb": "SMB",
    "nfs": "NFS",
    "api": "API",
    "gui": "GUI",
    "tui": "TUI",
    "os": "OS",
}

LOWERCASE_WORDS = {"and", "or", "for", "in", "on", "to", "with", "of", "via", "vs"}

def format_label(raw_name: str) -> str:
    stem = Path(raw_name).stem
    if stem.upper() == "README":
        return "Overview"
    
    # Handle attached numbers like fedora44 -> fedora 44
    import re
    stem = re.sub(r'([a-zA-Z])(\d+)', r'\1 \2', stem)
    words = re.split(r'[-_\s]+', stem.strip())
    
    formatted = []
    for i, word in enumerate(words):
        if not word:
            continue
        low = word.lower()
        if low in ACRONYMS:
            formatted.append(ACRONYMS[low])
        elif i > 0 and low in LOWERCASE_WORDS:
            formatted.append(low)
        else:
            formatted.append(word.capitalize())
            
    title = " ".join(formatted)
    return title.replace("Cheatsheet", "Cheat Sheet")

def build_snippets_page(repo_dir=".", output_file="source-code-reference.md"):
    files_by_dir = defaultdict(list)
    target_extensions = {'.py', '.sh', '.service', '.timer', '.toml', '.conf', '.jsonc'}
    
    for path in Path(repo_dir).rglob("*"):
        if path.is_file() and path.suffix in target_extensions:
            if not any(part.startswith('.') or part in EXCLUDED_DIRS for part in path.parts[:-1]):
                files_by_dir[path.parent.name].append(path)
                
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# Source Code Reference\n\n")
        f.write("Expand the blocks below to view the source code directly on this page.\n\n")
        for directory, files in sorted(files_by_dir.items()):
            dir_name = directory if directory != "." else "root"
            f.write(f"## 📁 {format_label(dir_name)}\n\n")
            for file_path in sorted(files):
                ext = file_path.suffix
                lang = "python" if ext == '.py' else "toml" if ext == '.toml' else "json" if ext == '.jsonc' else "ini" if ext in {'.conf', '.service', '.timer'} else "bash"
                f.write(f'??? quote "{file_path.name}"\n')
                f.write(f'    ```{lang} title="{file_path.as_posix()}"\n')
                f.write(f'    --8<-- "{file_path.as_posix()}"\n')
                f.write(f'    ```\n\n')

def build_nav(directory='.'):
    nav = []
    dir_path = Path(directory)
    
    # 1. Process files in current directory
    md_files = sorted(
        [f for f in dir_path.iterdir() if f.is_file() and f.suffix.lower() == '.md'],
        key=lambda p: (0 if p.name.upper() == 'README.MD' else 1, p.name.lower())
    )
    
    for path in md_files:
        if path.name.startswith('.'):
            continue
        if directory == '.' and path.name.upper() == 'README.MD':
            nav.insert(0, {'Home': 'README.md'})
        elif path.name.upper() != 'README.MD':
            label = format_label(path.name)
            nav.append({label: str(path.as_posix())})
            
    # 2. Process subdirectories
    subdirs = sorted(
        [d for d in dir_path.iterdir() if d.is_dir() and d.name not in EXCLUDED_DIRS and not d.name.startswith('.')],
        key=lambda p: p.name.lower()
    )
    
    for path in subdirs:
        sub_nav = build_nav(path)
        if sub_nav:
            dir_label = format_label(path.name)
            nav.append({dir_label: sub_nav})
            
    return nav

if __name__ == "__main__":
    # 1. Generate the snippets markdown file first
    build_snippets_page()
    
    # 2. Crawl the directory and update mkdocs.yml navigation
    mkdocs_path = Path('mkdocs.yml')
    if mkdocs_path.exists():
        with open(mkdocs_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
            
        config['nav'] = build_nav()
        
        with open(mkdocs_path, 'w', encoding='utf-8') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print("Successfully generated snippets and updated navigation in mkdocs.yml")
