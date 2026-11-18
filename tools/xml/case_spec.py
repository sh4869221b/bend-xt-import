"""Finite inventory; diagnostic probes are deliberately not acceptance cases."""
ENTRYPOINTS = {'ownership','text','input','input_errors','input_handoff',
               'input_replacement','numbers','types','driver','tokenizer','stream','positions','lifecycle'}
HELPERS = set()
OWNERS = {'reader','entry','document','finish'}
MARKERS = {
    'numbers':'numbers-ok\n','types':'67108864\n','tokenizer':'tokenizer-golden-64\n',
    'lifecycle':'lifecycle-balanced\n',
    'ownership':'ownership-balanced\n',
    'text':'text-balanced\n',
    'input':'input-splits-balanced\n',
    'input_errors':'input-errors-balanced\n',
    'input_handoff':'input-handoff-balanced\n',
    'input_replacement':'input-replacement-rejected\n',
}
