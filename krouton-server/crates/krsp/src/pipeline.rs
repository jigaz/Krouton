// MARK: - pipeline.rs

//! Sans-I/O extent pipeline: the node-side receiver and the workstation-side sender as pure state
//! machines (bytes in, frames out). Same rules as `SpoolExtentPipeline.swift`; the tests
//! drives both through a deterministic faulty link.

use crate::frame::{Frame, FrameDecoder, FrameHeader, FrameKind, WireError};
use crate::manifest::{ExtentBitmap, TransferManifest, leaf_digest};
use std::collections::{BTreeSet, HashMap, VecDeque};

// ---------------------------------------------------------------------------------------------
// Receiver (node): verify, persist, acknowledge, grant credit
// ---------------------------------------------------------------------------------------------

#[derive(Debug)]
pub struct StagingReceiver {
    manifest: TransferManifest,
    window_extents: u32,
    committed: ExtentBitmap,
    rejected_extents: u64,
    decoder: FrameDecoder,
}

impl StagingReceiver {
    #[must_use]
    pub fn new(manifest: TransferManifest, committed: ExtentBitmap, window_extents: u32) -> Self {
        Self {
            manifest,
            window_extents: window_extents.max(1),
            committed,
            rejected_extents: 0,
            decoder: FrameDecoder::new(),
        }
    }

    #[must_use]
    pub fn committed(&self) -> &ExtentBitmap {
        &self.committed
    }

    #[must_use]
    pub fn rejected_extents(&self) -> u64 {
        self.rejected_extents
    }

    /// Drops any half-received frame. Committed extents survive.
    pub fn connection_reset(&mut self) {
        self.decoder.reset();
    }

    /// Feeds bytes from the connection and returns the frames to send back. `persist` must make the
    /// extent durable (preallocated pwrite + ordered flush + journal record) before returning `true`.
    /// Credit is granted only after that, so the staging disk paces the sender end to end.
    pub fn receive(
        &mut self,
        bytes: &[u8],
        mut persist: impl FnMut(usize, &[u8]) -> bool,
    ) -> Result<Vec<Frame>, WireError> {
        let mut replies = Vec::new();
        for frame in self.decoder.push(bytes)? {
            replies.extend(self.handle_frame(&frame, &mut persist));
        }
        Ok(replies)
    }

    /// Frame-level entry point for sessions that own their own decoder (control frames share the
    /// connection). Frames other than `BitmapQuery` and `ExtentData` are ignored.
    pub fn handle_frame(&mut self, frame: &Frame, mut persist: impl FnMut(usize, &[u8]) -> bool) -> Vec<Frame> {
        match frame.header.kind {
            FrameKind::BitmapQuery => {
                if frame.payload.as_slice() != self.manifest.root.as_slice() {
                    return vec![Frame::signal(FrameKind::ManifestMismatch, 0)];
                }
                vec![
                    Frame::new(FrameHeader::new(FrameKind::BitmapReply), self.committed.as_bytes().to_vec()),
                    Frame::signal(FrameKind::Credit, self.window_extents),
                ]
            }
            FrameKind::ExtentData => self.accept(frame, &mut persist).to_vec(),
            _ => Vec::new(),
        }
    }

