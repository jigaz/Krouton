#!/bin/bash
# Mutation spot-check: each line breaks one protocol rule, runs the gate, and restores the file.
# Every mutation must print "caught". "MISSED" means a rule has no check guarding it.
# (The "resend everything" mutant is equivalent: the pump already skips acknowledged extents.)
set -u
cd "$(dirname "$0")/.."
run() { # file, from, to, label
  cp "$1" "$1.mutbak"
  python3 -c "import sys;p,a,b=sys.argv[1:4];s=open(p).read();assert a in s,('pattern missing',a);open(p,'w').write(s.replace(a,b,1))" "$1" "$2" "$3" || { echo "SKIP (pattern) $4"; return; }
  out=$(cargo run -q -p spoold-verify 2>&1); code=$?
  fails=$(echo "$out" | grep -o "[0-9]* failed" | head -1)
  if [ $code -ne 0 ]; then echo "caught   $4  ($fails)"; else echo "MISSED   $4"; fi
  mv "$1.mutbak" "$1"
}
P=crates/spoold-proto/src
run $P/manifest.rs "[only] => *only," "[only] => Sha256::digest(&[&[0x01], only, only])," "Merkle: duplicate odd node instead of promoting"
run $P/manifest.rs "*byte |= 1 << (index % 8);" "*byte |= 0x80 >> (index % 8);" "Bitmap MSB-first"
run $P/manifest.rs "if Sha256::digest(&[body]).get(..8) != Some(check) {" "if false {" "Journal: skip check bytes"
run $P/frame.rs "            (12, &self.first_lba.to_be_bytes())," "            (12, &self.first_lba.to_le_bytes())," "Frame: little-endian LBA"
run $P/frame.rs "if payload_length > MAX_PAYLOAD {" "if false {" "Frame: no max payload"
run $P/pipeline.rs "&& leaf_digest(&frame.payload) == *expected" "" "Receiver: trust header digest"
run $P/pipeline.rs "if self.in_flight.remove(&index) {" "if true { self.in_flight.remove(&index);" "Sender: accept stray acks"
run $P/pipeline.rs "self.pending = remote.missing().into();" "self.pending = (0..self.manifest.extent_count()).collect();" "Sender: resend everything on resume"
run $P/lease.rs "if lease.fencing_token != token {" "if false {" "Lease: ignore fencing token"
run $P/lease.rs "lease.phase == LeasePhase::Burning || " "" "Lease: burning leases expire"
run $P/endpoint.rs '("fe80::/10", AddressClass::LinkLocal),' '("fe80::/16", AddressClass::LinkLocal),' "Endpoint: fe80::/16 instead of /10"
run $P/endpoint.rs "            && let Some(v4) = v6.to_ipv4_mapped()" "            && let Some(v4) = None::<std::net::Ipv4Addr>" "Endpoint: no IPv4-mapped unwrap"
run $P/cutover.rs "pub const CONFIDENCE_Z: f64 = 2.33;" "pub const CONFIDENCE_Z: f64 = 0.0;" "Cutover: trust the mean"
run $P/identity.rs "base32_lower(digest.get(..16).unwrap_or(&[]))" "base32_lower(digest.get(..15).unwrap_or(&[]))" "Node ID: 15 bytes"
run $P/telemetry.rs "if existing.phase.is_terminal() && !sample.phase.is_terminal() => return," "if false => return," "Telemetry: terminal not sticky"
run $P/sha256.rs "s0.wrapping_add(maj)" "s0.wrapping_add(maj).wrapping_add(1)" "SHA-256 round function"
