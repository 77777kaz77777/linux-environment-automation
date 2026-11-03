#!/usr/bin/env python3
import yaml
import re
from pathlib import Path
from collections import defaultdict

EXCLUDED_DIRS = {'.git', '.github', '.obsidian', 'site', 'assets', 'venv', '__pycache__', '.venv', 'stylesheets'}

ACRONYMS = {
    "cli": "CLI", "lxc": "LXC", "ssh": "SSH", "dns": "DNS", "kde": "KDE",
    "gpu": "GPU", "amdgpu": "AMDGPU", "nvidia": "NVIDIA", "grub": "GRUB",
    "ssd": "SSD", "nvme": "NVMe", "btrfs": "BTRFS", "rog": "ROG",
    "asus": "ASUS", "vm": "VM", "vms": "VMs", "kvm": "KVM", "qemu": "QEMU",
    "proxmox": "Proxmox", "macos": "macOS", "ios": "iOS", "ip": "IP",
    "ufw": "UFW", "vpn": "VPN", "usb": "USB", "cpu": "CPU", "ram": "RAM",
    "bios": "BIOS", "uefi": "UEFI", "lvm": "LVM", "zfs": "ZFS",
    "smb": "SMB", "nfs": "NFS", "api": "API", "gui": "GUI", "tui": "TUI",
    "os": "OS",
}

LOWERCASE_WORDS = {"and", "or", "for", "in", "on", "to", "with", "of", "via", "vs"}
TARGET_EXTENSIONS = {'.py', '.sh', '.service', '.timer', '.toml', '.conf', '.jsonc'}

def format_label(raw_name: str) -> str:
    stem = Path(raw_name).stem
    
    # Strip secondary code extensions from the wrappers (e.g. script.sh.md -> script)
    while Path(stem).suffix in TARGET_EXTENSIONS:
        stem = Path(stem).stem
        
    if stem.upper() == "README":
        return "Overview"
    
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

def build_wrapper_pages(repo_dir="."):
    """Generate physical .md wrappers for all code scripts so they get included in the nav."""
    for path in Path(repo_dir).rglob("*"):
        if path.is_file() and path.suffix in TARGET_EXTENSIONS:
            if not any(part.startswith('.') or part in EXCLUDED_DIRS for part in path.parts[:-1]):
                # Create a physical markdown wrapper file
                md_path = path.with_name(path.name + '.md')
                lang = "python" if path.suffix == '.py' else "toml" if path.suffix == '.toml' else "json" if path.suffix == '.jsonc' else "ini" if path.suffix in {'.conf', '.service', '.timer'} else "bash"
                
                with open(md_path, 'w', encoding='utf-8') as f:
                    f.write(f"# {path.name}\n\n")
                    f.write(f"```{lang}\n")
                    f.write(f"--8<-- \"{path.as_posix()}\"\n")
                    f.write(f"```\n")

def build_snippets_page(repo_dir=".", output_file="source-code-reference.md"):
    files_by_dir = defaultdict(list)
    
    for path in Path(repo_dir).rglob("*"):
        if path.is_file() and path.suffix in TARGET_EXTENSIONS:
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

def update_gitignore():
    """Ensure the generated .md wrappers are ignored by git so they don't pollute the local repo."""
    gitignore_path = Path('.gitignore')
    ignore_entries = [f"*{ext}.md" for ext in TARGET_EXTENSIONS]
    
    if gitignore_path.exists():
        with open(gitignore_path, 'r', encoding='utf-8') as f:
            content = f.read()
    else:
        content = ""
        
    appends = []
    for entry in ignore_entries:
        if entry not in content:
            appends.append(entry)
            
    if appends:
        with open(gitignore_path, 'a', encoding='utf-8') as f:
            f.write("\n# Auto-generated script markdown wrappers\n")
            for entry in appends:
                f.write(f"{entry}\n")

if __name__ == "__main__":
    # 0. Add extensions to .gitignore to prevent local repo pollution
    update_gitignore()

    # 1. Generate physical Markdown wrappers for every script FIRST
    build_wrapper_pages()

    # 2. Generate the single snippets markdown file
    build_snippets_page()
    
    # 3. Crawl the directory and update mkdocs.yml navigation (will now find the new wrappers natively)
    mkdocs_path = Path('mkdocs.yml')
    if mkdocs_path.exists():
        with open(mkdocs_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
            
        config['nav'] = build_nav()
        
        with open(mkdocs_path, 'w', encoding='utf-8') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print("Successfully generated wrapper pages, snippets, and updated navigation in mkdocs.yml")
