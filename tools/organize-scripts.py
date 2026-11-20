## This script scans a local directory of bash scripts, uses a local LLM via LM Studio to analyze and categorize each one, and compiles the metadata into a JSON manifest file.


import json
import os

from openai import OpenAI

# Point to the local LM Studio server
client = OpenAI(
    base_url="http://localhost:1234/v1",
    api_key="" # Dummy key required by the client SDK
)

# Path to the folder containing your 517 scripts
SCRIPTS_DIR = "./my_scripts"

def analyze_script(file_path):
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read(4000) # Read first 4000 chars to save context window

    prompt = f"""Analyze this bash script and return a JSON object with three keys:
    1. "summary": A concise one-sentence description of what the script does.
    2. "category": A broad operational category (e.g., networking, backup, user-management, maintenance, docker).
    3. "suggested_filename": A clean, hyphenated lowercase filename ending in .sh (e.g., backup-database.sh).

    Script Content:
    {content}
    
    Return ONLY valid JSON. No markdown ticks, no extra text.
    """

    try:
        response = client.chat.completions.create(
            model="local-model", # LM Studio maps this to whatever model is currently loaded
            messages=[
                {"role": "system", "content": "You are a precise sysadmin assistant that outputs strict JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.1
        )
        
        result_text = response.choices[0].message.content.strip()
        # Clean up code blocks if the model accidentally adds them
        if result_text.startswith("```json"):
            result_text = result_text[7:-3].strip()
        elif result_text.startswith("```"):
            result_text = result_text[3:-3].strip()
            
        return json.loads(result_text)
    except Exception as e:
        return {"summary": f"Error parsing: {e}", "category": "unknown", "suggested_filename": os.path.basename(file_path)}

def main():
    if not os.path.exists(SCRIPTS_DIR):
        print(f"Directory {SCRIPTS_DIR} does not exist.")
        return

    manifest = []
    files = [f for f in os.listdir(SCRIPTS_DIR) if os.path.isfile(os.path.join(SCRIPTS_DIR, f))]
    
    print(f"Found {len(files)} scripts to process...")

    for i, filename in enumerate(files):
        file_path = os.path.join(SCRIPTS_DIR, filename)
        print(f"[{i+1}/{len(files)}] Processing {filename}...")
        
        analysis = analyze_script(file_path)
        manifest.append({
            "original": filename,
            "summary": analysis.get("summary"),
            "category": analysis.get("category"),
            "suggested_filename": analysis.get("suggested_filename")
        })

    with open("script_manifest.json", "w", encoding="utf-8") as out:
        json.dump(manifest, out, indent=4)
    
    print("Processing complete! Manifest saved to script_manifest.json.")

if __name__ == "__main__":
    main()
