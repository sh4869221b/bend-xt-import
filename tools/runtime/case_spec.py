"""Expected experiment identities, independently checked when sealing evidence."""
API={
 'io':['P01-raw-argv',*[f'P01-exit-{n}' for n in [0,2,3,4,5,6,7]],'P01-die',
       *[label for n in [0,1,65535,65536,65537,131073] for label in
         ([f'P02-roundtrip-{n}']+([f'P08-chunk-{n}'] if n!=65535 else []))],
       'P04-exclusive-new','P04-concurrent-exclusive-create','P04-existing-file','P04-existing-dir','P04-symlink',
       *['P05-'+n for n in ['missing','denied','mode','invalid-byte','readonly','full']],
       'P03-position','P03-u32-max-size','P03-u32-last-byte','P03-over-u32-size'],
 'arithmetic':[*[f'P03-P07-guard-{n}' for n in range(11)],'P07-affine-array',*[f'P09-sha-primitives-{n}' for n in range(12)]],
 'faults':[label for op in ['read','pread','write','pwrite'] for label in
           ([f'P06-{op}-short-{n}' for n in [1,7,4095]]+
            [f'P06-{op}-{n}' for n in ['eintr','error','partial-error','zero']]+
            ([f'P06-{op}-enospc'] if op in ['write','pwrite'] else []))]+
          ['P06-transient-error-followed-by-success','P06-realloc-failure','P06-close-error','P06-malloc-failure']}
RESOURCE={
 'budget':['P10-'+n for n in ['selftest','reserve','over','multiply-wrap','release-underflow','allocation',
                              'allocation-reject','work','work-exhausted','work-many','work-many-exhausted']],
 'shapes':[f'M-shape-{m}-{d}-{r}' for m in range(8) for d in ([8] if m==0 else [8,16,20]) for r in range(3)],
 'stress':['M-charge-256MiB','M-charge-one-over','M-oom-small','M-oom-1GiB','M-SIGTERM','M-SIGKILL','M-timeout',
           'M-AS-is-not-RSS','M-IO-read-SIGTERM','M-IO-write-SIGKILL','M-IO-write-timeout','M-index-256MiB-raw'],
 'stream':[f'M-stream-{n}-{r}' for n in [1048576,16777216,67108864] for r in range(3)]}


def expected(kind, group):
    groups={'api':API,'resource':RESOURCE}[kind]
    return [name for values in groups.values() for name in values] if group=='all' else groups[group]


def validate(data, kind, group, snapshot):
    if data.get('complete') is not True or data.get('group')!=group or data.get('execution_inputs')!=snapshot:
        raise ValueError('incomplete, wrongly scoped, or stale suite')
    if [c['case'] for c in data['cases']]!=expected(kind,group) or any(c['result']!='pass' for c in data['cases']):
        raise ValueError('missing, duplicate, unexpected, failed or reordered case')
