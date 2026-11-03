import os
import mkdocs_gen_files

# Map file extensions to their markdown syntax highlighting language
SUPPORTED_EXTENSIONS = {
    '.sh': 'bash',
    '.py': 'python',
    '.toml': 'toml',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.conf': 'bash'
}

# Directories to skip
IGNORE_DIRS = ['.git', '.github', '.obsidian']

# Walk through the repository
for root, dirs, files in os.walk('.'):
    # Skip hidden directories and explicitly ignored directories
    dirs[:] = [d for d in dirs if not d.startswith('.') and d not in IGNORE_DIRS]
    
    for file in files:
        ext = os.path.splitext(file)[1]
        if ext in SUPPORTED_EXTENSIONS:
            file_path = os.path.join(root, file)
            clean_path = file_path.lstrip('./')
            
            # Create a virtual markdown path (e.g., scripts/setup.sh -> scripts/setup.sh.md)
            md_path = f"{clean_path}.md"
            lang = SUPPORTED_EXTENSIONS[ext]
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    code_content = f.read()
                    
                # Write the file into the MkDocs virtual build environment
                with mkdocs_gen_files.open(md_path, 'w') as fd:
                    fd.write(f"# {file}\n\n")
                    fd.write(f"```{lang}\n")
                    fd.write(code_content)
                    fd.write(f"\n```\n")
            except Exception as e:
                print(f"Skipping {file_path}: {e}")
