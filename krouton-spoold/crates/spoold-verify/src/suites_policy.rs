// MARK: - Verify Suites S5–S8 (Leases, Cutover, Endpoint Policy & Telemetry)

use std::collections::BTreeMap;
use std::time::Duration;

use spoold_proto::cutover::{self, CutoverDecision, LinkStats, MediaClass, StoreAndForwardReason};
use spoold_proto::endpoint::{AddressClass, Cidr, Denial, EndpointPolicy, HostVerdict};
use spoold_proto::identity::{self, TxtHints};
use spoold_proto::lease::{DriveId, DriveLeaseTable, LeasePhase, LeaseRejection};
use spoold_proto::telemetry::{TelemetryConflator, TelemetryPhase, TelemetrySample};

use crate::harness::Harness;

pub fn run_policy_suites(h: &mut Harness) {
    h.suite("S5. Lease fencing & partition expiry", leases);
    h.suite("S6. Store-and-forward vs rolling cutover", cutover_policy);
    h.suite("S7. Endpoint policy (SSRF, rebinding, overlays)", endpoint_policy);
    h.suite("S8. Identity, TXT hints & telemetry conflation", identity_and_telemetry);
}

// S5
// ---------------------------------------------------------------------------------------------

fn leases(h: &mut Harness) {
    let bd = DriveId("node-a/bd-12x".to_owned());
    let (set_a, set_b) = ([0xA; 16], [0xB; 16]);
    let mut table = DriveLeaseTable::new([bd.clone()], Duration::from_secs(15), 3);
    let s = Duration::from_secs;

    let first = table.reserve(&bd, "ws-a", set_a, s(0));
    let token_a = first.as_ref().map_or(0, |l| l.fencing_token);
    h.check(token_a == (3u64 << 32) + 1, "Fencing tokens carry the boot epoch");
    h.check(
        table.reserve(&bd, "ws-b", set_b, s(1)) == Err(LeaseRejection::HeldByOther { holder: "ws-a".into() }),
        "No double claim",
    );
    h.check(
        table.reserve(&bd, "ws-a", set_a, s(2)).map(|l| l.fencing_token) == Ok(token_a),
        "Retried reserve returns the same lease",
    );
    let _ = table.heartbeat(&bd, token_a, s(10));
    h.check(table.reserve(&bd, "ws-b", set_b, s(20)).is_err(), "Heartbeat extends the lease");
    let second = table.reserve(&bd, "ws-b", set_b, s(26));
    let token_b = second.as_ref().map_or(0, |l| l.fencing_token);
    h.check(second.is_ok() && token_b != token_a, "A sleeper loses the drive after its TTL");
    h.check(
        table.commit(&bd, token_a, s(27)) == Err(LeaseRejection::StaleToken),
        "The sleeper's stale laser-on is refused",
    );
    let _ = table.commit(&bd, token_b, s(28));
    h.check(table.commit(&bd, token_b, s(29)).is_ok(), "Commit is idempotent for the current token");
    table.expire(s(10_000));
    h.check(table.lease(&bd).map(|l| l.phase) == Some(LeasePhase::Burning), "A burning lease never lapses");
    h.check(
        table.release(&bd, token_b, s(10_001)).is_ok() && table.lease(&bd).is_some(),
        "A burning drive cannot be released by the workstation",
    );
    table.finish(&bd, token_a);
    h.check(table.lease(&bd).is_some(), "finish() with a stale token is ignored");
    table.finish(&bd, token_b);
    h.check(table.lease(&bd).is_none(), "finish() with the current token frees the drive");
    let ghost = DriveId("ghost".into());
    h.check(table.reserve(&ghost, "ws-a", set_a, s(0)) == Err(LeaseRejection::UnknownDrive), "Unknown drive refused");
    let restarted = DriveLeaseTable::new([bd.clone()], Duration::from_secs(15), 4).reserve(&bd, "ws-a", set_a, s(0));
    h.check(
        restarted.map(|l| l.fencing_token).is_ok_and(|t| t > token_b),
        "Tokens after a daemon restart exceed every earlier token",
    );
}

// ---------------------------------------------------------------------------------------------
// S6
// ---------------------------------------------------------------------------------------------

