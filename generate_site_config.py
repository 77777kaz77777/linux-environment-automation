import yaml
from pathlib import Path
from collections import defaultdict

def build_snippets_page(repo_dir=".", output_file="source-code-reference.md"):
    files_by_dir = defaultdict(list)
    target_extensions = {'.py', '.sh', '.service', '.timer', '.toml', '.conf', '.jsonc'}
    exclude_dirs = {'.git', '.github', 'site', 'assets', 'venv'}
    
    for path in Path(repo_dir).rglob("*"):
        if path.is_file() and path.suffix in target_extensions:
            if not any(part.startswith('.') or part in exclude_dirs for part in path.parts[:-1]):
                files_by_dir[path.parent.name].append(path)
                
    with open(output_file, 'w') as f:
        f.write("# Source Code Reference\n\n")
        f.write("Expand the blocks below to view the source code directly on this page.\n\n")
        for directory, files in sorted(files_by_dir.items()):
            dir_name = directory if directory != "." else "root"
            f.write(f"## 📁 {dir_name}\n\n")
            for file_path in sorted(files):
                ext = file_path.suffix
                lang = "python" if ext == '.py' else "toml" if ext == '.toml' else "json" if ext == '.jsonc' else "ini" if ext in {'.conf', '.service', '.timer'} else "bash"
                f.write(f'??? quote "{file_path.name}"\n')
                f.write(f'    ```{lang} title="{file_path.as_posix()}"\n')
                f.write(f'    --8<-- "{file_path.as_posix()}"\n')
                f.write(f'    ```\n\n')

def build_nav(directory='.'):
    nav = []
    for path in sorted(Path(directory).iterdir()):
        if path.name.startswith('.') or path.name in ['assets', 'site', 'utils', 'venv']:
            continue
        if path.is_file():
            if path.suffix != '.md':
                continue
            if path.name == 'index.md' and directory == '.':
                nav.insert(0, {'Home': 'index.md'})
            elif path.name != 'index.md':
                nav.append({path.name: str(path)})
        elif path.is_dir():
            sub_nav = build_nav(path)
            if sub_nav:
                dir_name = path.name.replace('-', ' ').title()
                nav.append({dir_name: sub_nav})
    return nav

if __name__ == "__main__":
    # 1. Generate the snippets markdown file first
    build_snippets_page()
    
    # 2. Crawl the directory and build the navigation (which will now include the new snippets page)
    with open('mkdocs.yml', 'r') as f:
        config = yaml.safe_load(f)
        
    config['nav'] = build_nav()
    
    # 3. Save the updated mkdocs configuration
    with open('mkdocs.yml', 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
