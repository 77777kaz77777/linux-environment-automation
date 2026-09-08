## This script reads the generated JSON manifest, moves and renames the script files into sanitized category subdirectories, and automatically compiles a ⁠README.md⁠ index table documenting them all.


#!/usr/bin/env python3
import os
import json
import shutil
import re

# Configuration
BASE_DIR = "/mnt/router_scripts/_Organized_Files/Scripts_And_Configs/"
MANIFEST_FILE = "script_manifest.json"
README_FILE = os.path.join(BASE_DIR, "README.md")

def sanitize_name(name, default="uncategorized"):
    """Removes spaces and invalid characters for safe Linux paths."""
    if not name:
        return default
    clean = re.sub(r'[^a-zA-Z0-9_\-.]', '', name.replace(' ', '-').lower())
    return clean or default

def main():
    if not os.path.exists(MANIFEST_FILE):
        print(f"Error: {MANIFEST_FILE} not found in the current directory.")
        return

    with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    organized_data = {}
    print(f"Starting organization in {BASE_DIR}...")
    
    for entry in manifest:
        original = entry.get("original")
        summary = entry.get("summary", "No summary provided.")
        category = sanitize_name(entry.get("category"))
        suggested_filename = sanitize_name(entry.get("suggested_filename", original))

        src_path = os.path.join(BASE_DIR, original)
        category_dir = os.path.join(BASE_DIR, category)
        dest_path = os.path.join(category_dir, suggested_filename)

        if not os.path.exists(src_path):
            print(f"Warning: Source file not found, skipping: {original}")
            continue

        # Create the category directory if it doesn't exist
        os.makedirs(category_dir, exist_ok=True)

        # Prevent overwriting if multiple scripts get assigned the same name
        counter = 1
        base_name, ext = os.path.splitext(suggested_filename)
        if not ext:
            ext = ".sh" # Default to .sh if no extension was generated
            
        while os.path.exists(dest_path):
            dest_path = os.path.join(category_dir, f"{base_name}-{counter}{ext}")
            counter += 1

        # Move and rename
        try:
            shutil.move(src_path, dest_path)
            print(f"Moved: {original} -> {category}/{os.path.basename(dest_path)}")
            
            # Store metadata to generate the documentation
            if category not in organized_data:
                organized_data[category] = []
            organized_data[category].append({
                "filename": os.path.basename(dest_path),
                "summary": summary
            })
        except Exception as e:
            print(f"Error moving {original}: {e}")

    # Generate the Markdown documentation index
    print(f"\nGenerating index at {README_FILE}...")
    with open(README_FILE, "w", encoding="utf-8") as readme:
        readme.write("# Organized Scripts and Configurations\n\n")
        
        for category, scripts in sorted(organized_data.items()):
            readme.write(f"## {category.replace('-', ' ').title()}\n\n")
            readme.write("| Filename | Description |\n")
            readme.write("|---|---|\n")
            for script in sorted(scripts, key=lambda x: x['filename']):
                readme.write(f"| `{script['filename']}` | {script['summary']} |\n")
            readme.write("\n")

    print("Organization complete.")

if __name__ == "__main__":
    main()
