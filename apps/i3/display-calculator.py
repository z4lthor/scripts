#!/bin/python3
# Scientific calculator REPL — load via PYTHONSTARTUP
# Author: z4lthor <z4lthor@gmail.com>

import sys
import subprocess
from numpy import *

# Copy text to the X11 clipboard using xclip, detached from the parent
# process so the content persists after the REPL window is closed.
def _copy_to_clipboard(text):
    try:
        subprocess.Popen(
            ["xclip", "-selection", "clipboard"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        ).communicate(input=text.encode())
    except FileNotFoundError:
        pass

def _display_hook(value):
    if value is not None:
        if isinstance(value, (float, floating)):
            formatted = f"{value:.6f}".rstrip('0').rstrip('.')
            if formatted in ('0', '-0') and value != 0:
                formatted = f"{value:.6e}"
            print(formatted)
            _copy_to_clipboard(formatted)
        else:
            output = repr(value)
            print(output)
            _copy_to_clipboard(output)

sys.displayhook = _display_hook
