import requests
import json
import tempfile
import subprocess
import os
import hashlib
from typing import Dict, Optional
from datetime import datetime
import base64

class GitHubBranchInfo:
    def __init__(self, owner: str, repo: str, token: Optional[str] = None):
        self.owner = owner
        self.repo = repo
        self.headers = {}
        if token:
            self.headers["Authorization"] = f"token {token}"

    def calculate_sha256(self, temp_dir: str) -> str:
        """计算目录的 sha256 并返回正确格式"""
        files_to_hash = []
        for root, _, files in os.walk(temp_dir):
            if '.git' in root:
                continue
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, temp_dir)
                files_to_hash.append(rel_path)

        files_to_hash.sort()
        hasher = hashlib.sha256()

        for rel_path in files_to_hash:
            file_path = os.path.join(temp_dir, rel_path)
            hasher.update(rel_path.replace('\\', '/').encode())
            with open(file_path, 'rb') as f:
                while chunk := f.read(8192):
                    hasher.update(chunk)

        # 转换为 base64 并格式化
        digest = base64.b64encode(hasher.digest()).decode('utf-8')
        return f"sha256-{digest}"

    def get_branch_info(self, branch: str) -> Dict:
        """获取指定分支的信息，包含 hash 和 rev"""
        url = f"https://api.github.com/repos/{self.owner}/{self.repo}/branches/{branch}"
        response = requests.get(url, headers=self.headers)

        if response.status_code == 200:
            data = response.json()
            commit_sha = data['commit']['sha']

            with tempfile.TemporaryDirectory() as temp_dir:
                clone_url = f"https://github.com/{self.owner}/{self.repo}.git"
                try:
                    subprocess.run(
                        ["git", "clone", "--quiet", "--branch", branch, "--single-branch", clone_url, temp_dir],
                        check=True, capture_output=True
                    )
                    subprocess.run(
                        ["git", "checkout", "--quiet", commit_sha],
                        cwd=temp_dir, check=True, capture_output=True
                    )
                    subprocess.run(
                        ["git", "clean", "-fdx"],
                        cwd=temp_dir, check=True, capture_output=True
                    )

                    sha256_hash = self.calculate_sha256(temp_dir)

                    return {
                        "hash": sha256_hash,
                        "rev": commit_sha
                    }
                except subprocess.CalledProcessError as e:
                    print(f"Error processing branch {branch}: {str(e)}")
                    return None
        return None

def save_to_json(data: Dict, filename: str):
    """保存数据到 JSON 文件"""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

def main():
    owner = "precice"
    repo = "openfoam-adapter"

    branches = [
        "develop",
        "general-read-write",
        "master",
        "release-v1.3.0",
        "write-PG-volume-coupling",
        "fix-uvol",
        "OpenFOAM10",
        "OpenFOAM9",
        "OpenFOAM8",
        "OpenFOAM7",
        "OpenFOAM6",
        "OpenFOAM5",
        "OpenFOAM4",
        "foam-extend",
        "OpenFOAMdev",
        "OpenFOAMv1806",
        "SWE-interFoam",
        "FF-OF7"
    ]

    github_info = GitHubBranchInfo(owner, repo)
    branches_info = {}

    for branch in branches:
        print(f"Processing branch: {branch}")
        info = github_info.get_branch_info(branch)
        if info:
            branches_info[branch] = info
            print(f"Successfully processed {branch}")
            print(f"Hash: {info['hash']}")
            print(f"Rev: {info['rev']}\n")
        else:
            print(f"Warning: Could not process branch {branch}\n")

    json_filename = "openfoam_versions.json"
    save_to_json(branches_info, json_filename)
    print(f"\nResults saved to {json_filename}")
    print(f"\nProcessed {len(branches_info)} out of {len(branches)} branches successfully")

if __name__ == "__main__":
    main()
