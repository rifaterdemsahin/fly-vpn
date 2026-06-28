# Fix Formula — "VPN connect fails in the UI"

A reusable formula for diagnosing and fixing a WireGuard-on-Fly.io VPN that
won't connect from the client (the WireGuard macOS app). Written from the
2026-06-28 incident where the tunnel failed after a region move to Frankfurt.

---

## The formula

```
Working VPN  =  Server stays UP            (no crash loop)
            +  Client trusts server key    (fresh keys after volume reset)
            +  Client dials right endpoint (correct public IPv4)
```

If any one term is broken, the UI shows "no handshake" / connection failure.
Diagnose in that order — server first, then keys, then endpoint.

---

## Term 1 — Server must stay UP

**Symptom:** `fly status` shows `stopped`, or `fly ssh console` returns
`app … has no started VMs`, or logs end with
`machine has reached its max restart count of 10`.

**Check:**
```bash
fly status -a <app>
fly logs -a <app> --no-tail | tail -40
```

**Root cause we hit:** an `iptables` rule in `entrypoint.sh` PostUp used the
`TCPMSS` target:
```
iptables -t mangle -A FORWARD ... -j TCPMSS --clamp-mss-to-pmtu
```
Fly's Firecracker VMs **lack the `xt_TCPMSS` kernel module**, so the rule
failed:
```
Warning: Extension TCPMSS revision 0 not supported, missing kernel module?
RULE_APPEND failed (No such file or directory): rule in chain FORWARD
[#] ip link delete dev wg0          ← wg-quick rolls the tunnel back
Main child exited normally with code: 4
```
`wg-quick` aborts and tears down the tunnel when **any** PostUp command fails,
the entrypoint exits, the machine restarts → crash loop → "no started VMs".

**Fix:** remove the TCPMSS rule. A conservative client `MTU = 1280` already
prevents path-MTU fragmentation, so the MSS clamp is redundant on Fly.
> Rule of thumb: keep PostUp to the essentials that are known to work on
> Firecracker — FORWARD accepts + NAT MASQUERADE. Anything needing an extra
> kernel module will crash-loop the box.

---

## Term 2 — Client must trust the server key

**Symptom:** server is up, but the UI still never handshakes after a redeploy.

**Root cause:** server keys live on the `/config` volume. Deleting the app or
recreating the volume (e.g. moving regions — Fly volumes are region-bound)
**regenerates the server keypair**. Every previously exported client config now
carries a stale `[Peer] PublicKey`, so the handshake is rejected.

**Fix:** after any volume/app recreation, re-pull and re-import the client
config:
```bash
scripts/get-client-config.sh mac     # writes wg-clients/mac.conf
```
Then in the WireGuard app: delete the old tunnel, import the new file, Activate.

---

## Term 3 — Client must dial the right endpoint

**Symptom:** config looks fine but `Endpoint` is wrong/garbled, e.g.
`Endpoint = │:51820`.

**Root cause:** `deploy.sh` read the public IP by `awk`-ing the human table:
```bash
fly ips list -a "$APP" | awk '/v4/{print $2}'   # ← grabs a │ box-char, not the IP
```
`fly ips list` prints a box-drawing table with color codes, so `$2` is a
separator, not the address. That garbage became the `SERVERURL` secret and
flowed into every peer's `Endpoint`.

**Fix:** parse JSON instead of the table:
```bash
PUBLIC_IP="$(fly ips list -a "$APP" --json \
  | python3 -c "import sys,json; print(next(i['Address'] for i in json.load(sys.stdin) if i.get('Type')=='v4'))")"
```
Then re-set the secret so peer configs regenerate with the real IP:
```bash
fly secrets set SERVERURL="<public-ipv4>" -a <app>
```

---

## End-to-end recovery checklist

1. `fly status` / `fly logs` → confirm the machine is **started**, not
   crash-looping. Fix `entrypoint.sh` if a PostUp command is failing.
2. If you recreated the app/volume → server key changed → re-pull client config.
3. Verify `Endpoint = <correct-public-ipv4>:51820` in the pulled `.conf`.
4. In the WireGuard app: delete old tunnel → import fresh `.conf` → Activate.
5. Expect a handshake within a few seconds. If handshake succeeds but no
   traffic flows, check server-side NAT/forwarding (MASQUERADE + `ip_forward`).

---

## Commits that applied this fix (2026-06-28)

| Commit    | Term | Change |
|-----------|------|--------|
| `f8c570e` | —    | Move VPN region to Frankfurt (`fra`) |
| `2cb25e5` | 1    | Drop TCPMSS clamp rule that crash-loops the VM |
| `e0377fb` | 3    | Parse `fly ips list` as JSON to get a valid public IP |
