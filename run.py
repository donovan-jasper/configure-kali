import subprocess
import os

script1 = "ohmyzsh.sh"
script2 = "p10k.sh"

def run_script(script_path, wait=True):
    if os.path.exists(script_path):
        print(f"Running script: {script_path}")
        # Use subprocess to spawn a new terminal and execute the script
        process = subprocess.Popen(['xfce4-terminal', '--hold', '-e', f"bash {script_path}"])
        if wait:
            process.wait()
    else:
        print(f"Script not found: {script_path}")

run_script(script1, wait=True)
run_script(script2, wait=False)
