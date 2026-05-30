import subprocess
import json

res = subprocess.run(['/home/vimal-babu/.local/share/onyxcore/bin/gallery-dl', '--cookies-from-browser', 'firefox', '-j', 'https://www.instagram.com/reel/C-5_7Huvl6b/'], capture_output=True, text=True)

url = None
for line in res.stdout.splitlines():
    if line.strip():
        try:
            j = json.loads(line)
            if isinstance(j, list) and len(j) > 1:
                data = j[1]
                if isinstance(data, dict):
                    continue
                if isinstance(data, str) and data.startswith('http'):
                    url = data
                    break
        except Exception:
            pass

if url:
    print(f"URL: {url[:50]}...")
    print("Trying curl with empty User-Agent:")
    subprocess.run(['curl', '-sI', url])
    print("Trying curl with Firefox User-Agent:")
    subprocess.run(['curl', '-sI', '-A', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36', url])
else:
    print("URL not found")