    fn accept(&mut self, frame: &Frame, persist: &mut impl FnMut(usize, &[u8]) -> bool) -> [Frame; 2] {
        let index = frame.header.extent_index as usize;
        let range = self.manifest.byte_range(index);
        // The payload digest is recomputed and compared with the MANIFEST, never with the sender's header.
        let valid = self.manifest.leaf(index).is_some_and(|expected| {
            u32::from(frame.header.sector_size) == self.manifest.sector_size
                && frame.payload.len() as u64 == range.end - range.start
                && frame.header.digest == *expected
                && leaf_digest(&frame.payload) == *expected
        });
        if valid && (self.committed.contains(index) || persist(index, &frame.payload)) {
            self.committed.insert(index);
            [Frame::signal(FrameKind::ExtentAck, frame.header.extent_index), Frame::signal(FrameKind::Credit, 1)]
        } else {
            self.rejected_extents += 1;
            [Frame::signal(FrameKind::ExtentReject, frame.header.extent_index), Frame::signal(FrameKind::Credit, 1)]
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Sender (workstation): resume from the node's bitmap, obey credit, retransmit rejects
// ---------------------------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SenderPhase {
    Disconnected,
    AwaitingBitmap,
    Streaming,
    Complete,
    ManifestMismatch,
    /// The same extent failed verification too often: the source changed under the manifest.
    SourceChanged {
        extent: usize,
    },
}

pub const MAX_REJECTS_PER_EXTENT: u32 = 3;

#[derive(Debug)]
pub struct UploadSender {
    manifest: TransferManifest,
    max_in_flight: usize,
    phase: SenderPhase,
    acknowledged: ExtentBitmap,
    pending: VecDeque<usize>,
    in_flight: BTreeSet<usize>,
    rejects: HashMap<usize, u32>,
    credits: u64,
    decoder: FrameDecoder,
    pub retransmissions: u64,
    pub extents_sent: u64,
    pub peak_in_flight: usize,
}

impl UploadSender {
    #[must_use]
    pub fn new(manifest: TransferManifest, max_in_flight: usize) -> Self {
        let acknowledged = ExtentBitmap::new(manifest.extent_count());
        Self {
            manifest,
            max_in_flight: max_in_flight.max(1),
            phase: SenderPhase::Disconnected,
            acknowledged,
            pending: VecDeque::new(),
            in_flight: BTreeSet::new(),
            rejects: HashMap::new(),
            credits: 0,
            decoder: FrameDecoder::new(),
            retransmissions: 0,
            extents_sent: 0,
            peak_in_flight: 0,
        }
    }

    /// In-flight extents that fit `budget_bytes`, keeping one extent for the read-ahead buffer.
    #[must_use]
    pub fn max_in_flight_for_budget(budget_bytes: u64, manifest: &TransferManifest) -> usize {
        let per_extent = manifest.extent_bytes().max(1);
        usize::try_from((budget_bytes / per_extent).saturating_sub(1)).unwrap_or(usize::MAX).max(1)
    }

    #[must_use]
    pub fn phase(&self) -> SenderPhase {
        self.phase
    }

    #[must_use]
    pub fn acknowledged(&self) -> &ExtentBitmap {
        &self.acknowledged
    }

    /// A (re)connection: ask the node what it already holds. No extent goes out before the answer.
    pub fn connect(&mut self) -> Vec<Frame> {
        self.reset_connection_state();
        self.phase = SenderPhase::AwaitingBitmap;
        vec![Frame::new(FrameHeader::new(FrameKind::BitmapQuery), self.manifest.root.to_vec())]
    }

    pub fn disconnected(&mut self) {
        self.reset_connection_state();
        if matches!(self.phase, SenderPhase::AwaitingBitmap | SenderPhase::Streaming) {
            self.phase = SenderPhase::Disconnected;
        }
    }

    pub fn receive(&mut self, bytes: &[u8], mut extent: impl FnMut(usize) -> Vec<u8>) -> Result<Vec<Frame>, WireError> {
        for frame in self.decoder.push(bytes)? {
            let index = frame.header.extent_index as usize;
            match frame.header.kind {
                FrameKind::BitmapReply => {
                    if self.phase != SenderPhase::AwaitingBitmap {
                        continue;
                    }
                    let Some(remote) = ExtentBitmap::from_wire(self.manifest.extent_count(), &frame.payload) else {
                        continue;
                    };
                    self.pending = remote.missing().into();
                    self.acknowledged = remote; // the node's durable state is authoritative
                    self.phase = SenderPhase::Streaming;
                }
                FrameKind::ManifestMismatch => self.phase = SenderPhase::ManifestMismatch,
                FrameKind::Credit => self.credits = self.credits.saturating_add(u64::from(frame.header.extent_index)),
                FrameKind::ExtentAck => {
                    if self.in_flight.remove(&index) {
                        self.acknowledged.insert(index);
                    }
                }
                FrameKind::ExtentReject => {
                    if !self.in_flight.remove(&index) {
                        continue;
                    }
                    let count = self.rejects.entry(index).or_insert(0);
                    *count += 1;
                    if *count >= MAX_REJECTS_PER_EXTENT {
                        self.phase = SenderPhase::SourceChanged { extent: index };
                    } else {
                        self.pending.push_front(index);
                        self.retransmissions += 1;
                    }
                }
                _ => {}
            }
        }
        Ok(self.pump(&mut extent))
    }

    fn pump(&mut self, extent: &mut impl FnMut(usize) -> Vec<u8>) -> Vec<Frame> {
        if self.phase != SenderPhase::Streaming {
            return Vec::new();
        }
        let mut out = Vec::new();
        while self.credits > 0 && self.in_flight.len() < self.max_in_flight {
            let Some(index) = self.pending.pop_front() else { break };
            if self.acknowledged.contains(index) {
                continue;
            }
            let Some(leaf) = self.manifest.leaf(index) else { continue };
            let mut header = FrameHeader::new(FrameKind::ExtentData);
            header.extent_index = u32::try_from(index).unwrap_or(u32::MAX);
            header.first_lba = self.manifest.first_lba(index);
            header.sector_size = u16::try_from(self.manifest.sector_size).unwrap_or(0);
            header.digest = *leaf;
            out.push(Frame::new(header, extent(index)));
            self.in_flight.insert(index);
            self.credits -= 1;
            self.extents_sent += 1;
            self.peak_in_flight = self.peak_in_flight.max(self.in_flight.len());
        }
        if self.pending.is_empty() && self.in_flight.is_empty() && self.acknowledged.is_complete() {
            self.phase = SenderPhase::Complete;
        }
        out
    }

    fn reset_connection_state(&mut self) {
        self.decoder.reset();
        self.in_flight.clear();
        self.credits = 0;
    }
}
