//! The job manager on its own, with the simulated backend and no workers running.
#![allow(clippy::unwrap_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]

use krsp::control::{BurnOptions, Content, JobState};
use krsp::manifest::TransferManifest;
use server_core::config::{BackendKind, Config};
use server_core::jobs::{JobManager, Submission};
use server_core::testutil::TempDir;

/// A cancel that lands while the last extent is being written (the upload's session commits it,
/// then calls `finish_upload`) must not be undone by queuing the burn.
#[test]
fn finishing_an_upload_does_not_revive_a_cancelled_job() {
    let tmp = TempDir::new("jobs-cancel");
    let mut config = Config::defaults(tmp.path());
    config.backend = BackendKind::Simulate;
    config.simulate_drives = 1;
    config.min_free_bytes = 0;
    let backend = server_core::backend::from_config(&config);
    let jobs = JobManager::new(config, backend).unwrap();

    let image: Vec<u8> = (0..32usize * 2048).map(|i| (i * 31) as u8).collect();
    let manifest = TransferManifest::from_image(&image, 2048, 8).unwrap();
    let options = BurnOptions { speed: 0, verify: false, simulate: false, eject: false };
    let submission =
        Submission { owner: "mac", job: "j1", drive: "sim-1", label: "L", content: Content::Image, options: &options };
    let mut staged = jobs.begin_upload(&submission, &manifest).unwrap();
    for i in 0..manifest.extent_count() {
        let r = manifest.byte_range(i);
        staged.commit(i, &image[r.start as usize..r.end as usize]).unwrap();
    }
    assert!(jobs.cancel("mac", "j1"));
    jobs.finish_upload("j1", &mut staged).unwrap();
    assert_eq!(jobs.job_info("mac", "j1").unwrap().state, JobState::Cancelled);
}
