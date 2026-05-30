import json
import urllib.request
import os
import ssl

ssl._create_default_https_context = ssl._create_unverified_context

input_file = '/Users/maddy/.gemini/antigravity-ide/brain/c09a9d5e-e103-4cbc-b9fb-3ddd6bc7e074/.system_generated/steps/11/output.txt'
out_dir = '/Users/maddy/ZeroPay-app/.stitch_screens'
os.makedirs(out_dir, exist_ok=True)

with open(input_file, 'r') as f:
    data = json.load(f)

for screen in data.get('screens', []):
    title = screen.get('title', 'untitled').replace('/', '_').replace('\\', '_')
    screen_id = screen.get('name', '').split('/')[-1]
    html_code = screen.get('htmlCode', {})
    
    if not html_code or not html_code.get('downloadUrl'):
        print(f"Skipping screen without code: {title} ({screen_id})")
        continue
        
    url = html_code.get('downloadUrl')
    mime_type = html_code.get('mimeType', 'text/html')
    ext = 'html' if 'html' in mime_type else 'md' if 'markdown' in mime_type else 'txt'
    
    out_path = os.path.join(out_dir, f"{screen_id}_{title}.{ext}")
    print(f"Downloading {title} to {out_path}...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            content = response.read()
            with open(out_path, 'wb') as out_f:
                out_f.write(content)
    except Exception as e:
        print(f"Failed to download {title}: {e}")

print("Done downloading screens!")
