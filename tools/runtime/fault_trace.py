"""Validate the event sequence emitted by the pinned test interposer."""
from itertools import groupby
import re


LINE = re.compile(r'([a-z]+) ([A-Za-z-]+) call=([0-9]+) bytes=([0-9]+)')
IO_OPERATIONS = {'read', 'pread', 'write', 'pwrite'}


def check_fault_trace(trace, fault):
    operation = fault['OP']
    mode = fault['MODE']
    split = int(fault.get('SPLIT', 7))

    def require(valid):
        if not valid:
            raise AssertionError(f'{operation}/{mode}: fault trace does not prove the requested injection')

    events = []
    for line in trace.splitlines():
        match = LINE.fullmatch(line)
        require(match is not None and match[1] == operation)
        events.append((int(match[3]), match[2], int(match[4])))
    require(len(events) >= 2 and events[0] == (0, 'armed', split))

    special = {'close': ('EIO-after-close', 0), 'malloc': ('ENOMEM', 8193), 'realloc': ('ENOMEM', 128)}
    if operation in special:
        event, size = special[operation]
        require(mode == 'error' and events[1:] == [(1, event, size)])
        return
    require(operation in IO_OPERATIONS)

    calls = []
    for number, records in groupby(events[1:], key=lambda event: event[0]):
        require(number == len(calls) + 1)
        calls.append([(event, size) for _, event, size in records])
    names = [tuple(event for event, _ in call) for call in calls]
    if mode == 'short':
        require(len(calls) >= 2 and names[0] == ('request', 'short'))
        require(all(name in {('request', 'short'), ('request', 'unchanged')} for name in names))
    else:
        sequences = {
            'eintr': [('EINTR',), ('real',)],
            'error': [('EIO',)],
            'zero': [('zero',)],
            'partial-error': [('request', 'short'), ('EIO',)],
            'transient-error': [('request', 'short'), ('EIO',), ('real',)],
            'enospc': [('request', 'short'), ('ENOSPC',)],
            'stall': [('request', 'short'), ('stall',)],
        }
        require(mode in sequences)
        prefix = sequences[mode]
        require(names[:len(prefix)] == prefix)
        tail = names[len(prefix):]
        if mode in {'eintr', 'transient-error'}:
            require(all(name == ('real',) for name in tail))
        else:
            require(not tail)

    for call, name in zip(calls, names):
        if name[0] == 'request':
            requested = call[0][1]
            require(call[1] == ('short' if requested > split else 'unchanged', min(requested, split)))
    if mode == 'eintr':
        require(calls[1][0][1] == calls[0][0][1])
    if mode in {'partial-error', 'transient-error', 'enospc', 'stall'}:
        require(calls[1][0][1] == calls[0][0][1] - split)
