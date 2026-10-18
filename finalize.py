"""CI metadata only; no wheel import or native initialization."""
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from verify_wheel import verify

def main():
    root=Path(__file__).resolve().parent
    policy=json.loads((root/'build-policy.json').read_text())
    if os.environ.get('GITHUB_REPOSITORY')!=policy['repository']:
        raise ValueError('CONTEXT_REJECTED')
    wheels=list((root/'dist').glob('*.whl'))
    if len(wheels)!=1 or len(list((root/'dist').iterdir()))!=1:
        raise ValueError('ARTIFACT_COUNT_REJECTED')
    wheel=wheels[0]
    if not wheel.name.endswith('-cp311-cp311-win_amd64.whl'):
        raise ValueError('ABI_REJECTED')
    digest=hashlib.sha256(wheel.read_bytes()).hexdigest()
    verify(wheel.read_bytes(),digest)
    record={
        'source_commit':policy['source_commit'], 'source_repository':policy['source_repository'],
        'submodules':policy['submodules'], 'python':sys.version.split()[0],
        'msvc_toolset':policy['msvc_toolset'], 'windows_sdk':policy['windows_sdk'],
        'runner_image':os.environ.get('ImageVersion','UNAVAILABLE'),
        'workflow_commit':os.environ.get('GITHUB_SHA'), 'run_id':os.environ.get('GITHUB_RUN_ID'),
        'run_attempt':os.environ.get('GITHUB_RUN_ATTEMPT'),
        'wheel':wheel.name,'sha256':digest,
        'build_lock_sha256':hashlib.sha256((root/'build-requirements.lock').read_bytes()).hexdigest(),
        'build_packages':sorted(d.metadata['Name']+'=='+d.version for d in importlib.metadata.distributions()),
        'native_runtime_safety':'UNVERIFIED', 'local_engine_execution':'NOT_PERFORMED'
    }
    (root/'dist'/'provenance.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    (root/'dist'/'SHA256SUMS').write_text(digest+'  '+wheel.name+'\n',encoding='ascii')

if __name__=='__main__':
    try:main()
    except Exception:raise SystemExit('ARTIFACT_VALIDATION_FAILED') from None