fn cutover_policy(h: &mut Harness) {
    let bd25 = 25_000_000_000u64;
    let extent = 4_194_304u64;
    let plenty = 100_000_000_000u64;
    let stats = |mean: f64, sd: f64, wifi: bool| LinkStats {
        mean_bytes_per_second: mean,
        standard_deviation: sd,
        sample_count: 30,
        is_wifi: wifi,
    };
    let lead = |d: CutoverDecision| {
        if let CutoverDecision::RollingWindow { lead_bytes } = d { Some(lead_bytes) } else { None }
    };
    let bd = MediaClass::BdSingleLayer;

    h.check(
        lead(cutover::decide(bd25, bd, 6.0, &stats(110e6, 5e6, false), plenty, extent))
            .is_some_and(|b| (80_000_000..90_000_000).contains(&b)),
        "1GbE, BD 6x: laser-on after ~85 MB",
    );
    h.check(
        cutover::decide(bd25, bd, 6.0, &stats(900e6, 50e6, false), plenty, extent)
            == CutoverDecision::StoreAndForward(StoreAndForwardReason::QuickToPrestage),
        "10GbE: just pre-stage",
    );
    h.check(
        cutover::decide(bd25, bd, 6.0, &stats(40e6, 15e6, true), plenty, extent)
            == CutoverDecision::StoreAndForward(StoreAndForwardReason::RollingGainTooSmall),
        "Noisy Wi-Fi at 6x: pre-stage",
    );
    h.check(
        lead(cutover::decide(bd25, bd, 4.0, &stats(40e6, 15e6, true), plenty, extent))
            .is_some_and(|b| (17_500_000_000..18_500_000_000).contains(&b)),
        "Wi-Fi at 4x: roll with ~18 GB lead",
    );
    h.check(
        cutover::decide(700_000_000, MediaClass::CdAudio, 24.0, &stats(110e6, 5e6, false), plenty, extent)
            == CutoverDecision::StoreAndForward(StoreAndForwardReason::MediaPolicy),
        "Audio CD always pre-stages",
    );
    h.check(
        cutover::decide(bd25, bd, 6.0, &stats(110e6, 5e6, false), 20_000_000_000, extent)
            == CutoverDecision::Refuse { needed_bytes: bd25 + cutover::RESERVE_BYTES, free_bytes: 20_000_000_000 },
        "No room for the whole image: refuse",
    );
    h.check(
        cutover::decide(bd25, bd, 6.0, &LinkStats::from_samples(&[110e6, 108e6, 111e6], false), plenty, extent)
            == CutoverDecision::StoreAndForward(StoreAndForwardReason::UnmeasuredLink),
        "Fewer than 8 samples never justify rolling",
    );
    h.check(
        cutover::decide(
            bd25,
            bd,
            6.0,
            &LinkStats::from_samples(&[f64::NAN, f64::INFINITY, -1.0], false),
            plenty,
            extent,
        ) == CutoverDecision::StoreAndForward(StoreAndForwardReason::UnmeasuredLink),
        "NaN/inf/negative samples are discarded",
    );
    let b = cutover::required_lead_bytes(100.0, 10.0, 5.0, 1.0, 0.0);
    h.check(
        (b - 55.0).abs() < 1e-9 && ((100.0 - 10.0 * ((100.0 - b) / 5.0)) - 10.0).abs() < 1e-9,
        "Lead formula leaves exactly one stall of cushion",
    );
}

// ---------------------------------------------------------------------------------------------
// S7
// ---------------------------------------------------------------------------------------------

