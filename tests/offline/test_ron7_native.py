"""Optional fixed-source native tests. Success includes confirmed policy gaps."""
import hashlib
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest

PIN = "08202453b54c2284df27c9f188f66c2b2fb0f92e"
SOURCE = os.environ.get("ELEAFER_RON7_SOURCE")


@unittest.skipUnless(SOURCE, "set ELEAFER_RON7_SOURCE to the fixed Ron7 checkout")
class Ron7Native(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(SOURCE).resolve()
        head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        if head != PIN:
            raise ValueError("wrong Ron7 commit")
        for path in ("src/pufflimit.c", "src/atomizer.c", "inc/pufflimit.h", "src/meusbd.c", "src/dataflash.c"):
            expected = subprocess.check_output(["git", "-C", str(root), "show", PIN+":"+path])
            if hashlib.sha256(expected).digest() != hashlib.sha256((root/path).read_bytes()).digest():
                raise ValueError("modified Ron7 input: " + path)
        cls.temp = tempfile.TemporaryDirectory(prefix="eleafer-ron7-")
        cls.addClassCleanup(cls.temp.cleanup)
        temp = Path(cls.temp.name)
        source = (root/"src/atomizer.c").read_text()
        start = source.index("if ( FireDuration > 5 )")
        end = source.index("{", start)
        depth = 1
        while depth:
            end += 1
            depth += (source[end] == "{") - (source[end] == "}")
        (temp/"stop_accounting.inc").write_text(source[start:end+1])
        source = (root/"src/meusbd.c").read_text()
        start = source.index("if ( ! u32ParamLen % EP2_MAX_PKT_SIZE )")
        end = source.index("}", start)
        (temp/"fmc_guard.inc").write_text(source[start:end+1])
        source = (root/"src/dataflash.c").read_text()
        start = source.index("if ( dfMagic == DFMagicNumber && CalcPageCRC( DataFlash.params ) == dfCRC )")
        branch = re.match(r".*?\n\t}\n\telse\n\t{.*?\n\t}", source[start:], re.S)
        if branch is None:
            raise ValueError("missing fixed CRC fallback branch")
        (temp/"crc_fallback.inc").write_text(branch[0])
        cls.binary = temp/"native-policy"
        fixture = Path(__file__).parent/"ron7_fixture"
        subprocess.run(["cc", "-std=c99", "-Wall", "-Wextra", "-Werror",
                        "-I"+str(fixture), "-I"+str(root/"inc"), "-I"+str(temp),
                        str(root/"src/pufflimit.c"), str(fixture/"harness.c"),
                        "-o", str(cls.binary)], check=True)

    def run_scenario(self, number):
        result = subprocess.run([str(self.binary), str(number)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_untrusted_spare_budget_is_allowed(self): self.run_scenario(1)
    def test_untrusted_spent_budget_is_blocked(self): self.run_scenario(2)
    def test_disabled_limiter_bypasses_quota(self): self.run_scenario(3)
    def test_backward_clock_keeps_count_but_allows(self): self.run_scenario(4)
    def test_five_short_fires_not_counted(self): self.run_scenario(5)
    def test_six_ticks_count_and_defer_save(self): self.run_scenario(6)
    def test_loss_before_deferred_save_restores_allowance(self): self.run_scenario(7)
    def test_reset_defaults_restores_allowance(self): self.run_scenario(8)
    def test_invalid_large_count_clamps_closed(self): self.run_scenario(9)
    def test_anchored_window_rolls_count(self): self.run_scenario(10)
    def test_fmc_read_guard_accepts_unaligned_lengths(self): self.run_scenario(11)
    def test_fmc_read_guard_rejects_zero_only(self): self.run_scenario(12)
    def test_crc_mismatch_resets_allowance_counterexample(self): self.run_scenario(13)
    def test_valid_crc_keeps_exhausted_allowance(self): self.run_scenario(14)
