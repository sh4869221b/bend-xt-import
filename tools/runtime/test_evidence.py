"""Regression checks for stale-build and truncated-suite false certification."""
import json
import contextlib
import io
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import experiment
import measure
from case_spec import expected, validate
from integrity import digest, inputs


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        for name in ['tools/runtime','tests/runtime','build','.github/workflows']:
            (self.root/name).mkdir(parents=True)
        for name in ['sources.lock','.github/workflows/runtime-probes.yml','tools/runtime/build_probes.py']:
            (self.root/name).write_text('fixture')
        for name in ['sample','exclusive_race','fault_inject.so']:
            (self.root/'build'/name).write_bytes(name.encode())
        self.manifest={'complete':True,'inputs':inputs(self.root),
            'probes':[{'probe':'sample','binary_sha256':digest(self.root/'build/sample')}],
            'race_sha256':digest(self.root/'build/exclusive_race'),
            'interposer_sha256':digest(self.root/'build/fault_inject.so')}
        self.write_manifest()
        self.addCleanup(patch.stopall)
        patch.object(experiment,'ROOT',self.root).start()

    def write_manifest(self):
        (self.root/'build/build.json').write_text(json.dumps(self.manifest))

    def test_matching_build(self):
        self.assertIn('sample',experiment.verified_build())

    def test_changed_lock(self):
        (self.root/'sources.lock').write_text('different compiler')
        with self.assertRaises(RuntimeError):experiment.verified_build()

    def test_changed_recipe(self):
        (self.root/'tools/runtime/build_probes.py').write_text('different compiler invocation')
        with self.assertRaises(RuntimeError):experiment.verified_build()

    def test_changed_binary(self):
        (self.root/'build/sample').write_bytes(b'wrong')
        with self.assertRaises(RuntimeError):experiment.verified_build()

    def test_partial_build(self):
        self.manifest['complete']=False;self.write_manifest()
        with self.assertRaises(RuntimeError):experiment.verified_build()

    def test_failed_build_without_manifest(self):
        (self.root/'build/build.json').unlink()
        with self.assertRaises(FileNotFoundError):experiment.verified_build()

    def suite(self):
        return {'complete':True,'group':'all','execution_inputs':inputs(self.root),
                'cases':[{'case':n,'result':'pass'} for n in expected('api','all')]}

    def test_matching_suite(self):
        validate(self.suite(),'api','all',inputs(self.root))

    def test_prefix_cannot_be_complete(self):
        data=self.suite();data['cases']=data['cases'][:1]
        with self.assertRaises(ValueError):validate(data,'api','all',inputs(self.root))

    def test_no_completion_marker(self):
        data=self.suite();data.pop('complete')
        with self.assertRaises(ValueError):validate(data,'api','all',inputs(self.root))

    def test_execution_snapshot_mismatch(self):
        data=self.suite();(self.root/'sources.lock').write_text('new')
        with self.assertRaises(ValueError):validate(data,'api','all',inputs(self.root))

    def test_failed_or_duplicate_case(self):
        for mutation in ['fail','duplicate']:
            data=self.suite()
            if mutation=='fail':data['cases'][0]['result']='fail'
            else:data['cases'][-1]=data['cases'][0]
            with self.assertRaises(ValueError):validate(data,'api','all',inputs(self.root))


    def test_resource_inventory_finalization(self):
        # Native behavior is tested separately. Exercise both runner control paths
        # without Docker, including the completion/inventory call after the loop.
        result={'exit':0,'stdout':'','timed_out':False,'oom_killed':False,
                'external_kill':False,'samples':[],'native_result':None}
        for group in ['budget','shapes']:
            with patch.object(measure,'ROOT',self.root), \
                 patch.object(measure,'run_probe',return_value=(result,self.root/'runs/case')), \
                 patch.object(measure,'assert_equal'), \
                 patch.object(sys,'argv',['measure.py','--group',group]), \
                 contextlib.redirect_stdout(io.StringIO()):
                measure.main()
            data=json.loads((self.root/('runs/measure-'+group+'.json')).read_text())
            validate(data,'resource',group,inputs(self.root))

    def test_hard_stop_invalidates_previous_suite(self):
        module_dir=Path(__file__).resolve().parent
        for module,group,name in [('run_probes','io','suite-io.json'),('measure','budget','measure-budget.json')]:
            path=self.root/'runs'/name
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps({'complete':True,'old':True}))
            code="""import os,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
m=__import__(sys.argv[2])
m.ROOT=Path(sys.argv[3])
m.run_probe=lambda *a,**k:os._exit(91)
sys.argv=[sys.argv[2]+'.py','--group',sys.argv[4]]
m.main()
"""
            run=subprocess.run([sys.executable,'-c',code,str(module_dir),module,str(self.root),group],capture_output=True,timeout=10)
            self.assertEqual(run.returncode,91,run.stderr)
            data=json.loads(path.read_text())
            self.assertIs(data['complete'],False)
            self.assertNotIn('old',data)

if __name__=='__main__':unittest.main()