fn endpoint_policy(h: &mut Harness) {
    use AddressClass::{LinkLocal, Loopback, PrivateLan, UniqueLocalV6};
    use Denial::{PublicAddress, TranslatedPublicAddress, UnspecifiedOrMulticast, UnsupportedHostName};
    let strict = EndpointPolicy::default();
    let cases: [(&str, HostVerdict); 17] = [
        ("10.0.0.1", HostVerdict::AllowedLiteral(PrivateLan)),
        ("010.0.0.1", HostVerdict::Denied(UnsupportedHostName)),
        ("8.8.8.8", HostVerdict::Denied(PublicAddress)),
        ("0.0.0.0", HostVerdict::Denied(UnspecifiedOrMulticast)),
        ("224.0.0.251", HostVerdict::Denied(UnspecifiedOrMulticast)),
        ("100.100.10.1", HostVerdict::Denied(PublicAddress)),
        ("[fd7a:115c:a1e0::1]", HostVerdict::AllowedLiteral(UniqueLocalV6)),
        ("fe80::1%en0", HostVerdict::AllowedLiteral(LinkLocal)),
        ("febf::1", HostVerdict::AllowedLiteral(LinkLocal)),
        ("::1", HostVerdict::AllowedLiteral(Loopback)),
        ("::ffff:192.168.1.4", HostVerdict::AllowedLiteral(PrivateLan)),
        ("::ffff:8.8.8.8", HostVerdict::Denied(PublicAddress)),
        ("64:ff9b::808:808", HostVerdict::Denied(TranslatedPublicAddress)),
        ("2002:808:808::1", HostVerdict::Denied(TranslatedPublicAddress)),
        ("studio-rack.local", HostVerdict::ResolveThenEvaluate),
        ("evil.lan", HostVerdict::Denied(UnsupportedHostName)),
        ("spool.example.com", HostVerdict::Denied(UnsupportedHostName)),
    ];
    for (host, expected) in cases {
        h.check(strict.evaluate_host(host) == expected, &format!("{host} → {expected:?} (same as Swift Suite 27)"));
    }
    let tailnet = EndpointPolicy::new(true, []);
    h.check(
        tailnet.evaluate_host("100.100.10.1") == HostVerdict::AllowedLiteral(AddressClass::OverlayCgnat),
        "CGNAT only after the overlay opt-in",
    );
    let studio =
        EndpointPolicy::new(false, [Cidr::parse("203.0.113.0/24"), Cidr::parse("0.0.0.0/0")].into_iter().flatten());
    h.check(
        studio.trusted_ranges().len() == 1
            && studio.evaluate_host("203.0.113.40") == HostVerdict::AllowedLiteral(AddressClass::TrustedStudioRange),
        "Studio range honoured, /0 dropped",
    );
    h.check(
        strict.evaluate_host("studio.local@evil.com") == HostVerdict::Denied(UnsupportedHostName),
        "userinfo-style smuggling refused",
    );
}

// ---------------------------------------------------------------------------------------------
// S8
// ---------------------------------------------------------------------------------------------

fn identity_and_telemetry(h: &mut Harness) {
    h.check(identity::base32_lower(b"foobar") == "mzxw6ytboi", "Base32 matches RFC 4648 (lowercase, unpadded)");
    let id = identity::node_id(&[0x42; 32]);
    let hints = TxtHints {
        node_id: id.clone(),
        protocol_version: 1,
        capabilities: identity::caps::WRITES_CD | identity::caps::WRITES_BD,
    };
    let pairs: BTreeMap<String, String> = hints.to_pairs().into_iter().map(|(k, v)| (k.to_owned(), v)).collect();
    h.check(id.len() == 26 && TxtHints::parse(&pairs).as_ref() == Some(&hints), "TXT hints round-trip");
    let mut hostile = pairs.clone();
    hostile.insert("caps".into(), "ff".into());
    h.check(TxtHints::parse(&hostile).is_none(), "Unknown capability bits refused");
    hostile = pairs.clone();
    hostile.insert("id".into(), "NOT-A-NODE-ID".into());
    h.check(TxtHints::parse(&hostile).is_none(), "Malformed node ID refused");
    h.check(identity::tls_key_pin(&[0x02; 33]).is_none(), "Compressed P-256 keys are not accepted as pins");

    let sample = |drive: &str, phase: TelemetryPhase, fraction: f64| TelemetrySample {
        drive_id: drive.into(),
        phase,
        fraction,
        current_lba: 0,
        total_lba: 1,
        effective_speed_x: 8.0,
        fifo_fill: 0.9,
        drive_buffer_fill: 0.9,
    };
    let mut conflator = TelemetryConflator::new();
    conflator.offer(sample("bd0", TelemetryPhase::BurningProgress, 0.40));
    conflator.offer(sample("bd0", TelemetryPhase::BurningProgress, 0.41));
    conflator.offer(sample("dvd1", TelemetryPhase::BurningProgress, 0.10));
    conflator.offer(sample("dvd1", TelemetryPhase::BurnCompleted, 1.0));
    conflator.offer(sample("dvd1", TelemetryPhase::BurningProgress, 0.99));
    let drained = conflator.drain();
    h.check(
        drained.iter().map(|s| s.drive_id.as_str()).collect::<Vec<_>>() == ["bd0", "dvd1"]
            && drained.first().is_some_and(|s| (s.fraction - 0.41).abs() < f64::EPSILON)
            && drained.last().is_some_and(|s| s.phase == TelemetryPhase::BurnCompleted)
            && conflator.drain().is_empty(),
        "Newest per drive, terminal states sticky, empty after drain",
    );
    h.check(TelemetryPhase::BurningProgress.wire_name() == "BURNING_PROGRESS", "Phase names match the Swift enum");
}
