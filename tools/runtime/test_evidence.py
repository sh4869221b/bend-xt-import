"""Regression checks for stale-build and truncated-suite false certification."""
import json
import contextlib
import io
import shutil
import signal
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import experiment
import measure
import run_probes
import summarize
from case_spec import API, RESOURCE, expected, validate
from fault_trace import check_fault_trace
from integrity import digest, inputs, observation_reference


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
        result={'exit':0,'docker_client_exit':0,'stdout':'','timed_out':False,'oom_killed':False,
                'external_kill':False,'kill_signal':None,'samples':[],'events_before':{'oom_kill':0},
                'native_result':{'exit':0,'wait_status':0,'signal':None},'final_cgroup':{'events':{'oom_kill':0}}}
        for group in ['budget','shapes']:
            with patch.object(measure,'ROOT',self.root), \
                 patch.object(measure,'run_probe',return_value=(result,self.root/'runs/case')), \
                 patch.object(measure,'observation_reference',return_value={'sha256':'fixture'}), \
                 patch.object(measure,'check_result'), \
                 patch.object(sys,'argv',['measure.py','--group',group]), \
                 contextlib.redirect_stdout(io.StringIO()):
                measure.main()
            data=json.loads((self.root/('runs/measure-'+group+'.json')).read_text())
            validate(data,'resource',group,inputs(self.root))

    def case_record(self, label, probe, arguments=(), code=0, output='', **options):
        directory=self.root/'runs'/label
        directory.mkdir(parents=True,exist_ok=True)
        row={'case':label,'probe':probe,'scratch':directory.name,'binary_sha256':'binary',
             'args_base64':experiment.encoded_arguments(arguments),'options':experiment.execution_options(**options),
             'exit':code,'docker_client_exit':code,'stdout':output,'timed_out':False,'oom_killed':False,
             'external_kill':False,'kill_signal':None,'limits':{'memory.max':'1073741824','memory.swap.max':'0'},
             'samples':[],'events_before':{'oom_kill':0},'native_result':{'exit':code,'wait_status':code<<8,
             'signal':None,'maxrss_bytes':100},'final_cgroup':{'events':{'oom_kill':0}},'build_sha256':'build'}
        (directory/'observation.json').write_text(json.dumps(row))
        return {'case':label,'result':'pass',**observation_reference(self.root,directory)}

    def test_summary_rejects_swapped_cases_and_rechecks_observed_values(self):
        labels=['P01-exit-0','P01-exit-7']
        records=[self.case_record(label,'argv_exit',['exit',code],code) for label,code in zip(labels,[0,7])]
        recipes=run_probes.run_cases
        def exit_cases(group, case):
            recipes(group,lambda label,*args,**kwargs: case(label,*args,**kwargs) if label in labels else None)
        def seal(cases):
            data={'complete':True,'group':'io','execution_inputs':{},'cases':cases}
            return summarize.summarize_suite(data,'api','io',{}, {'build_sha256':'build'}, {'argv_exit':'binary'},set())

        with patch.object(summarize,'ROOT',self.root), patch.dict(API,{'io':labels}), \
             patch.object(run_probes,'run_cases',exit_cases):
            self.assertEqual([x['exit'] for x in seal(records)],[0,7])
            swapped=[{**record,**{k:other[k] for k in ['observation','sha256']}}
                     for record,other in zip(records,reversed(records))]
            with self.assertRaisesRegex(ValueError,'observation case or scratch differs'):
                seal(swapped)
            path=self.root/records[0]['observation']
            valid=json.loads(path.read_text())
            native=valid['native_result']
            mutations=[('args_base64',experiment.encoded_arguments(['exit',7]),'invocation'),
                       ('options',experiment.execution_options(rlimit_as=1),'invocation'),
                       ('binary_sha256','different','build or runner identity'),
                       ('exit',7,'expected 0, observed 7'),('stdout','wrong','expected.*observed'),
                       ('native_result',{**native,'exit':91},'expected 0, observed 91'),
                       ('native_result',{**native,'signal':signal.SIGTERM},'expected None, observed'),
                       ('native_result',{**native,'wait_status':7<<8},'expected 0, observed 7')]
            for field,value,message in mutations:
                with self.subTest(field=field):
                    path.write_text(json.dumps({**valid,field:value}))
                    with self.assertRaisesRegex(ValueError,'observation digest differs'):
                        seal(records)
                    with self.assertRaisesRegex(ValueError,message):
                        seal([{**records[0],'sha256':digest(path)},records[1]])

    def test_summary_recomputes_resource_metrics(self):
        records=[]
        def fixture(label, probe, arguments=(), expected=0, output=None):
            entry=self.case_record(label,probe,arguments,expected,output)
            row=json.loads((self.root/entry['observation']).read_text())
            records.append({**entry,'metrics':measure.summarize(row)})
        measure.run_cases('budget',fixture)
        data={'complete':True,'group':'budget','execution_inputs':{},'cases':records}
        def seal():
            return summarize.summarize_suite(data,'resource','budget',{}, {'build_sha256':'build'},
                                             {'budget_work':'binary'},set())
        with patch.object(summarize,'ROOT',self.root):
            self.assertEqual(len(seal()),len(expected('resource','budget')))
            records[0]['metrics']['memory_peak']=1
            with self.assertRaisesRegex(ValueError,'resource metrics differ'):
                seal()

    def test_resource_summary_rejects_conflicting_exit_evidence(self):
        label='P10-over'
        entry=self.case_record(label,'budget_work',['reserve',268435456,268435456,1],5)
        path=self.root/entry['observation']
        valid=json.loads(path.read_text())
        recipes=measure.run_cases
        def only_over(group, case):
            recipes(group,lambda name,*args,**kwargs: case(name,*args,**kwargs) if name==label else None)
        def seal():
            row=json.loads(path.read_text())
            case={**entry,'sha256':digest(path),'metrics':measure.summarize(row)}
            data={'complete':True,'group':'budget','execution_inputs':{},'cases':[case]}
            return summarize.summarize_suite(data,'resource','budget',{}, {'build_sha256':'build'},
                                             {'budget_work':'binary'},set())
        with patch.object(summarize,'ROOT',self.root), patch.dict(RESOURCE,{'budget':[label]}), \
             patch.object(measure,'run_cases',only_over):
            self.assertEqual(seal()[0]['exit'],5)
            for update in [{'docker_client_exit':125}, {'native_result':{**valid['native_result'],'exit':91}},
                           {'native_result':None}, {'final_cgroup':None}]:
                with self.subTest(update=update):
                    path.write_text(json.dumps({**valid,**update}))
                    with self.assertRaises(ValueError):
                        seal()

    def test_abnormal_resource_termination_uses_case_specific_evidence(self):
        for termination, sig, external in [('oom',signal.SIGKILL,False), ('SIGTERM',signal.SIGTERM,True),
                                           ('SIGKILL',signal.SIGKILL,True), ('timeout',signal.SIGKILL,True)]:
            with self.subTest(termination=termination):
                code=128+sig
                native={'exit':code,'signal':int(sig),'wait_status':int(sig)}
                row={'exit':code,'docker_client_exit':code,'native_result':native,'external_kill':external,
                     'kill_signal':sig.name if external else None,'timed_out':termination=='timeout',
                     'oom_killed':termination=='oom','events_before':{'oom_kill':0},
                     'samples':[{'events':{'oom_kill':int(termination=='oom')}}],
                     'final_cgroup':{'events':{'oom_kill':int(termination=='oom')}}}
                measure.check_termination(row,code,termination)
                missing={**row,'native_result':None,'final_cgroup':None}
                if sig==signal.SIGKILL:
                    measure.check_termination(missing,code,termination)
                else:
                    with self.assertRaises(AssertionError):
                        measure.check_termination(missing,code,termination)
                for update in [{'docker_client_exit':125}, {'native_result':{**native,'exit':91}},
                               {'native_result':{**native,'wait_status':code<<8}},
                               {'native_result':{**native,'signal':float(sig)}},
                               {'timed_out':not row['timed_out']}, {'oom_killed':not row['oom_killed']},
                               *[{field:int(row[field])} for field in ('oom_killed','timed_out','external_kill')],
                               {'native_result':None}, {'final_cgroup':None}]:
                    with self.subTest(update=update), self.assertRaises(AssertionError):
                        measure.check_termination({**row,**update},code,termination)
                bad_count=int(termination!='oom')
                with self.assertRaises(AssertionError):
                    measure.check_termination({**missing,'samples':[{'events':{'oom_kill':bad_count}}]},code,termination)

    def test_termination_evidence_requires_json_types_and_kernel_widths(self):
        observation=self.case_record('P01-exit-0','argv_exit',['exit',0])
        row=json.loads((self.root/observation['observation']).read_text())
        measure.check_termination(row,0,'exit')
        native=row['native_result']
        for field in ('exit','docker_client_exit','native_result.exit','native_result.wait_status'):
            is_native=field.startswith('native_result.')
            key=field.rsplit('.',1)[-1]
            maximum=65535 if key=='wait_status' else 255
            values=(False,True,0.0,'0',None,-1,maximum+1,1<<32)
            for value in values:
                update={'native_result':{**native,key:value}} if is_native else {key:value}
                with self.subTest(field=field,value=value), self.assertRaisesRegex(AssertionError,'must be an integer'):
                    measure.check_termination({**row,**update},0,'exit')
        for flag in ('oom_killed','timed_out','external_kill'):
            for value in (0,0.0,'false',None):
                with self.subTest(flag=flag,value=value), self.assertRaisesRegex(AssertionError,'expected boolean'):
                    measure.check_termination({**row,flag:value},0,'exit')
        for status in (0x7f,0xffff):
            with self.subTest(status=status), self.assertRaisesRegex(AssertionError,'does not encode a process exit'):
                measure.check_termination({**row,'native_result':{**native,'wait_status':status}},0,'exit')
        measure.check_termination({**row,'exit':255,'docker_client_exit':255,
                                   'native_result':{**native,'exit':255,'wait_status':255<<8}},255,'exit')

    def test_oom_counter_must_not_decrease_at_any_observation_boundary(self):
        row={'exit':137,'docker_client_exit':137,'native_result':{'exit':137,'signal':9,'wait_status':9},
             'oom_killed':True,'external_kill':False,'timed_out':False,'kill_signal':None,
             'events_before':{'oom_kill':0},'samples':[{'events':{'oom_kill':1}}],
             'final_cgroup':{'events':{'oom_kill':1}}}
        measure.check_termination(row,137,'oom')
        for update in [{'events_before':{'oom_kill':2}},
                       {'samples':row['samples']+[{'events':{'oom_kill':0}}]},
                       {'final_cgroup':{'events':{'oom_kill':0}}}]:
            with self.subTest(update=update), self.assertRaisesRegex(AssertionError,'counter decreased'):
                measure.check_termination({**row,**update},137,'oom')

    def test_close_gap_requires_close_failure(self):
        observation=self.case_record('P06-close-error','short_io',['write'],output='complete\n')
        row=json.loads((self.root/observation['observation']).read_text())
        fault={'OP':'close','MODE':'error'}
        for bad in ['read armed call=0 bytes=7\nread real call=1 bytes=8\n',
                    'close armed call=0 bytes=7\nclose real call=1 bytes=0\n',
                    'close EIO-after-close call=1 bytes=0\nclose armed call=0 bytes=7\n']:
            with self.subTest(trace=bad), self.assertRaises(AssertionError):
                run_probes.check_result({**row,'fault_trace':bad},self.root,0,'complete\n',None,fault)
        trace='close armed call=0 bytes=7\nclose EIO-after-close call=1 bytes=0\n'
        run_probes.check_result({**row,'fault_trace':trace},self.root,0,'complete\n',None,fault)

    def test_fault_modes_require_the_injection_and_any_retry_in_order(self):
        short=['request call=1 bytes=8','short call=1 bytes=7']
        cases=[
            ('read','short',short+['request call=2 bytes=1','unchanged call=2 bytes=1']),
            ('pread','eintr',['EINTR call=1 bytes=8','real call=2 bytes=8']),
            ('write','error',['EIO call=1 bytes=8']),
            ('pwrite','zero',['zero call=1 bytes=8']),
            ('pread','partial-error',short+['EIO call=2 bytes=1']),
            ('read','transient-error',short+['EIO call=2 bytes=1','real call=3 bytes=8']),
            ('pwrite','enospc',short+['ENOSPC call=2 bytes=1']),
            ('write','stall',short+['stall call=2 bytes=1']),
            ('malloc','error',['ENOMEM call=1 bytes=8193']),
            ('realloc','error',['ENOMEM call=1 bytes=128']),
        ]
        for op,mode,events in cases:
            with self.subTest(operation=op,mode=mode):
                fault={'OP':op,'MODE':mode}
                trace='\n'.join(f'{op} {line}' for line in ['armed call=0 bytes=7',*events])+'\n'
                transfer=(8,8) if mode=='short' else None
                check_fault_trace(trace,fault,short_transfer=transfer)
                with self.assertRaises(AssertionError):
                    check_fault_trace(trace.removesuffix(f'{op} {events[-1]}\n'),fault,short_transfer=transfer)
                with self.assertRaises(AssertionError):
                    check_fault_trace(trace.replace(f'\n{op} ', '\nclose ',1),fault,short_transfer=transfer)

    def test_short_read_trace_accounts_for_all_reported_bytes_and_eof(self):
        label='P06-read-short-7'
        fault={'OP':'read','MODE':'short','SPLIT':7}
        output=run_probes.byte_line(range(64))
        entry=self.case_record(label,'short_io',['read'],output=output,fault=fault)
        path=self.root/entry['observation']
        row=json.loads(path.read_text())
        trace=['read armed call=0 bytes=7']
        for index in range(11):
            trace.extend([f'read request call={index+1} bytes={8192-min(64,index*7)}',
                          f'read short call={index+1} bytes=7'])
        recipes=run_probes.run_cases
        def only_short_read(group, case):
            recipes(group,lambda name,*args,**kwargs: case(name,*args,**kwargs) if name==label else None)
        def seal(lines):
            path.write_text(json.dumps({**row,'fault_trace':'\n'.join(lines)+'\n'}))
            data={'complete':True,'group':'faults','execution_inputs':{},'cases':[{**entry,'sha256':digest(path)}]}
            return summarize.summarize_suite(data,'api','faults',{}, {'build_sha256':'build'}, {'short_io':'binary'},set())
        with patch.object(summarize,'ROOT',self.root), patch.dict(API,{'faults':[label]}), \
             patch.object(run_probes,'run_cases',only_short_read):
            self.assertEqual(seal(trace)[0]['result'],'pass')
            for incomplete in [trace[:5],trace[:-2]]:
                with self.assertRaisesRegex(ValueError,'does not account for the expected transfer'):
                    seal(incomplete)

    def test_stream_checks_expected_size_and_bytes_of_both_files(self):
        row={'timed_out':False,'oom_killed':False,'external_kill':False}
        def case(label, probe, prepare, check, **kwargs):
            if label!='M-stream-1048576-0':
                return
            source=self.root/'input.bin'
            output=self.root/'output.bin'
            source.touch()
            output.touch()
            with self.assertRaises(AssertionError):
                check(row,self.root)
            prepare(self.root)
            shutil.copyfile(source,output)
            with patch.object(measure.hashlib,'file_digest',create=True,side_effect=AssertionError('requires Python 3.11')):
                check(row,self.root)
            for path in (source,output):
                with path.open('r+b') as stream:
                    stream.write(b'wrong')
            with self.assertRaises(AssertionError):
                check(row,self.root)
        measure.run_cases('stream',case)

    def test_native_samples_preserve_missing_values(self):
        metrics=measure.summarize({'samples':[{'native_process':True,'memory_current':7,'VmHWM_bytes':8},
                                              {'native_process':False,'VmRSS_bytes':100},
                                              {'native_process':True,'VmHWM_bytes':9,'VmSize_bytes':None}]})
        self.assertIsNone(metrics['VmRSS_bytes'])
        self.assertIsNone(metrics['VmSize_bytes'])
        self.assertEqual(metrics['VmHWM_bytes'],9)
        self.assertEqual(metrics['memory_current'],7)

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
