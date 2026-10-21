"""Bounded local transport for the MoonBit example; contains no admission decisions."""
import json, pathlib, selectors, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = ROOT / '_build/native/release/build/examples/dispatcher/dispatcher.exe'


class Client:
    def __init__(self, *args):
        self.process = subprocess.Popen([str(EXE), *args], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=True, bufsize=1)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        try:
            assert self.read().get('ready'), 'dispatcher did not become ready'
        except BaseException:
            self.close()
            raise

    def read(self):
        if not self.selector.select(15):
            raise TimeoutError('dispatcher response timed out')
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('dispatcher closed unexpectedly: ' + self.process.stderr.read()[-1000:])
        return json.loads(line)

    def send(self, request):
        self.process.stdin.write(json.dumps(request, separators=(',', ':')) + '\n')
        self.process.stdin.flush()
        return self.read()

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                try:
                    self.process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=2)
        self.selector.close()
        self.process.stdout.close()
        self.process.stderr.close()

    def __enter__(self):
        return self

    def __exit__(self, *ignored):
        self.close()
