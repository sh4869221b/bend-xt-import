"""Verify the supervisor's termination evidence against the case recipe."""
import os
import signal


def assert_equal(actual, expected):
    if actual != expected:
        raise AssertionError(f'expected {expected!r}, observed {actual!r}')


def check_termination(row, expected, termination):
    oom = termination == 'oom'
    timed_out = termination == 'timeout'
    external = termination not in {'exit', 'oom'}
    native_signal = {'exit': None, 'oom': signal.SIGKILL, 'SIGKILL': signal.SIGKILL,
                     'SIGTERM': signal.SIGTERM, 'timeout': signal.SIGKILL}[termination]
    supervised_signal = native_signal.name if external else None
    assert_equal(row['exit'], expected)
    assert_equal(row['docker_client_exit'], expected)
    assert_equal((row['oom_killed'], row['timed_out'], row['external_kill'], row['kill_signal']),
                 (oom, timed_out, external, supervised_signal))

    native = row['native_result']
    final = row['final_cgroup']
    if (native is None) != (final is None):
        raise AssertionError('native exit and final cgroup evidence must be captured together')

    oom_kills = [row['events_before']['oom_kill']]
    oom_kills.extend(sample['events']['oom_kill'] for sample in row['samples'])
    if final is not None:
        oom_kills.append(final['events']['oom_kill'])
    if any(type(count) is not int or count < 0 for count in oom_kills):
        raise AssertionError('invalid cgroup OOM kill counter')
    if any(previous > current for previous, current in zip(oom_kills, oom_kills[1:])):
        raise AssertionError('cgroup OOM kill counter decreased')
    if (oom_kills[-1] > oom_kills[0]) != oom:
        raise AssertionError('cgroup OOM kill evidence differs from expected termination')

    if native is None:
        # SIGKILL can stop the wait4 helper before it writes a result.
        if native_signal != signal.SIGKILL:
            raise AssertionError('native exit evidence is missing')
        return
    assert_equal(native['exit'], expected)
    assert_equal(native['signal'], native_signal)
    wait_exit = expected if native_signal is None else -native_signal
    assert_equal(os.waitstatus_to_exitcode(native['wait_status']), wait_exit)
