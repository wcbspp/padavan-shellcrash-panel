#!/usr/bin/env python3
import hashlib, importlib.util, io, tempfile, unittest, subprocess, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('receiver', ROOT/'tools/mirror_receive.py');receiver=importlib.util.module_from_spec(spec);spec.loader.exec_module(receiver)
class MirrorTests(unittest.TestCase):
 def shell_env(self,p):
  import sys
  (p/'bin').mkdir()
  f=p/'bin/base64';f.write_text('#!'+sys.executable+'\nimport base64,sys\nsys.stdout.buffer.write(base64.b64decode(open(sys.argv[-1],"rb").read()))\n');f.chmod(0o700)
  return dict(os.environ,PATH=str(p/'bin')+':'+os.environ['PATH'])
 def test_atomic_upload_and_blob_alias(self):
  with tempfile.TemporaryDirectory() as d:
   data=b'public-core-fixture';sha=hashlib.sha256(data).hexdigest();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
   self.assertEqual(receiver.receive(d,'core '+sha,io.BytesIO(data)),sha)
   self.assertEqual((Path(d)/('blob-'+blob+'.tar.gz')).read_bytes(),data)
   meta=('version=1.12.13\nsha256='+sha+'\n').encode();h=hashlib.sha256(meta).hexdigest()
   receiver.receive(d,'info '+h,io.BytesIO(meta));self.assertEqual((Path(d)/'core-info.txt').read_bytes(),meta)
 def test_failed_upload_keeps_previous_metadata(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'core-info.txt').write_text('previous')
   for cmd,data in [('core '+'0'*64,b'wrong'),('../private '+'0'*64,b'x'),('info '+hashlib.sha256(b'bad').hexdigest(),b'bad')]:
    with self.assertRaises(ValueError):receiver.receive(d,cmd,io.BytesIO(data))
   self.assertEqual((p/'core-info.txt').read_text(),'previous');self.assertEqual(list(p.glob('.incoming-*')),[])
 def test_unconfigured_probe_makes_no_download_request(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'configs').mkdir();(p/'bin').mkdir()
   stub=p/'bin/curl';stub.write_text('#!/bin/sh\ntouch "'+str(p/'unexpected-query')+'"\nexit 1\n');stub.chmod(0o700)
   result=subprocess.run(['sh','-c','C="$1"; D="$1"; . "$2"; mirror_probe', 'test', d, str(ROOT/'payload/starts/mirror_lib.sh')],env=dict(os.environ,PATH=str(p/'bin')+':'+os.environ['PATH']),capture_output=True)
   self.assertEqual(result.returncode,0,result.stderr);self.assertFalse((p/'unexpected-query').exists())
   self.assertIn('"configured":false',(p/'mirror-check.json').read_text())
 def test_settings_validation_and_save_failure_restore(self):
  import base64
  for data,expected in [('base=http://mirror.example.com/objects\ntarget=\n',0), ('base=http://mirror.example.com/objects;id\ntarget=\n',1), ('base=http://mirror.example.com/objects\ntarget=root@server.example.com:0\n',1)]:
   with tempfile.TemporaryDirectory() as d:
    p=Path(d);(p/'configs').mkdir();(p/'starts').mkdir();(p/'job').mkdir()
    (p/'starts/mirror_lib.sh').write_bytes((ROOT/'payload/starts/mirror_lib.sh').read_bytes())
    (p/'job/kind').write_text('mirror')
    encoded=base64.b64encode(data.encode()).decode();(p/'job/upload.parts').write_text('0000 '+encoded+'\n')
    script='C="$1"; D="$1/job"; act=mirrorsave; phase(){ :; }; event(){ :; }; fail(){ echo "$1"; }; save_safe(){ return 0; }; . "$2"'
    r=subprocess.run(['sh','-c',script,'test',d,str(ROOT/'payload/starts/mirror_update.sh')],env=self.shell_env(p),capture_output=True,text=True)
    self.assertEqual(r.returncode,expected,r.stdout+r.stderr)
    if expected: self.assertFalse((p/'configs/mirror.conf').exists())
    else:self.assertEqual((p/'configs/mirror.conf').read_text(),data)
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'configs').mkdir();(p/'starts').mkdir();(p/'job').mkdir()
   (p/'starts/mirror_lib.sh').write_bytes((ROOT/'payload/starts/mirror_lib.sh').read_bytes())
   before='base=http://old.example.com\ntarget=\n';(p/'configs/mirror.conf').write_text(before)
   data='base=http://new.example.com\ntarget=\n';(p/'job/kind').write_text('mirror');(p/'job/upload.parts').write_text('0000 '+base64.b64encode(data.encode()).decode()+'\n')
   script='C="$1"; D="$1/job"; act=mirrorsave; phase(){ :; }; event(){ :; }; fail(){ :; }; save_safe(){ return 1; }; . "$2"'
   r=subprocess.run(['sh','-c',script,'test',d,str(ROOT/'payload/starts/mirror_update.sh')],env=self.shell_env(p),capture_output=True)
   self.assertEqual(r.returncode,1);self.assertEqual((p/'configs/mirror.conf').read_text(),before)
 def test_size_limit_and_no_shell_commands(self):
  with tempfile.TemporaryDirectory() as d:
   data=b'x'*262145
   with self.assertRaises(ValueError):receiver.receive(d,'rules '+hashlib.sha256(data).hexdigest(),io.BytesIO(data))
   for command in ['sh','rules '+'0'*64+'; id','core ../../config.json','cn '+'A'*64]:
    with self.assertRaises(ValueError):receiver.receive(d,command,io.BytesIO(b''))
if __name__=='__main__':unittest.main(verbosity=2)
