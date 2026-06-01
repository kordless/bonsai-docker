#!/usr/bin/env python3
"""Bonsai Image 4B Endpoint Test Client

A dependency-free Python script to send generation requests to the containerized
Bonsai Image 4B endpoint running on localhost:8000.
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Query the containerized Bonsai Image 4B endpoint.")
    parser.add_argument(
        "-p", "--prompt", 
        default="A majestic bonsai tree sitting on a serene ceramic table, morning sun filtering through a window, highly detailed, photorealistic",
        help="Text prompt for image generation."
    )
    parser.add_argument("--seed", type=int, default=42, help="Seed value for deterministic generation.")
    parser.add_argument("--steps", type=int, default=4, help="Inference steps (default: 4).")
    parser.add_argument("--size", default="512x512", help="Image size as WxH (e.g., 512x512, 1024x1024).")
    parser.add_argument("-o", "--output", default="bonsai_result.png", help="Path to save the generated PNG image.")
    parser.add_argument("--host", default="localhost", help="Endpoint host address (default: localhost).")
    parser.add_argument("--port", type=int, default=8000, help="Endpoint port number (default: 8000).")
    return parser.parse_args()


def main():
    args = parse_args()
    
    # Parse width and height
    try:
        width_str, height_str = args.size.lower().split("x")
        width = int(width_str)
        height = int(height_str)
    except ValueError:
        print(f"Error: Invalid size format '{args.size}'. Must be WxH (e.g., 512x512).", file=sys.stderr)
        sys.exit(1)
        
    url = f"http://{args.host}:{args.port}/generate"
    payload = {
        "prompt": args.prompt,
        "seed": args.seed,
        "steps": args.steps,
        "width": width,
        "height": height
    }
    
    print("========================================================")
    print("      Bonsai Image 4B Endpoint Test Client")
    print("========================================================")
    print(f"Sending prompt to: {url}")
    print(f"Prompt: {args.prompt!r}")
    print(f"Config: {width}x{height} | Steps: {args.steps} | Seed: {args.seed}")
    print("--------------------------------------------------------")
    print("⏳ Processing request on GPU... (Please wait)")
    
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    
    start_time = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=600) as response:
            img_bytes = response.read()
            duration = time.perf_counter() - start_time
            
            output_path = Path(args.output).resolve()
            output_path.write_bytes(img_bytes)
            
            print("--------------------------------------------------------")
            print("🎉 Success!")
            print(f"⏱️  Inference Time : {duration:.2f} seconds")
            print(f"💾 Image Saved To : {output_path}")
            print("========================================================")
            
    except urllib.error.HTTPError as e:
        print(f"\n❌ Error: Server returned HTTP {e.code}", file=sys.stderr)
        try:
            err_body = e.read().decode("utf-8")
            print(f"Details:\n{err_body}", file=sys.stderr)
        except Exception:
            pass
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"\n❌ Connection Error: Could not reach endpoint at {url}.", file=sys.stderr)
        print("Make sure the Docker container is running (docker compose up -d) and healthy.", file=sys.stderr)
        print(f"Reason: {e.reason}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
