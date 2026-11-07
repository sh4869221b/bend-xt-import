"""Mandatory inventories; acceptance never treats selected/absent cases as success."""
ENTRYPOINTS = {
    'budget','budget_edges','buffers','codec_pending','codec_splits','codecs','contracts','cursors',
    'foundation','hex_format','memory','ranges','roundtrip','scalar_budget','sha','sha_errors','sha_vectors',
}
OWNERS = {'array','budget','reservation','bytes','scalar','sha','source','window'}


def functional_cases():
    # The test program asserts each field/content; the runner also requires its
    # explicit completion markers. Oracles are independently checked below.
    return [
        ('foundation', []), ('budget', []), ('contracts', []), ('cursors', []), ('ranges', []),
        ('scalar_budget', []), ('codec_pending', []), ('codec_splits', []), ('sha_errors', []),
        ('buffers', []), ('budget_edges', []), ('hex_format', []), ('sha_vectors', []),
        ('memory', ['3','3','3']), ('roundtrip', ['257','3']),
    ]


def resource_cases():
    cases = []
    def add(group, name, args):
        for repeat in range(3):
            cases.append({'group':group,'probe':name,'args':[str(x) for x in args],'repeat':repeat})
    add('baseline-bytes','memory',[0,0,0])
    add('baseline-sha','sha',[97,0,1])
    add('baseline-codec','roundtrip',[0,0])
    for count in [1,2,3]:
        for length in [0,1,255,257,65535,65536]:
            add(f'bytes-{count}-{length}','memory',[count,length,3])
    for count,length in [(254,65536),(255,65536),(3854,1),(3855,1)]:
        add(f'ceiling-{count}-{length}','memory',[count,length,3])
    for length in [1,257,65535,65536]:
        add(f'codec-shape-{length}','roundtrip',[length,3])
    for mib in [1,16,64]:
        add(f'sha-stream-{mib}','sha',[97,mib*1048576,65536])
        add(f'codec-stream-{mib}','roundtrip',[65536,mib*16])
    for name in ['contracts','scalar_budget','sha_errors']:
        add('error-lifecycles-'+name,name,[])
    return cases


def key(probe,args,repeat=None):
    return probe + ':' + ','.join(map(str,args)) + ('' if repeat is None else ':'+str(repeat))
