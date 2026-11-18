"""Verify the supervisor's termination evidence against the case recipe."""
import signal


def assert_equal(actual, expected):
    if actual != expected:
        raise AssertionError(f'expected {expected!r}, observed {actual!r}')


def checked_uint(value, maximum, field):
    if type(value) is not int or not 0 <= value <= maximum:
        raise AssertionError(f'{field} must be an integer in 0..{maximum}')
    return value


def check_termination(row, expected, termination):
    oom = termination == 'oom'
    timed_out = termination == 'timeout'
    external = termination not in {'exit', 'oom'}
    native_signal = {'exit': None, 'oom': signal.SIGKILL, 'SIGKILL': signal.SIGKILL,
                     'SIGTERM': signal.SIGTERM, 'timeout': signal.SIGKILL}[termination]
    supervised_signal = native_signal.name if external else None
    for field in ('exit', 'docker_client_exit'):
        assert_equal(checked_uint(row[field], 255, field), expected)
    for field, flag in (('oom_killed', oom), ('timed_out', timed_out), ('external_kill', external)):
        if row[field] is not flag:
            raise AssertionError(f'{field}: expected boolean {flag}, observed {row[field]!r}')
    assert_equal(row['kill_signal'], supervised_signal)

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
    assert_equal(checked_uint(native['exit'], 255, 'native_result.exit'), expected)
    if native['signal'] is not None and type(native['signal']) is not int:
        raise AssertionError('native_result.signal must be an integer or null')
    assert_equal(native['signal'], native_signal)
    status = checked_uint(native['wait_status'], 65535, 'native_result.wait_status')
    # Linux stores the normal exit code in the high byte. The only signal
    # outcomes in these recipes are SIGTERM and SIGKILL, with no core dump.
    expected_status = expected << 8 if native_signal is None else native_signal.value
    if status != expected_status:
        raise AssertionError(f'native_result.wait_status: expected {expected_status:#06x}, observed {status:#06x}')
