"""Independent expectations for deterministic native test programs."""
import hashlib

MARKERS = {
    'foundation': '4294967295\n0\n7\n',
    'budget': 'budget-balanced\n',
    'contracts': '\n'.join(['add-zero','add-max','add-overflow','sub-zero','sub-underflow',
        'mul-zero','mul-max','mul-edge','mul-overflow','byte-255','invalid-byte','invalid-byte',
        'empty-capacity','one-capacity','round-capacity','max-capacity','capacity-over',
        'cumulative-not-reset','zero-live-none','zero-live-none','zero-live-none'])+'\n',
    'cursors': 'cursor-balanced\n'*8,
    'ranges': '\n'.join(['range-checked','range-checked','range-rejected','range-rejected',
        'range-checked','range-checked','range-rejected','range-rejected','range-rejected','range-rejected',
        'zero-at-end','take-rejected','take-rejected','take-rejected','cursor-rejected','cursor-rejected',
        'truncation-rejected','remaining-checked'])+'\n',
    'scalar_budget': 'scalar-budget-balanced\n'*8,
    'codec_pending': 'pending-balanced\n'*4,
    'codec_splits': 'split-balanced\n'*15,
    'sha_errors': 'sha-error-unchanged\nsha-error-unchanged\nsha-update-work-prefix-resume-abc\nsha-update-work-prefix-resume-abc\nsha-final-live-refusal-none-retry-abc\nsha-final-initialization-refusal-none-retry-abc\nsha-final-writes-refusal-some-zero-output-retry-abc\nsha-final-exact-neighbor-abc\nsha-errors-ok\n',
}


def capacity(length):
    return 1 << (max(1,length)-1).bit_length()


def memory_expectation(count,length,cycles):
    charge = max(65536,16*capacity(length))+4096
    held = min(count,(268435456-65536)//charge)
    live = 65536+held*charge
    checksum = held*(sum(range(256))*(length//256)+sum(range(length%256)))
    work = cycles*held*(capacity(length)+2*length)
    lines = []
    for index in range(cycles):
        lines.append('previous-sum='+str(checksum if index else 0))
        if held == count: lines.append('allocation-complete')
        else: lines.extend(['allocation-rejected','4',str(live),str(charge)])
        lines.append('live='+str(live))
    lines.extend(['sum='+str(checksum if cycles else 0),'work='+str(work),'balanced'])
    return '\n'.join(lines)+'\n', live if cycles else 65536


def sha_expected(byte,total):
    digest = hashlib.sha256()
    chunk = bytes([byte])*65536
    for _ in range(total//65536): digest.update(chunk)
    digest.update(chunk[:total%65536])
    return digest.digest()


def digest_output(output):
    lines = output.splitlines()
    if len(lines)!=33 or lines[-1]!='done': raise AssertionError('SHA digest framing')
    return bytes(int(value) for value in lines[:-1])


def verify_output(name,args,stdout):
    if name in MARKERS:
        if stdout != MARKERS[name]: raise AssertionError(name+' completion markers differ')
    elif name == 'memory':
        if stdout != memory_expectation(*map(int,args))[0]: raise AssertionError('memory lifecycle/cost/content differs')
    elif name == 'roundtrip':
        length,cycles=map(int,args)
        expected=f'live=codec-source-scalars-output\nwork={3*capacity(length)+length+5*length*cycles}\nbalanced\n'
        if stdout != expected: raise AssertionError('codec stream cost/content differs')
    elif name == 'sha':
        byte,total,chunk=map(int,args)
        if digest_output(stdout)!=sha_expected(byte,total): raise AssertionError('SHA oracle mismatch')
    elif name == 'sha_vectors':
        messages=[b'abc',b'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
                  b'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu']
        constants=['ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
                   '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
                   'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1']
        lines=stdout.splitlines()
        if len(lines)!=99: raise AssertionError('NIST vector framing')
        for index,(message,constant) in enumerate(zip(messages,constants)):
            actual=digest_output('\n'.join(lines[index*33:(index+1)*33])+'\n')
            if actual.hex()!=constant or actual!=hashlib.sha256(message).digest(): raise AssertionError('NIST vector mismatch')
    else:
        raise AssertionError('no independent completion expectation for '+name)


def check_observation(row):
    if row['exit']!=0 or row['docker_client_exit']!=0 or row['timed_out'] or row['external_kill'] or row['oom_killed'] or row['stderr']:
        raise AssertionError('native program failed')
    if row['limits'] != {'memory.max':'1073741824','memory.swap.max':'0'}:
        raise AssertionError('resource ceiling not proven')
    if row['ready']['uid']==0 or row['native_result'] is None or row['final_cgroup'] is None:
        raise AssertionError('native identity/final resource record missing')
    if row['native_result']['exit']!=0 or row['native_result']['signal'] is not None:
        raise AssertionError('native exit not successful')
    before,after=row['events_before'],row['final_cgroup']['events']
    if any(after[k]!=before[k] for k in ['oom','oom_kill','max']):
        raise AssertionError('memory ceiling was hit')
    if row['final_cgroup']['memory_peak']>=1073741824:
        raise AssertionError('1 GiB memory ceiling reached')

MARKERS.update({'buffers': 'buffer-capacity-boundary\nbuffer-capacity-boundary\nbuffer-capacity-boundary\nbuffer-empty-minimum-capacity\nbuffer-new-preflight\nbuffer-bounds-invalid-bytes-reuse\nbuffer-new-preflight\nbuffer-work-failure-preserves-content\nbuffer-copy-distinct-owner-two-visits\nbuffer-copy-partial-work-edge\nbuffer-copy-partial-work-edge\nbuffer-copy-partial-work-edge\nbuffer-copy-partial-work-edge\nbuffer-copy-partial-work-edge\nbuffer-copy-partial-work-edge\nbuffer-copy-allocation-rejected\nbuffers-ok\n', 'hex_format': 'hex-32-raw-to-64-lowercase-ascii\nhex-non32-preflight-no-allocation\nhex-non32-preflight-no-allocation\nhex-non32-preflight-no-allocation\nhex-non32-preflight-no-allocation\nhex-partial-owner-content-work\nhex-partial-owner-content-work\nhex-partial-owner-content-work\nhex-partial-owner-content-work\nhex-format-ok\n', 'budget_edges': 'budget-consumable-exact-plus-one-preserved\nbudget-consumable-exact-plus-one-preserved\nbudget-consumable-exact-plus-one-preserved\nbudget-consumable-exact-plus-one-preserved\nbudget-consumable-exact-plus-one-preserved\nbudget-live-exact-plus-one-preserved\nbudget-overflow-preserves-existing-ticket\nbudget-multidimension-atomic-no-refund\nbudget-profile-overflow-rejected\nbudget-profile-overflow-rejected\nbudget-profile-overflow-rejected\nbudget-profile-overflow-rejected\nbudget-profile-overflow-rejected\nbudget-profile-overflow-rejected\nbudget-edges-ok\n'})
