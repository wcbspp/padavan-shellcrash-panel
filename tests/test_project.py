#!/usr/bin/env python3
"""Offline checks: never connect to a router or run its installer."""
import json, os, re, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def run(args,**kw):return subprocess.run(args,capture_output=True,text=True,errors="backslashreplace",**kw)

class ProjectTests(unittest.TestCase):
 def test_shell_syntax(self):
  for p in ROOT.rglob('*.sh'):
   result=run(['sh','-n',str(p)])
   self.assertEqual(result.returncode,0,f'{p.relative_to(ROOT)}: {result.stderr}')
 def test_javascript_syntax(self):
  if not shutil.which('node'):self.skipTest('Node.js unavailable')
  sources=[(str(p.relative_to(ROOT)),p.read_text()) for p in (ROOT/'payload/padavan').glob('*.js')]
  html=(ROOT/'payload/ui/index.html').read_text()
  sources += [('inline',s) for s in re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>',html,re.S)]
  for label,source in sources:
   result=run(['node','--check','-'],input=source)
   self.assertEqual(result.returncode,0,f'{label}: {result.stderr}')
 def profile(self,nodes,cn='1.0.1.0/24\n'):
  td=tempfile.TemporaryDirectory();self.addCleanup(td.cleanup);d=Path(td.name)
  (d/'nodes.json').write_text(json.dumps({'outbounds':nodes}));(d/'cn.txt').write_text(cn)
  result=run([sys.executable,str(ROOT/'tools/prepare_profile.py'),'--input',str(d/'nodes.json'),'--output',str(d/'private.json'),'--lan-ip','192.168.1.1','--secret-file',str(d/'secret'),'--cn-list',str(d/'cn.txt')])
  return result,d
 def nodes(self):return [{'type':'anytls','tag':'香港01','server':'proxy.example.com','server_port':443,'password':'fixture-password','tls':{'enabled':True}}]
 def test_profile_groups_private_and_format(self):
  nodes=self.nodes()+[{'type':'trojan','tag':'台湾02','server':'other.example.com','server_port':443,'password':'fixture-only'}]
  result,d=self.profile(nodes);self.assertEqual(result.returncode,0,result.stderr)
  obj=json.loads((d/'private.json').read_text());secret=(d/'secret').read_text().strip()
  self.assertEqual(len(secret),48);self.assertNotIn(secret,result.stdout)
  self.assertEqual(obj['experimental']['clash_api']['secret'],secret)
  self.assertEqual(obj['outbounds'][0]['tag'],'proxy-main')
  self.assertEqual(obj['outbounds'][0]['outbounds'],['地区/香港','地区/台湾'])
  self.assertEqual(obj['outbounds'][-2:],nodes)
  self.assertRegex((d/'private.json').read_text(),r'\n"outbounds":\[')
  self.assertEqual((d/'private.json').stat().st_mode&0o777,0o600)
 def test_profile_rejects_ambiguous_nodes(self):
  for nodes in [[],self.nodes()*2,[dict(self.nodes()[0],detour='other')],[dict(self.nodes()[0],tag='proxy-main')]]:
   result,_=self.profile(nodes);self.assertNotEqual(result.returncode,0)
 def test_profile_rejects_noncanonical_cidr(self):
  result,_=self.profile(self.nodes(),'1.0.1.7/24\n');self.assertNotEqual(result.returncode,0)
 def test_filter_compilation(self):
  source='example.com\n+.example.net\n*.example.org\nstun.*.*\n#comment\n'
  result=run(['awk','-f',str(ROOT/'payload/starts/filter_compile.awk')],input=source)
  self.assertEqual(result.returncode,0);obj=json.loads(result.stdout)
  self.assertEqual(obj['domain'],['example.com']);self.assertEqual(obj['domain_suffix'],['example.net'])
  self.assertTrue(re.match(obj['domain_regex'][0],'one.example.org'));self.assertFalse(re.match(obj['domain_regex'][0],'two.one.example.org'))
  result=run(['awk','-f',str(ROOT/'payload/starts/filter_compile.awk')],input='geosite:category-games\n');self.assertNotEqual(result.returncode,0)
 def test_shipped_filter_valid(self):
  result=run(['awk','-f',str(ROOT/'payload/starts/filter_compile.awk'),str(ROOT/'examples/fake_ip_filter.list')]);self.assertEqual(result.returncode,0);json.loads(result.stdout)
 def test_memory_thresholds_and_bounded_samples(self):
  with tempfile.TemporaryDirectory() as td:
   d=Path(td);proc=d/'proc';(proc/'net').mkdir(parents=True);(proc/'sys/net/netfilter').mkdir(parents=True)
   (proc/'net/sockstat').write_text('TCP: inuse 5 alloc 10 mem 3\nUDP: inuse 2 mem 4\n');(proc/'sys/net/netfilter/nf_conntrack_count').write_text('200')
   (proc/'zoneinfo').write_text('Node 0, zone DMA\n pages free 400\nNode 0, zone Normal\n pages free 2000\n')
   helper=d/'helper.sh';helper.write_text((ROOT/'payload/starts/resource_health.sh').read_text().replace('/proc/',str(proc)+'/'))
   (d/'resources.csv').write_text('\n'.join(','.join(['1','1']+['0']*13) for _ in range(1500))+'\n')
   for available,pressure in [(8000,'protect'),(15000,'warning'),(24000,'normal')]:
    (proc/'meminfo').write_text(f'MemFree: 5000 kB\nMemAvailable: {available} kB\n')
    # Paths are generated internally, no untrusted shell interpolation.
    result=run(['sh','-c',f'. "{helper}"; D="{d}"; now=100; up=100; pid=77; rss=30000; resource_snapshot; printf "%s %s %s %s\\n" "$rh_pressure" "$rh_tcp" "$rh_udp" "$rh_conn"'])
    self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(result.stdout.strip(),f'{pressure} 12 16 200')
   rows=(d/'resources.csv').read_text().splitlines();self.assertLessEqual(len(rows),1441);self.assertTrue(all(len(x.split(','))==15 for x in rows))
 def test_public_payload_no_private_runtime_files(self):
  forbidden={'config.json','ShellCrash.cfg','command.env','identity.secret','authtoken.secret','sub.raw','cloud-backup-key','api-secret'}
  for p in (ROOT/'payload').rglob('*'):
   self.assertFalse(p.is_symlink());self.assertNotIn(p.name,forbidden)
   if p.is_file():self.assertLess(p.stat().st_size,1024*1024)
 def test_installer_preflight_preserves_custom_hooks(self):
  with tempfile.TemporaryDirectory() as td:
   d=Path(td);c=d/'etc/storage/ShellCrash';(c/'configs').mkdir(parents=True);(c/'task').mkdir();(c/'jsons').mkdir()
   (c/'version').write_text('1.9.4release\n');(c/'configs/ShellCrash.cfg').write_text('crashcore=singbox\n')
   (c/'jsons/config.json').write_text('"outbounds":[{"tag":"proxy-main"}]\n')
   (d/'etc/storage/chinadns').mkdir();(d/'etc/storage/chinadns/chnroute.txt').write_text('1.0.1.0/24\n')
   (d/'www').mkdir();(d/'www/state.js').write_text('');(d/'sbin').mkdir();(d/'sbin/mtd_storage.sh').write_text('')
   (d/'tmp').mkdir();(d/'opt').mkdir();shim=d/'bin';shim.mkdir()
   commands={'id':'echo 0','uname':'echo mips','nvram':'case "$2" in lan_ipaddr) echo 192.168.1.1;; ss_enable) echo 0;; esac'}
   for cmd in ['iptables','ipset','mtd_write','sha256sum']:commands[cmd]='exit 0'
   for cmd,body in commands.items():
    f=shim/cmd;f.write_text('#!/bin/sh\n'+body+'\n');f.chmod(0o700)
   script=(ROOT/'install.sh').read_text().replace('export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH','export PATH="'+str(shim)+':$PATH"')
   script=re.sub(r'/(?:etc/storage/|www/|sbin/|tmp/|opt)',lambda m:str(d)+m.group(0),script)
   f=d/'install-check.sh';f.write_text(script)
   hook=c/'task/bfstart';hook.write_text('echo user-hook\n')
   result=run(['sh',str(f),'--check']);self.assertNotEqual(result.returncode,0);self.assertIn('已有自定义钩子',result.stdout,result.stderr);self.assertEqual(hook.read_text(),'echo user-hook\n')
   hook.unlink();result=run(['sh',str(f),'--check']);self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('预检通过',result.stdout)

if __name__=='__main__':unittest.main(verbosity=2)
