#!/bin/python3
# Scientific calculator REPL — load via PYTHONSTARTUP
# Author: z4lthor <z4lthor@gmail.com>

import sys
from numpy import *

def _display_hook(value):
    if value is not None:
        if isinstance(value, (float, floating)):
            formatted = f"{value:.6f}".rstrip('0').rstrip('.')
            if formatted in ('0', '-0') and value != 0:
                formatted = f"{value:.6e}"
            print(formatted)
        else:
            print(repr(value))

sys.displayhook = _display_hook
