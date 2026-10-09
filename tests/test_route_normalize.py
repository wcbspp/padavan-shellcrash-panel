import json,subprocess,unittest
from pathlib import Path
SCRIPT=Path(__file__).resolve().parents[1]/'payload/starts/route_normalize.awk'
class RouteNormalizeTests(unittest.TestCase):
 def apply(self,c):
  raw='{\n'+',\n'.join(json.dumps(k)+':'+json.dumps(v,separators=(',',':'))for k,v in c.items())+'\n}\n'
  r=subprocess.run(['awk','-f',str(SCRIPT)],input=raw,capture_output=True,text=True)
  self.assertEqual(r.returncode,0,r.stderr);return r.stdout,json.loads(r.stdout)
 def test_old_profile_adds_domain_route_and_local_library(self):
  text,c=self.apply({'route':{'rules':[{'ip_is_private':True,'outbound':'direct'}],'final':'proxy-main'}})
  self.assertEqual(c['route']['rules'][0],{'rule_set':['cn'],'outbound':'direct'});self.assertEqual(c['route']['rule_set'][0]['path'],'/tmp/ShellCrash/ruleset/cn.srs')
 def test_current_profile_is_idempotent(self):
  a,c=self.apply({'route':{'rules':[]}});b,d=self.apply(c);self.assertEqual(a,b);self.assertEqual(len(d['route']['rule_set']),1)
 def test_other_library_preserved(self):
  _,c=self.apply({'route':{'rules':[],'rule_set':[{'tag':'private','type':'local','path':'/tmp/private.srs'}]}});self.assertEqual([r['tag']for r in c['route']['rule_set']],['cn','private'])
 def test_existing_cn_declaration_not_duplicated(self):
  _,c=self.apply({'route':{'rules':[],'rule_set':[{'tag':'cn','type':'local','path':'/tmp/ShellCrash/ruleset/cn.srs'}]}});self.assertEqual(len(c['route']['rule_set']),1)
 def test_noncanonical_layout_refused(self):
  r=subprocess.run(['awk','-f',str(SCRIPT)],input='{"route":{"rules":[]}}',capture_output=True,text=True);self.assertNotEqual(r.returncode,0)
if __name__=='__main__':unittest.main()
