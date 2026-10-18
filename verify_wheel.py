"""Read-only structural verification; never imports wheel/native code.

Trusted SHA must come from separately verified signed provenance. This function
does not claim to establish provenance or native execution safety by itself.
"""
import base64
import csv
import hashlib
import io
from pathlib import PurePosixPath
import re
import zipfile
from email.parser import BytesParser

COMMIT='74703b034dd90a1f199f49bb70bf3b66b1728a86'
VERSION='0.1.dev251+g74703b0'

def verify(data, trusted_sha256):
    def reject():raise ValueError('WHEEL_REJECTED')
    if type(data) is not bytes or len(data)>32*1024*1024:reject()
    if type(trusted_sha256) is not str or re.fullmatch('[0-9a-f]{64}',trusted_sha256) is None:reject()
    if hashlib.sha256(data).hexdigest()!=trusted_sha256:reject()
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            names=archive.namelist()
            if len(names)!=len(set(names)) or len(names)>5000:reject()
            if sum(i.file_size for i in archive.infolist())>128*1024*1024:reject()
            for name in names:
                path=PurePosixPath(name)
                if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:reject()
                if name.endswith(('.pth','.exe','.bat','.cmd')):reject()
            metadata=[n for n in names if n.endswith('.dist-info/METADATA')]
            if len(metadata)!=1:reject()
            prefix=metadata[0].rsplit('/',1)[0]
            meta=BytesParser().parsebytes(archive.read(metadata[0]))
            if meta.get('Name')!='pyopenjtalk' or meta.get('Version')!=VERSION:reject()
            wheel=BytesParser().parsebytes(archive.read(prefix+'/WHEEL'))
            if wheel.get_all('Tag')!=['cp311-cp311-win_amd64']:reject()
            if wheel.get('Root-Is-Purelib','').lower()!='false':reject()
            record_name=prefix+'/RECORD'
            rows=list(csv.reader(io.StringIO(archive.read(record_name).decode('utf-8'))))
            if len(rows)!=len(names) or {r[0] for r in rows}!=set(names):reject()
            for row in rows:
                if len(row)!=3:reject()
                name,digest,size=row
                if name==record_name:
                    if digest or size:reject()
                    continue
                content=archive.read(name)
                expected='sha256='+base64.urlsafe_b64encode(hashlib.sha256(content).digest()).rstrip(b'=').decode('ascii')
                if digest!=expected or size!=str(len(content)):reject()
        return {'structural_check':'PASS','source_commit_expected':COMMIT,
                'provenance':'REQUIRES_SEPARATE_SIGNED_VERIFICATION','native_safety':'UNVERIFIED'}
    except Exception:
        raise ValueError('WHEEL_REJECTED') from None
