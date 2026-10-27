from pathlib import Path
from collections import defaultdict

def build_snippets_page(repo_dir=".", output_file="source-code-reference.md"):
    files_by_dir = defaultdict(list)
    
    # Define which file types to include
    target_extensions = {'.py', '.sh', '.service', '.timer', '.toml', '.conf', '.jsonc'}
    exclude_dirs = {'.git', '.github', 'site', 'assets', 'venv'}
    
    # Crawl the directory
    for path in Path(repo_dir).rglob("*"):
        if path.is_file() and path.suffix in target_extensions:
            # Skip hidden directories and explicitly excluded folders
            if not any(part.startswith('.') or part in exclude_dirs for part in path.parts[:-1]):
                files_by_dir[path.parent.name].append(path)
                
    # Write the Markdown file
    with open(output_file, 'w') as f:
        f.write("# Source Code Reference\n\n")
        f.write("Expand the blocks below to view the source code directly on this page.\n\n")
        
        for directory, files in sorted(files_by_dir.items()):
            dir_name = directory if directory != "." else "root"
            f.write(f"## 📁 {dir_name}\n\n")
            
            for file_path in sorted(files):
                # Map extensions to syntax highlighting languages
                ext = file_path.suffix
                lang = "bash"
                if ext == '.py':
                    lang = "python"
                elif ext == '.toml':
                    lang = "toml"
                elif ext == '.jsonc':
                    lang = "json"
                elif ext in {'.conf', '.service', '.timer'}:
                    lang = "ini"
                
                # Write the collapsible block and snippet inclusion
                f.write(f'??? quote "{file_path.name}"\n')
                f.write(f'    ```{lang} title="{file_path.as_posix()}"\n')
                f.write(f'    --8<-- "{file_path.as_posix()}"\n')
                f.write(f'    ```\n\n')

if __name__ == "__main__":
    build_snippets_page()
